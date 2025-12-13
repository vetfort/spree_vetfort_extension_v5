class VetfortExtensionV5::AiConsultant::ProductCardComponent < ApplicationComponent
  def initialize(product:, reason: nil)
    @product = product
    @reason = reason
  end
  
  def image_url
    @product.images.first&.attachment&.url
  end

  def display_price
    @product.display_price.to_s
  end

  def link_to_product
    Spree::Core::Engine.routes.url_helpers.product_path(@product)
  end

  def placeholder_image_url
    SpreeVetfortExtensionV5::Images.product_no_image_placeholder
  end
end
