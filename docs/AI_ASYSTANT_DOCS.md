# AI‑powered consultant for a Spree e‑commerce store

## Overview and inspiration

Your story describes an AI assistant that can chat with shoppers in your Spree‑based pet‑supply store.  The assistant should ask a few clarifying questions about a pet (species, diet, etc.), recommend appropriate food, and then suggest additional related items.  To design this feature, it helps to look at existing patterns:

- **AI integration in Rails.**  A step‑by‑step guide to using OpenAI with Ruby on Rails shows how to install HTTP client gems, create a service class to call the OpenAI API, and configure API keys in environment variables ([source](https://nascenia.com/integrating-ai-with-ruby-on-rails-application/)).  It emphasizes using external APIs instead of training your own model, handling time‑outs via background jobs, and scaling with caching and worker queues ([source](https://nascenia.com/integrating-ai-with-ruby-on-rails-application/)).  Best practices include regularly updating models, protecting user data and API keys, and using background jobs for long‑running tasks ([source](https://nascenia.com/integrating-ai-with-ruby-on-rails-application/)).

- **Generative recommendation systems.**  Generative AI can create highly personalized product recommendations by generating detailed product descriptions and suggesting bundles tailored to individual preferences ([source](https://caylent.com/blog/building-recommendation-systems-using-genai-and-amazon-personalize)).  Such systems can extend beyond simple collaborative filtering by creating context‑aware suggestions ([source](https://caylent.com/blog/building-recommendation-systems-using-genai-and-amazon-personalize)).

- **Real‑time chat in Rails using Hotwire/Stimulus.**  A recent guide shows how Hotwire reduces JavaScript complexity by using server‑driven updates and Turbo Streams ([source](https://medium.com/@anusha.gundeti2298/crafting-a-real-time-ai-chat-application-a-deep-dive-into-ruby-on-rails-hotwire-and-stimulus-ee4d3539bbc6)).  In the example, the developer adds the `ruby-openai`, `hotwire-rails`, and `stimulus-rails` gems ([source](https://medium.com/@anusha.gundeti2298/crafting-a-real-time-ai-chat-application-a-deep-dive-into-ruby-on-rails-hotwire-and-stimulus-ee4d3539bbc6)), uses a controller to broadcast new messages over Turbo Streams ([source](https://medium.com/@anusha.gundeti2298/crafting-a-real-time-ai-chat-application-a-deep-dive-into-ruby-on-rails-hotwire-and-stimulus-ee4d3539bbc6)), and writes a small Stimulus controller to manage scrolling and resetting the chat form ([source](https://medium.com/@anusha.gundeti2298/crafting-a-real-time-ai-chat-application-a-deep-dive-into-ruby-on-rails-hotwire-and-stimulus-ee4d3539bbc6)).  Benefits include real‑time updates without page reloads and minimal front‑end complexity ([source](https://medium.com/@anusha.gundeti2298/crafting-a-real-time-ai-chat-application-a-deep-dive-into-ruby-on-rails-hotwire-and-stimulus-ee4d3539bbc6)).

### Architectural examples from GaggleAMP

Internal projects under the `GaggleAMP` namespace demonstrate how to structure LLM integrations:

- **LLM service object.**  Their `LLM` module builds Langchain‑based back‑ends for both “mini” and “large” models.  It wraps the OpenAI client and configures Faraday logging, centralizing model selection.

- **Custom tools.**  Tools like `JiraTool` extend `Langchain::ToolDefinition` and expose functions with structured parameters.  For example, `search_issues(query:)` specifies a description and required argument, then implements the logic to query Jira and return JSON.  Tools are passed into the assistant so the agent can call them to fetch data.

- **Assistant class.**  `GaggleAMPAssistant` loads a YAML prompt file for system instructions, registers multiple tools and then delegates `invoke(messages)` to a `Langchain::Assistant`.  This pattern cleanly separates prompt instructions, tool registration and context management.

- **Streaming transport.**  Their examples show `ActionController::Live` with server‑sent events (SSE) to stream tokens. In our implementation we will use WebSockets (Solid Cable) for bidirectional, low‑latency updates while keeping Turbo Streams for DOM updates.

These examples highlight important design patterns: centralizing LLM configuration, building modular tools that the assistant can call, and using WebSockets (Solid Cable) with Turbo Streams for responsive chat UIs.

## High‑level design

### Choice of LLM and integration library

- **Provider.**  Use a hosted LLM such as OpenAI’s GPT‑4 or GPT‑4o via the `langchainrb` gem.  Hosted models avoid the cost and complexity of training your own model and can be swapped with other providers later.  The AI integration guide stresses using external APIs for complex tasks ([source](https://nascenia.com/integrating-ai-with-ruby-on-rails-application/)).

- **Library.**  Adopt [`langchainrb`](https://github.com/patterns-ai-core/langchainrb) to simplify agent creation, streaming and tool management.  It provides abstractions for LLMs, chat agents and vector stores similar to Python LangChain.

- **Vector search (optional).**  If product descriptions are long or you want semantic search, embed product texts using `Langchain::Vectorsearch::Pinecone` or another vector store.  For an MVP, direct database queries via tools may suffice.

### Key components

1. **Product tool – exposes product data to the LLM:**

   - `ProductTool` will extend `Langchain::ToolDefinition`.  Define functions such as:
     - `search_products(query:, pet_type:, diet_restrictions:)` – returns a list of product IDs/names that match a keyword and optional criteria.
     - `product_details(product_ids:)` – returns structured info (name, price, description, ingredients, stock) for each product.
     - `related_products(product_id:)` – returns complementary items (toys, bowls, supplements).
   - Implement these methods by querying `Spree::Product`, `Spree::Variant`, `Spree::Taxon` and other models.  Return JSON because the assistant expects machine‑readable outputs.

2. **AIConsultantAssistant service – orchestrates conversation:**

   - Create `app/services/ai_consultant_assistant.rb` that loads system instructions from a YAML file.  Instructions should tell the model:
     - It is an AI shopping consultant for a pet‑supply store.
     - It must ask clarifying questions (pet species, age, allergies, preferred food type) before suggesting products.
     - It should use the `ProductTool` functions to retrieve products and never hallucinate unavailable items.  It should return final recommendations with product names and reasons, then suggest complementary items.
     - It must avoid sensitive topics and follow general AI safety practices.
  - Initialize a `Langchain::Assistant` with `LLM.default` and pass the `ProductTool` instance. Chat responses will be generated in a background job and delivered over WebSockets.
  - Provide a method `invoke(messages)` that adds the user/assistant messages to the agent and returns an array of assistant messages ready to broadcast over the WebSocket channel (safe to call from a background worker).

3. **Controller and routes (Spree engine):**

- Add a `AiChatsController` with a `create` action.  It should accept `messages` (array of `{role:, content:}`) from the front end.
- Enqueue a background job that calls `AiConsultantAssistant.invoke` and broadcasts the resulting messages over a Solid Cable WebSocket channel. The controller returns immediately (e.g., 202 Accepted or a small JSON indicating the request was queued).
- Expose a route inside the Spree engine routes (see `config/routes.rb` `Spree::Core::Engine.add_routes` block), e.g. `post '/ai_chat' => 'spree_vetfort_extension_v5/ai_chats#create'`. Optionally add an authenticated admin UI for debugging.

4. **Chat UI using Hotwire and Stimulus (existing partials & paths):**

  - Create a Turbo Frame for the chat window and a form for sending messages. The storefront already renders `spree/shared/_vetfort_ai_consultant.html.erb` via the engine’s `spree_storefront.body_end_partials`.
- Use a Stimulus controller to submit the form via Turbo, scroll to the bottom, and reset the input field.
- Subscribe the client to a Solid Cable WebSocket channel. When the background job broadcasts assistant replies, Turbo Streams append them to the chat in real time.
  - Provide an “Ask AI Consultant” button that opens the chat window on product pages or in the navigation bar. Front‑end JS lives under `app/javascript/spree/spree_vetfort_extension_v5/`; add a `chat_controller.js` there.

5. **Data preparation and clarifying questions:**

   - Identify the core attributes needed to recommend pet food: species (dog, cat, bird, etc.), breed/size, age (puppy/kitten/adult/senior), dietary restrictions (grain‑free, allergies), format (dry/wet), and budget.
   - Prepare taxonomy for product tags (e.g., `pet_type:dog`, `diet:grain_free`).  This will make filtering easier in `search_products`.
   - Curate a list of complementary categories (treats, bowls, toys) that the assistant can suggest as cross‑sell items.  Use `Spree::Taxon` to group these.

6. **Security and cost considerations:**

   - Store the OpenAI API key and any vector DB keys in encrypted credentials.  The AI integration guide warns that data security and API secrecy are paramount.
   - Implement rate limiting or caching for OpenAI requests.  For example, cache responses for common queries to reduce API usage.
- Use background jobs (e.g., Solid Queue/Sidekiq/Resque) to offload expensive operations. Long responses are executed in a job, and results are broadcast over WebSockets.

7. **Testing and quality assurance:**

   - Unit‑test the `ProductTool` functions using RSpec to ensure correct filtering and JSON output.
   - Write tests for `AiConsultantAssistant` to verify that instructions are loaded, messages are added correctly, and that tool calls occur when expected.  You can simulate tool outputs to test the assistant’s reasoning without hitting the actual API.
   - Add system tests for the chat UI, verifying that messages are appended and that streaming works under Turbo Streams.  Use Capybara with a JavaScript driver similar to the example in GaggleAMP’s AI content generation tests.

8. **Deployment and scaling:**

   - Configure production environment variables (`OPENAI_API_KEY`, any Pinecone keys) in each environment (development, staging, production).
   - Use caching layers (Redis, Memcached) for conversation context and product query results.
   - Monitor API usage and latency.  Consider fallback to a smaller model (like `gpt-3.5-turbo`) or local models if API costs are high.

9. **Future enhancements & existing tools:**

   - Persist chat history per user so the consultant can remember past preferences and orders.  This will allow more personalized recommendations over time.
   - Fine‑tune prompts or use retrieval‑augmented generation (RAG) by embedding product manuals and pet nutrition articles into a vector store.  This will let the assistant answer deeper product questions.
  - Support multilingual consultations by detecting the user’s language and adapting responses. Existing tool scaffolding under `app/services/llm_assistants/tools/` (e.g., `name_generator`, `tags_generator`, `option_types_fetch`, `taxons_fetch`, `properties_fetch`, `url_fetch`) can serve as patterns for implementing product search/detail/related tools.
   - Add analytics to track which recommendations lead to purchases, enabling continuous improvement.

## Implementation plan and subtasks

| Phase | Subtasks | Description |
|---|---|---|
| **1. Requirements and discovery** | Gather product data | Export product attributes (category, species, ingredients, price) and identify the clarifying questions the AI must ask. Identify cross‑sell categories. |
| | Decide LLM provider & model | Choose OpenAI (e.g., GPT‑4o) and evaluate pricing. Decide whether to use semantic search (vector store) or direct ActiveRecord queries. |
| | Design system prompt | Draft the YAML instructions for the assistant describing its role, the expected questions, and how to call tools. |
| **2. Setup & dependencies** | Add gems | Add `langchainrb`, `ruby-openai`, `hotwire-rails` and `stimulus-rails` to the `Gemfile` and run `bundle install`. |
| | Configure credentials | Store OpenAI API key and optional vector store keys using Rails encrypted credentials or environment variables. |
| | Implement LLM service | Use existing initializer `config/initializers/langchainrb.rb` to configure `LLM.default` (e.g., `Langchain::LLM::OpenAI.new`). |
| **3. Build the product tool** | Create under `app/services/llm_assistants/tools/` | Extend `Langchain::ToolDefinition`. Use `define_function` to expose `search_products`, `product_details`, `related_products`. Implement via `Spree::Product` queries. Return JSON arrays/objects. |
| | Write RSpec tests | Verify that each function returns correct results for various criteria (pet type, diet). |
| **4. Build the AI assistant** | Create `app/services/llm_assistants/ai_consultant_assistant.rb` | Load system instructions from YAML; register tools; initialize `Langchain::Assistant` with `LLM.default`. Provide `invoke(messages)` safe for background workers and returning messages for WebSocket broadcast. |
| | Write YAML prompt | Place under `app/services/llm_assistants/prompts/ai_consultant_instructions.yaml`. Instruct AI to ask clarifying questions, call tools, avoid hallucination, summarise recommendations. |
| **5. API and controller** | Add routes | In `config/routes.rb` inside `Spree::Core::Engine.add_routes`, add `post '/ai_chat' => 'spree_vetfort_extension_v5/ai_chats#create'`. |
| | Implement `AiChatsController#create` | Accept `messages`; enqueue a background job that calls `AiConsultantAssistant.invoke` and broadcasts the results over a WebSocket channel. Return immediately (e.g., 202 or small JSON) rather than waiting for the LLM response. |
| | Add authentication (optional) | If you don’t want anonymous users to access the API, wrap the endpoint with Spree’s user authentication. |
| **6. Front‑end integration** | Build chat component | Create partials for chat messages and a form.  Add a Turbo Frame or Turbo Stream to update messages in real time. |
| | Add Stimulus controller | Create `app/javascript/controllers/chat_controller.js` to handle form submit/scroll/reset and subscribe to the Solid Cable channel for chat updates. |
| | Add UI entry point | Place an “Ask AI Consultant” button or link on the store’s layout or product pages.  When clicked, show the chat component (e.g., in a modal or sidebar) and ensure it listens on the WebSocket channel for new messages. |
| **7. Testing** | System tests | Write Capybara tests that simulate a user opening the chat, entering questions, and receiving AI responses.  Test both streaming and non‑streaming flows. |
| | Performance tests | Simulate multiple simultaneous chats to ensure SSE/Turbo Streams scale. |
| **8. Deployment & monitoring** | Configure production env | Set API keys, configure caching, and ensure Action Cable/Solid Cable (WebSockets) is allowed behind your reverse proxy. Configure your background job processor (e.g., Solid Queue) workers. |
| | Monitor usage | Track OpenAI token usage, request latency, and error rates.  Implement alerts if usage spikes. |
| | Plan for fallback | Provide a fallback message if the AI is unavailable or if the rate limit is exceeded. |

## Conclusion

Integrating an AI consultant into your Spree store involves both back‑end (LLM configuration, tools, prompts) and front‑end (chat UI) work.  Using `langchainrb` and patterns from GaggleAMP projects allows you to build a structured assistant that can call Ruby methods to fetch product data, ask clarifying questions, and provide tailored recommendations.  Combining this with Hotwire and Stimulus yields a lightweight, real‑time chat experience.  By following the above plan and subtasks, you can incrementally develop, test and deploy a powerful AI shopping assistant while ensuring performance, security and maintainability.
