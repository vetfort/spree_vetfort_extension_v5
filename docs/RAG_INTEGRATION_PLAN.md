# RAG Integration Plan for the Vetfort AI Consultant

## 1. How Retrieval‑Augmented Generation works

Retrieval‑Augmented Generation (RAG) combines a language model with a vector search engine.  Instead of asking the model to recall everything from its internal parameters, RAG retrieves relevant documents from a **vector store** and includes them in the prompt before generation.  The typical workflow involves three steps:

1. **Indexing:**  All knowledge sources (in our case, product descriptions, specifications and relevant articles) are chunked, converted into numeric embeddings using an embedding model (e.g., `text‑embedding‑ada‑002`) and stored in a vector database.  Each vector is linked back to its product record.
2. **Retrieval:**  When the user asks a question, the same embedding model converts the query into a vector.  The system performs a nearest‑neighbour search to find the most similar stored vectors.  Similarity is measured via cosine distance or inner product.
3. **Generation:**  The retrieved product snippets are concatenated with the user’s query and passed to the language model.  The model uses this context to generate a grounded answer.

By using RAG, the AI consultant can surface products that match the **intent** behind a query (“something to help calm my nervous cat”) rather than relying solely on exact keywords or tags.  This reduces hallucinations and ensures recommendations are based on up‑to‑date catalog content.

## 2. High‑level implementation

### 2.1 Enabling vector search in Rails

1. **Add pgvector and Neighbor:**  Include `gem 'pgvector'` and `gem 'neighbor'` in your Gemfile, then run `bundle install`.  Generate the vector extension using Neighbor’s generator and run the migration:

   ```
   rails generate neighbor:vector
   rails db:migrate
   ```

   Neighbor registers the `vector` type with ActiveRecord and ensures it appears in schema dumps.

2. **Add an embedding column:**  Decide whether to embed directly on `spree_products` or in a separate table.  For simplicity, add a `vector` column named `embedding` to `spree_products` (dimension 1536 for `text‑embedding‑ada‑002`).  Example migration:

   ```
   add_column :spree_products, :embedding, :vector, limit: 1536, null: false
   add_index :spree_products, :embedding, using: :hnsw  # optional for ANN
   ```

3. **Configure the model:**  In `Spree::Product`, include Neighbor helpers:

   ```
   class Spree::Product < ApplicationRecord
     has_neighbors :embedding  # adds .nearest_neighbors
   end
   ```

   This gives you a simple API for nearest‑neighbour queries.

### 2.2 Generating embeddings

1. **Choose an embedding model:**  Use OpenAI’s embedding API via Langchainrb’s unified interface.  Call `llm.embed(text: description).embedding` to get an array of floats.
2. **Backfill existing records:**  Build a service that iterates over all products, optionally summarises long descriptions, calls the embedding API and writes the vector to `product.embedding`.  Throttle API calls to respect rate limits.
3. **Update on change:**  Add a callback to regenerate the embedding when a product’s description or name changes.  Optionally schedule periodic re‑embeddings if you switch models.

### 2.3 Searching and retrieving

1. **Nearest‑neighbour search:**  When the assistant needs semantic recommendations, embed the user’s query and call:

   ```
   similar = Spree::Product
     .where(product_type: allowed_types)  # apply gating filters:contentReference[oaicite:8]{index=8}
     .nearest_neighbors(:embedding, query_embedding, distance: 'cosine', limit: k)
   ```

   Combining tag filters with vector search ensures species, diet and product‑type rules still apply.

2. **Hybrid and fallback:**  If no similar products are found or similarity scores are low, fall back to your existing tag‑based `ProductsFetch` logic.  You can also use lexical search to complement vector results.

3. **Tool abstraction:**  Encapsulate the search logic in a new tool (e.g., `SemanticProductsSearch`).  The tool accepts `query:` and `k:`, embeds the query, performs the search and returns a structured response containing product IDs, names, URLs and reasons for selection.  Register this tool with the assistant along with `ProductsFetch`.

### 2.4 Prompt and UI updates

* **Assistant instructions:**  Update Dasha’s prompt to mention that she can call `SemanticProductsSearch` when tag‑based filters might miss relevant items.  Provide examples so the LLM learns when to prefer semantic search.
* **Front‑end changes:**  Follow the product separation doc to display vector search results in a dedicated Turbo frame.  Use the existing `ProductsGridComponent` to render results; separate from chat messages so that product grids can update independently.

## 3. How the AI consultant will use vector search

* **Contextual queries:**  When the user asks a broad or fuzzy question (“My dog is bored; what can I get him to keep him occupied?”), the assistant will embed the query and call `SemanticProductsSearch`.  The search will return products such as puzzles, chew toys or training games based on their description embeddings.  Dasha will integrate these results into her response and display them in a product grid.
* **Combination with tags:**  For clearly defined requests (“grain‑free food for a senior cat”), Dasha may rely on the existing tag system.  If the user’s query includes both structured and fuzzy elements, she can first apply tag filters and then run vector search on the filtered set.
* **Cross‑selling:**  After the user selects a product, Dasha can embed the selected product’s description and perform a secondary search for related accessories (e.g., beds or bowls) to suggest complementary items.

## 4. Benefits and future work

Adding RAG to the AI consultant enables more nuanced, context‑aware recommendations, improving customer experience.  It leverages existing infrastructure (Postgres) while providing a path to scale: if the catalogue grows, you can tune HNSW index parameters or migrate to dedicated vector databases like Pinecone or Qdrant.  Future enhancements include advanced re‑ranking, multilingual embeddings and indexing external knowledge sources such as blog posts and FAQs.

## 5. Implementation Refinements

To ensure robustness and performance, the following technical strategies should be adopted:

### 5.1 Asynchronous Updates
Generating embeddings requires a call to OpenAI that can take several hundred milliseconds. To avoid blocking the admin interface:
*   **Drop inline callbacks:** Do not generate embeddings in the request cycle.
*   **Use Background Jobs:** Implement an `after_commit` hook to enqueue a `ProductEmbeddingJob`.
   ```ruby
   after_commit :enqueue_embedding_job, on: %i[create update]

   def enqueue_embedding_job
     ProductEmbeddingJob.perform_later(id)
   end
   ```
*   **Retry Logic:** The job should handle transient API errors (rate limits, timeouts) with automatic retries.

### 5.2 Multilingual Handling
Since the store operates in Romanian and Russian:
*   **Localized Content:** Ensure the `search_content` field includes translated summaries or local slang terms.
*   **Query Translation:** Optionally translate the user’s query to the catalog's primary language before embedding. This often yields better vector similarity than cross-lingual matching.
*   **Language Filtering:** If products have language-specific versions, store the language in metadata and filter by it during retrieval.

### 5.3 Context‑Window Management
Dumping full product descriptions into the LLM prompt is expensive and inefficient.
*   **Summarization:** When indexing, generate a concise `search_content` summary (Name, Benefits, Ingredients, Tags).
*   **Embed Summaries:** Embed this summary, not the full HTML description.
*   **Lean Retrieval:** Pass only these summaries (top 3–5 results) to the LLM generation step to save tokens and reduce latency.
