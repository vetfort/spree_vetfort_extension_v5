# Product Separation Implementation Plan

## Overview

This document outlines the phased implementation of separating product recommendations from conversational text in the AI Shopping Consultant feature. The goal is to display products in a dedicated section rather than embedded within chat messages.

**Selected Approach:** Structured JSON responses from LLM (Option 2)
- LLM returns `{ "text": "...", "products": [...] }` format
- Deterministic parsing, clean separation, extensible for future enhancements
- Alternative considered: markdown link extraction (rejected as fragile)

---

## Phase 1: LLM Integration Layer Update

**Goal:** Enable LLM to return structured JSON and parse responses

### Phase 1.1: Update Prompt Template ✅ COMPLETE

**File:** `app/services/llm_assistants/prompts/ai_consultant_instructions.yaml`

**Changes:**
- Added JSON response format specification to system prompt
- Defined rules for "text" field: conversational response, no URLs or prices
- Defined rules for "products" field: only from fetch tool results
- Provided example response structures
- Emphasized "RESPOND ONLY WITH VALID JSON"

**Example Response Format:**
```json
{
  "text": "These products are perfect for your needs...",
  "products": [
    {
      "product_id": 123,
      "reason": "Compact size fits small spaces"
    }
  ]
}
```

**Note:** The LLM tools return `product_id`, not URLs. This ensures we use the correct product from our database rather than trusting LLM-generated slugs.

### Phase 1.2: Update Assistant Service ✅ COMPLETE

**File:** `app/services/llm_assistants/ai_consultant_assistant.rb`

**Changes:**
1. Added `response_format: { type: 'json_object' }` to OpenAI LLM initialization
2. Replaced `normalize_assistant_messages()` with `parse_structured_response()`
3. New method extracts "text" and "products" from JSON response
4. Returns hash with both fields: `{ role: 'assistant', content: json_string, text: '...', products: [...] }`
5. Added robust error handling with fallback response

**Key Methods:**
- `parse_structured_response(messages)` - Parses JSON and extracts fields
- `fallback_response()` - Returns safe default if parsing fails

**Error Handling:**
- JSON parse errors logged and caught
- Returns fallback message with empty products array
- LLM errors logged and return fallback response

---

## Phase 2: Database Layer Update

**Goal:** Store products separately from text in message records

### Phase 2.1: Create Database Migration

**File:** `db/migrate/[timestamp]_add_products_to_ai_consultant_messages.spree_vetfort_extension_v5.rb`

**Changes:**
- Add `products` column (JSONB type) to `ai_consultant_messages` table
- Add optional GIN index for future analytics queries (can be deferred if not querying products yet)
- Set default value to empty array `[]`

**Migration Content:**
```ruby
class AddProductsToAiConsultantMessages < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_vetfort_extension_v5_ai_consultant_messages, :products, :jsonb, default: [], null: false
    # Only add index if you plan to query products (e.g., analytics).
    # For now, most queries are message_id-based, so this is optional.
    # add_index :spree_vetfort_extension_v5_ai_consultant_messages, :products, using: :gin
  end
end
```

**Note on JSONB vs JSON:**
- Use `jsonb` instead of `json` for better performance and operator support (`@>` for containment queries)
- GIN index makes sense with `jsonb` for future queries like `WHERE products @> '[{\"product_id\": 123}]'`
- Defer the index until you need analytics on products

### Phase 2.2: Update Message Model

**File:** `app/models/spree/vetfort_extension_v5/ai_consultant_message.rb`

**Changes:**
- Add validation: `products` must be array of hashes with `product_id` and `reason`
- Add `with_products` scope to find messages with products
- Leverage JSONB column type (no additional serialization needed)

**Model Code:**
```ruby
class Spree::VetfortExtensionV5::AiConsultantMessage < ApplicationRecord
  validate :validate_products_structure
  
  scope :with_products, -> { where.not(products: []) }
  
  private
  
  def validate_products_structure
    return if products.blank?
    
    unless products.is_a?(Array)
      errors.add(:products, "must be an array")
      return
    end
    
    products.each_with_index do |product, idx|
      unless product.is_a?(Hash)
        errors.add(:products, "item #{idx} must be a hash")
        next
      end
      
      product_id = product["product_id"] || product[:product_id]
      reason     = product["reason"] || product[:reason]
      
      if product_id.blank? || reason.blank?
        errors.add(:products, "item #{idx} must have product_id and reason")
      end
    end
  end
end
```

