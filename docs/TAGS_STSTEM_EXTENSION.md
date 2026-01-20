# AiSearchable Tags System – Extension Plan (Vetfort)

Goal: extend the **ai_searchable** tagging system so it covers not only food and supplements, but also non-food pet products (toys, bowls, carriers, hygiene, grooming, etc). This is mainly about **expanding the tag dimensions + whitelist**, and adjusting the tagging logic to avoid wrong tags like `format:treat` on toys.

This doc is written as implementation guidance for GitHub Copilot/Codex.

---

## 1. Problem statement

### Current state
We have an ai_searchable tagging system driven by:
- YAML config (whitelist of allowed values)
- LLM-based tagger (ProductTagger) that extracts tags from product name/description/taxons/properties
- normalization layer (TagFormat, BrandNormalizer)
- rake task to populate tags for existing products

Current dimensions are optimized for **food and supplements**:
- species (multi)
- format (dry, wet, treat, supplement)
- diet (normal, premium, super_premium, veterinary)
- problem (skin, renal, gi, urinary, etc)
- brand (enum with aliases)

### Issues
1) For non-food products, schema does not provide enough “language” to classify them.
2) LLM tries to force-match to existing dimensions and produces wrong tags:
   - toys labeled as `format:treat`
   - random `diet` / `problem` inferred from weak hints
3) Coverage is weak for categories that are not food/supplements.

### Desired outcome
- Add new dimensions that apply broadly, so non-food items can be tagged meaningfully.
- Keep existing food dimensions, but limit them to relevant product types to reduce hallucinations.
- Maintain strict whitelists for enum dimensions.

---

## 2. Design principle

### Separate tags into layers
We should treat ai_searchable tags as 2 groups:

#### A) Universal tags (apply to any product)
These should be safe and meaningful for any catalog item:
- species
- brand
- product_type (new) – very important

#### B) Food-only / medical tags (apply only when relevant)
These should only be produced for food/supplements:
- format
- diet
- problem

Key idea: **Add `product_type` dimension** and use it as a gate:
- if product_type is not food/supplement, we should not emit `format`, `diet`, `problem`

This prevents `format:treat` on toys and similar errors.

---

## 3. Required changes overview

### 3.1 Add new dimension: `product_type`
Add a new enum dimension that classifies the product category at a high level.

Suggested values (keep it small and useful):
- food
- supplement
- treat (optional: only if you want separate from food)
- toy
- accessory
- hygiene
- grooming
- litter
- carrier
- bedding
- bowl_feeder
- other

Notes:
- You can start with 8-12 values. Keep it stable.
- If unsure, use `other` or omit product_type (but better to classify).
- This dimension is not about taxons granularity. It’s a coarse “what is this product”.

### 3.2 Extend YAML config
Update `ai_searchable.yaml` to include `product_type` in the whitelist.

Example:

ai_searchable:
  product_type:
    values:
      - food
      - supplement
      - toy
      - accessory
      - hygiene
      - grooming
      - litter
      - carrier
      - bedding
      - bowl_feeder
      - other

Important:
- `AiSearchable::Config.dimensions` must include `product_type`
- `AiSearchable::Config.values_for("product_type")` must work

### 3.3 Update LLM schema generation
`AiSearchable::ProductTagger#ai_schema_description` currently prints all dimensions, and the prompt asks the model to emit values.

Update the prompt/schema to include:
- `product_type` as required-ish (if possible)
- rules that gate `format/diet/problem` behind product_type

### 3.4 Update prompt rules to reduce wrong tags
Update `product_tagger_prompt.yaml` to clearly describe:
- what `product_type` means
- when to omit `format/diet/problem`

Add explicit “negative rules”:
- If product_type in [toy, accessory, hygiene, grooming, carrier, bowl_feeder, bedding, litter]:
  - do NOT emit format
  - do NOT emit diet
  - do NOT emit problem
  - only emit species/brand/product_type if known

Also tighten existing rules:
- Only emit `diet` when explicitly indicated, otherwise omit it
- Only emit `problem` when explicitly indicated, otherwise omit it
- Only emit `format:treat` for edible treats, never for toys

---

## 4. Prompt update specification

### 4.1 Add product_type to expected JSON shape
New expected output:

{
  "ai_tags": {
    "product_type": "toy",
    "species": ["cat"],
    "brand": "mr_bandit"
  }
}

or for food:

