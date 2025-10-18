# app/controllers/spree/admin/products_controller_decorator.rb
module Decorators
  module Admin
    module ProductsControllerDecorator
      def generate_description
        authorize! :update, @product
        descriptions = OpenAiServices::ProductDescription.new(@product, current_store).call

        descriptions.each do |locale, description|
          key = "description_#{locale}".to_sym
          @product.update(key => description[:description])
        end

        description = descriptions[current_locale.to_sym][:description]

        render json: { success: true, description: }
      end
    end
  end
end

::Spree::Admin::ProductsController.prepend Decorators::Admin::ProductsControllerDecorator
