class VetfortExtensionV5::AiConsultant::ProductsGridComponent < ApplicationComponent
  def initialize(products: [])
    @products = Array(products)
  end
  
  def product_entry_to_card_component(entry)
    pid = entry['product_id'] || entry[:product_id]
    reason = entry['reason'] || entry[:reason]
    product = Spree::Product.find_by(id: pid)
    return nil unless product
    
    VetfortExtensionV5::AiConsultant::ProductCardComponent.new(product: product, reason: reason)
  end
end