{
  "ai_tags": {
    "product_type": "food",
    "species": ["cat"],
    "format": "dry",
    "diet": "veterinary",
    "problem": ["urinary"],
    "brand": "royal_canin"
  }
}

### 4.2 Add gating rules (must)
Add to prompt Rules:

- First decide `product_type`.
- Only emit `format`, `diet`, and `problem` when product_type is "food" or "supplement".
- If product_type is not "food" or "supplement", omit `format`, `diet`, and `problem` entirely.

### 4.3 Add non-food clarification
Add something like:

Non-food examples:
- Toys, collars, leashes, bowls, fountains, carriers, litter boxes, grooming tools, scratching posts are NOT food.
For such products, omit food-related dimensions.

### 4.4 Tighten treat logic
Add:

- Use `format: treat` ONLY for edible treats/snacks.
- Do NOT use `format: treat` for chew toys, catnip toys, or any toy.

---

## 5. Tagger logic changes

### 5.1 Update multiplicity list
Currently:

multiple_dimensions = %w[species problem]

After adding `product_type`, it remains single.

### 5.2 Update normalization
Normalization already:
- maps problems -> problem via DIMENSION_ALIASES
- validates against whitelist unless allow_any?

Add:
- make sure `product_type` is validated against its whitelist
- make sure `normalize_dimension` recognizes `product_type`

### 5.3 Add post-processing gate in code (recommended)
Even if prompt says to omit, do not fully trust the LLM.

Add a safety filter inside `normalize_ai_tags`:

- Read normalized product_type (first)
- If product_type is present and not in ["food", "supplement"]:
  - drop dimensions: format, diet, problem

This guarantees no `format:treat` on toys even if LLM tries.

Pseudo logic:

normalized = normalize_ai_tags(parsed["ai_tags"] || {})
product_type = normalized["product_type"]
if product_type.present? && !%w[food supplement].include?(product_type)
  normalized.delete("format")
  normalized.delete("diet")
  normalized.delete("problem")
end
normalized

Notes:
- If product_type is missing, current behavior remains (but you should aim to emit it).
- Later you can decide to enforce product_type always.

---

## 6. YAML values and future-proofing

### 6.1 Keep lists stable
Once you start tagging products, changing the enum set can create messy migrations.
Prefer adding new values, not renaming old ones.

### 6.2 Aliases for product_type (optional)
If you expect multiple phrasings from content, you can support aliases in config later, similar to brand.
Example (optional):

product_type:
  values: [...]
  aliases:
    bowl_feeder:
      - bowl
      - feeder
      - миска
      - кормушка

But simplest approach:
- let LLM output exact whitelisted strings
- filter hard in code

---

## 7. Rake task notes (scope of this doc: tagging extension only)

We are not changing rake behavior here, but after introducing product_type:
- rerun populate task to tag non-food products correctly
- observe reduced wrong tags (format/diet/problem on toys should disappear)

Optional env flags for later:
- ONLY_UNTAGGED=1
- DRY_RUN=1

But these are separate improvements, not part of this “tags extension” doc.

---

## 8. Acceptance criteria

After implementing `product_type` and gating:

1) Toys/accessories/hygiene items should no longer get:
- ai_searchable:format:*
- ai_searchable:diet:*
- ai_searchable:problem:*

2) Non-food products should still receive useful tags:
- ai_searchable:product_type:<value>
- ai_searchable:species:<value> (only if explicit, or according to current strategy)
- ai_searchable:brand:<value> (if clear)

3) Food and supplements should keep working as before, with improved precision:
- fewer guessed diet/problem tags
- `format:treat` only for edible treats

---

## 9. Implementation checklist

- [ ] Add `product_type` to `ai_searchable.yaml` whitelist.
- [ ] Ensure `AiSearchable::Config.dimensions` includes "product_type".
- [ ] Ensure schema generation includes `product_type`.
- [ ] Update prompt:
  - [ ] define product_type
  - [ ] gate food-only tags by product_type
  - [ ] tighten treat logic
  - [ ] add non-food examples list
- [ ] Add code-level gating in ProductTagger normalization (drop format/diet/problem unless food/supplement).
- [ ] Run rake task on a sample set and verify:
  - toys no longer tagged as treat
  - food still tagged correctly
- [ ] Consider adding a small report (counts by product_type) to validate distribution.

---

## 10. Notes on later improvements (out of scope)
This doc only covers expanding the tagging vocabulary.
Later we can improve:
- better species strategy for cross-species goods
- deterministic classification without LLM for non-food
- idempotency and backoff in rake
- QA review UI for tags