**Notes:**
- `jsonb` column in database already returns Ruby objects; no need for `serialize`
- `where.not(products: [])` is more Rails-idiomatic than raw SQL
- Default `products: []` ensures consistent type (never nil)

---

## Phase 3: Response Handling in Job

**Goal:** Store text and products separately from LLM response

### Design Decision: One Parsing Location

**Keep parsing in Assistant only (Phase 1.2 complete)**
- `AiConsultantAssistant` is the single source of truth for JSON parsing
- Returns fully validated Ruby hash: `{ text: '...', products: [...] }`
- `AiChatJob` trusts the result and persists directly
- Error handling stays close to source (where JSON is parsed)
- Simpler, avoids duplicate parsing logic

**Alternate approach (not recommended):** ResponseParser as centralized service
- Would introduce second parsing location
- Increases complexity without clear benefit
- Decision: Skip this layer, parsing stays in assistant

### Phase 3: Update AiChatJob

**File:** `app/jobs/ai_chat_job.rb`

**Changes:**
- Call `AiConsultantAssistant.call()` which returns `{ text: '...', products: [...] }`
- Store both fields in message record
- Broadcast message and products grid separately via Turbo

**Updated Flow:**
```
User submits message
  → AiChatJob enqueued
  → AiConsultantAssistant.call()
    ├─ LLM returns JSON
    ├─ parse_structured_response() extracts text + products
    └─ returns { text: '...', products: [...] }
  → message.update!(content: text, products: products)
  → turbo_stream.replace 'ai-consultant-products'
  → turbo_stream.append 'messages'
```

**Code Example:**
```ruby
class AiChatJob < ApplicationJob
  def perform(conversation_id, user_message)
    conversation = AiConsultantConversation.find(conversation_id)
    messages = conversation.to_llm_messages  # or: conversation.messages.map { |m| { role: m.role, content: m.content } }
    
    # LLMAssistant returns { text: '...', products: [...], raw_json: '...' }
    result = LLMAssistants::AiConsultantAssistant.call(messages: messages)
    
    message = conversation.messages.create!(
      role: 'assistant',
      content: result[:text],        # Store conversational text
      products: result[:products],   # Store products array
      raw_json: result[:raw_json]    # Optional: raw LLM response for debugging
    )
    
    # Broadcast text and products separately
    broadcast_message(message)
    broadcast_products(message.products)
  end
end
```

---

## Phase 4: UI Components Update

**Goal:** Display products in dedicated grid below chat

**Key Behavior:** Products grid always reflects recommendations from the latest assistant message, not a union of all conversation history.

### Phase 4.1: Create ProductsGrid Component

**File:** `app/components/vetfort_extension_v5/ai_consultant/products_grid_component.rb`

**Responsibility:**
- Display products in responsive grid (2-4 columns based on screen size)
- Fetch real product records from `product_id` in products array
- Show product image, name, price from DB (not LLM)
- Show "reason" why recommended (from products array)
- Include "Add to Cart" button

**Component Props:**
```ruby
products_grid_component(products: [...])  # products = [{ product_id: 123, reason: "..." }]
```

**Implementation Notes:**
- Always resolve `product_id` to actual `Spree::Product` in backend
- Use product DB data for name/image/price (never trust LLM values)
- Gracefully handle missing products (product deleted after recommendation)

### Phase 4.2: Create ProductCard Component

**File:** `app/components/vetfort_extension_v5/ai_consultant/product_card_component.rb`

**Responsibility:**
- Render individual product card
- Display image, name, short description
- Show recommendation reason
- Add to cart button

### Phase 4.3: Update ChatComponent

**File:** `app/components/vetfort_extension_v5/ai_consultant/chat_component.rb`

**Changes:**
- Add products grid container in separate Turbo Frame (do not re-render messages on grid update)
- Toggle visibility based on whether products exist
- Show only products from **last assistant message** (not union of all conversation)
- Pass products to ProductsGrid component

**Layout:**
```
┌─ Messages History (Turbo Stream) ─────────────┐
│  [User Message]                               │
│  [Assistant Text Message]                     │
│  [User Message]                               │
└───────────────────────────────────────────────┘
┌─ Products Grid (Separate Frame) ──────────────┐
│ [Product 1] [Product 2] [Product 3]           │
│ [Product 4] [Product 5]                       │
└───────────────────────────────────────────────┘
```

**Turbo Stream Strategy:**
```erb
<%= turbo_stream.append "ai-consultant-messages" do %>
  <%= render message_component %>
<% end %>

<%= turbo_stream.replace "ai-consultant-products" do %>
  <%= render products_grid_component(products: @message.products) %>
<% end %>
```

