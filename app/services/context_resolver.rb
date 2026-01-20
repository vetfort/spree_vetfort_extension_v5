class ContextResolver
  attr_reader :path

  def initialize(path)
    @path = path
  end

  def call
    return if path.blank?

    recognized = recognize_path
    return generic_context if recognized.nil?

    case recognized[:controller]
    when 'spree/products'
      product_context(recognized[:id])
    when 'spree/taxons'
      taxon_context(recognized[:id])
    else
      generic_context
    end
  rescue ActionController::RoutingError, ArgumentError
    generic_context
  end

  private

  def recognize_path
    Rails.application.routes.recognize_path(path, method: :get)
  rescue ActionController::RoutingError
    nil
  end

  def product_context(slug_or_id)
    product = Spree::Product.find_by(slug: slug_or_id) || Spree::Product.find_by(id: slug_or_id)
    return generic_context unless product

    name = product.name
    description = product.description
    ai_searchable_tags = product.tag_list.join(', ')

    sku_or_slug = product.sku.presence || product.slug || product.id
    
    "Context: User is viewing product page: #{name} \n Description: #{description} \n Tags: #{ai_searchable_tags} \n Product ID
    (identifier: #{sku_or_slug})."
  end

  def taxon_context(permalink)
    taxon = find_taxon(permalink)
    return generic_context unless taxon

    "Context: User is browsing category page: #{taxon.name} (permalink: #{taxon.permalink})."
  end

  def find_taxon(permalink)
    Spree::Taxon.find_by(permalink: permalink) || Spree::Taxon.find_by(slug: permalink)
  rescue StandardError
    nil
  end

  def generic_context
    "Context: User is browsing page at path: #{path}."
  end
end

