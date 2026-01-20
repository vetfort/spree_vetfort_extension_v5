namespace :vetfort do
  namespace :embeddings do
    desc 'Enqueue embedding generation for all Spree products (Postgres only)'
    task enqueue_products: :environment do
      unless Spree::Product.column_names.include?('embedding')
        puts 'Skipped: embedding column not present'
        next
      end

      scope = Spree::Product.all
      count = 0

      scope.find_each do |product|
        ProductEmbeddingJob.perform_later(product.id)
        count += 1
      end

      puts "Enqueued ProductEmbeddingJob for #{count} products"
    end
  end
end