**Rationale:**
- Separate frames avoid re-rendering chat history when products update
- Cleaner Turbo streams, faster page updates
- Can add "Show earlier recommendations" toggle later

### Phase 4.4: Update BotMessageComponent

**File:** `app/components/vetfort_extension_v5/ai_consultant/bot_message_component.rb`

**Changes:**
- Remove product link extraction logic
- Display only `text` field (no products)
- Remove markdown link parsing
- Simplify to pure text rendering

---

## Phase 5: Integration & Testing

**Goal:** Ensure all phases work together seamlessly

### Phase 5.1: Unit Tests

**Test: Message Model Validation**
```ruby
it "rejects products that are not an array" do
  message.products = { product_id: 123 }
  expect(message).not_to be_valid
end

it "rejects products without product_id or reason" do
  message.products = [{ product_id: 123 }]  # missing reason
  expect(message).not_to be_valid
end

it "accepts valid products array" do
  message.products = [{ "product_id" => 123, "reason" => "Good fit" }]
  expect(message).to be_valid
end
```

**Test: AiConsultantAssistant JSON Parsing**
```ruby
it "extracts text and products from valid JSON response" do
  result = AiConsultantAssistant.call(messages: [...])
  expect(result[:text]).to be_present
  expect(result[:products]).to be_an(Array)
end

it "returns fallback on JSON parse error" do
  # Mock LLM to return invalid JSON
  result = AiConsultantAssistant.call(messages: [...])
  expect(result[:text]).to match(/having trouble/)
  expect(result[:products]).to eq([])
end
```

### Phase 5.2: Integration Tests

**Test: Full Chat Flow**
```ruby
it "stores text and products from LLM response" do
  AiChatJob.perform_now(conversation.id, "Show me cozy chairs")
  
  message = conversation.messages.last
  expect(message.role).to eq("assistant")
  expect(message.content).to be_present  # text stored
  expect(message.products).to be_an(Array)
  expect(message.products.first["product_id"]).to be_present
end
```

### Phase 5.3: System/Browser Tests

**Test: UI Display**
- User sends message → wait for Turbo stream → message appears with text
- Products grid renders below with correct items
- Click product card → navigates to product page
- Empty products array → grid hidden, only text visible

**Desktop/Mobile Responsive:**
- Grid responsive (2-4 columns)
- Mobile: Products stack vertically
- Touch targets adequately sized

### Phase 5.4: Error Scenarios

**Test Cases:**
- LLM returns JSON with missing `text` field → fallback message
- LLM returns invalid JSON → fallback, error logged
- Product no longer exists in DB → card gracefully skipped
- Network timeout → error message shown to user
- Missing `OPENAI_API_KEY` → error logged, fallback shown

**Data Preservation:**
- Even on parse error, raw LLM response stored for debugging
- Fallback response includes `products: []` for consistency

---

## Current Status

| Phase | Status | Completion |
|-------|--------|------------|
| 1.1 | ✅ Complete | Prompt template updated with JSON format rules (using product_id) |
| 1.2 | ✅ Complete | AiConsultantAssistant service updated for JSON parsing |
| 2.1 | ⏳ Pending | Database migration: add `products` JSONB column |
| 2.2 | ⏳ Pending | Message model: add validation and scope for products |
| 3.1 | ⏳ Pending | AiChatJob updated to store text + products from assistant result |
| 3.2 | ⏳ Pending | Turbo streams updated to broadcast products grid separately |
| 4.1 | ⏳ Pending | ProductsGrid component created |
| 4.2 | ⏳ Pending | ProductCard component created |
| 4.3 | ⏳ Pending | ChatComponent products grid integration |
| 4.4 | ⏳ Pending | BotMessageComponent text-only rendering |
| 5.1-5.4 | ⏳ Pending | Integration and testing |

---

## Technical Details

### Response Format Contract

**LLM Output (from OpenAI with `response_format: { type: 'json_object' }`):**
```json
{
  "text": "Conversational response explaining the recommendations and answering the user's question.",
  "products": [
    {
      "product_id": 123,
      "reason": "Brief explanation why this product matches the user's needs"
    },
    {
      "product_id": 456,
      "reason": "Another reason this is relevant"
    }
  ]
}
```

**Why `product_id` instead of `url`?**
- LLM may hallucinate or return incorrect product slugs
- Using `product_id` from the tool response is more reliable
- Backend resolves product_id to real product record for name, image, price
- Never trust LLM-provided product data; always validate against DB

