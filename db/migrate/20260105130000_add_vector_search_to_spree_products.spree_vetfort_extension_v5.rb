class AddVectorSearchToSpreeProducts < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!  # allow index creation outside the main transaction

  def change
    add_column :spree_products, :search_content, :text unless column_exists?(:spree_products, :search_content)

    unless vector_extension_available?
      raise <<~MSG
        pgvector is not installed for this PostgreSQL instance.

        PostgreSQL reported that the "vector" extension is not available.
        Install pgvector on the system where PostgreSQL is running, then re-run `rails db:migrate`.

        macOS (Homebrew) typical steps:
          brew install pgvector
          brew services restart postgresql@16

        Verify availability:
          psql -d <db_name> -c "SELECT name FROM pg_available_extensions WHERE name='vector'"
      MSG
    end

    enable_extension 'vector' unless extension_enabled?('vector')

    unless column_exists?(:spree_products, :embedding)
      add_column :spree_products, :embedding, :vector, limit: 1536, null: true
    end

    begin
      add_index :spree_products, :embedding, using: :hnsw unless index_exists?(:spree_products, :embedding)
    rescue ActiveRecord::StatementInvalid
      # Optional performance optimization; keep migration resilient across pgvector/index variations.
    end
  end

  private

  def vector_extension_available?
    result = execute("SELECT 1 FROM pg_available_extensions WHERE name='vector' LIMIT 1")
    result.respond_to?(:ntuples) ? result.ntuples.positive? : result.any?
  rescue StandardError
    false
  end
end
