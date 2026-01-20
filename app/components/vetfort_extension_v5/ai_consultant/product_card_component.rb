class VetfortExtensionV5::AiConsultant::ProductCardComponent < ApplicationComponent
  include Spree::ImagesHelper

  attr_reader :product, :reason

  def initialize(product:, reason: nil)
    @product = product
    @reason = reason
  end

  def display_price
    product.display_price.to_s
  end

  def link_to_product
    Spree::Core::Engine.routes.url_helpers.product_path(product)
  end

  def placeholder_image_url
    SpreeVetfortExtensionV5::Images.product_no_image_placeholder
  end

  def product_name
    product.name || product.name_ru ||  product.name_ro || product.name_en
  end

  private 

  def image 
    product.master&.images&.to_a&.first
  end
end