**Assistant Service Return Value (Single Format):**
```ruby
{
  text: 'Conversational response explaining recommendations...',
  products: [
    { "product_id": 123, "reason": "..." },
    { "product_id": 456, "reason": "..." }
  ]
}
```

**Data Flow in Job:**
```ruby
result = AiConsultantAssistant.call(messages: [...])
# result[:text] => conversational text
# result[:products] => array of { product_id, reason }
# result[:raw_json] => raw JSON string for debugging

message.update!(
  content: result[:text],
  products: result[:products],
  raw_json: result[:raw_json]  # Optional: preserve for error analysis
)
```

**Optional `raw_json` Column:**
Consider adding `raw_json` text column to `ai_consultant_messages` to preserve raw LLM responses. Useful for debugging parsing errors and analyzing model behavior. Can be added in Phase 2 migration or deferred to Phase 5 if not needed initially.

### Database Schema Changes

**Table: ai_consultant_messages**
```sql
ALTER TABLE spree_vetfort_extension_v5_ai_consultant_messages
ADD COLUMN products jsonb DEFAULT '[]';

-- Optional: Add GIN index if querying products for analytics
-- CREATE INDEX idx_ai_consultant_messages_products 
-- ON spree_vetfort_extension_v5_ai_consultant_messages 
-- USING gin(products);
```

**Example Queries:**
```sql
-- Find messages with products
-- Equivalent in Rails: Message.with_products
SELECT * FROM spree_vetfort_extension_v5_ai_consultant_messages 
WHERE products != '[]'::jsonb;

-- Find messages recommending specific product (with index)
SELECT * FROM spree_vetfort_extension_v5_ai_consultant_messages 
WHERE products @> '[{"product_id": 123}]';
```

### API Contract Between Phases

**Phase 1 → Phase 2:**
```ruby
{
  text: "Conversational response...",
  products: [
    { "product_id": 123, "reason": "..." },
    { "product_id": 456, "reason": "..." }
  ]
}
```

**Phase 2 → Phase 3:**
Message record:
```ruby
message = {
  role: 'assistant',
  content: 'Conversational response...',  # stored text
  products: [{ "product_id": 123, ... }] # stored products array
}
```

**Phase 3 → Phase 4:**
Job broadcasts:
```erb
<%= turbo_stream.append "messages" do %>
  <%= render message_component(message) %>
<% end %>

<%= turbo_stream.replace "products-grid" do %>
  <%= render products_grid_component(products: message.products) %>
<% end %>
```

**Phase 4 → UI:**
Component receives and displays:
```ruby
ProductsGridComponent.new(
  products: [{ "product_id": 123, "reason": "..." }, ...]
).render  # Resolves product_id to Spree::Product, shows name/image/price
```

---

## Rollback Plan

If issues arise, rollback in reverse order:

1. **Phase 4 Rollback:** Revert component changes, message display returns to embedded products
2. **Phase 3 Rollback:** Remove job changes, use old message persistence flow
3. **Phase 2 Rollback:** Drop `products` column, migration down
4. **Phase 1 Rollback:** Restore old prompt, remove JSON parsing from service

---

## Implementation Checklist

### Phase 1 ✅
- [x] Update prompt with JSON format rules
- [x] Enable JSON mode in LLMAssistant
- [x] Implement JSON parsing and extraction
- [x] Add error handling with fallback

### Phase 2 ⏳
- [ ] Create migration: add `products` JSONB column with `null: false`
- [ ] Update AiConsultantMessage model: add validation and `with_products` scope
- [ ] Test model validation
- [ ] Verify migrations run cleanly

### Phase 3 ⏳
- [ ] Update AiChatJob to extract text + products
- [ ] Store products in message record
- [ ] Test job with mock LLM responses

### Phase 4 ⏳
- [ ] Create ProductsGridComponent
- [ ] Create ProductCardComponent (resolve product_id to Spree::Product)
- [ ] Update ChatComponent to render products grid
- [ ] Update BotMessageComponent to show text only

### Phase 5 ⏳
- [ ] Write unit tests for model validation
- [ ] Write unit tests for JSON parsing
- [ ] Write integration test for full chat flow
- [ ] Browser testing (desktop/mobile)
- [ ] Error scenario testing

---

*Last Updated: December 4, 2025*
*Implementation Status: Phase 1.2 Complete, Phase 2-5 Pending*
*Incorporating feedback: JSONB, product_id contract, single parsing location, separate Turbo frames, comprehensive testing*
