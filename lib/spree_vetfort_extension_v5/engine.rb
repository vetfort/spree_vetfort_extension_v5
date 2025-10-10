module SpreeVetfortExtensionV5
  class Engine < Rails::Engine
    require 'spree/core'
    isolate_namespace Spree
    engine_name 'spree_vetfort_extension_v5'

    # use rspec for tests
    config.generators do |g|
      g.test_framework :rspec
    end

    initializer 'spree_vetfort_extension_v5.environment', before: :load_config_initializers do |_app|
      SpreeVetfortExtensionV5::Config = SpreeVetfortExtensionV5::Configuration.new
    end

    def self.activate
      Dir.glob(File.join(File.dirname(__FILE__), '../../app/**/*_decorator*.rb')) do |c|
        Rails.configuration.cache_classes ? require(c) : load(c)
      end
    end

    config.to_prepare(&method(:activate).to_proc)

    # initializer 'spree_vetfort_extension_v5.admin_menu_item' do
    #   Rails.application.config.spree_admin.store_nav_partials <<
    #     'spree/admin/shared/sidebar/vetfort_import_nav_item'
    # end

    config.after_initialize do
      Rails.application.config.spree_admin.head_partials << "spree/admin/shared/vetfort_extension_v5_head"
      Rails.application.config.spree_admin.store_products_nav_partials <<
        'spree/admin/shared/sidebar/vetfort_import_nav_item'

      Rails.application.config.spree_storefront.head_partials << "spree/shared/vetfort_extension_v5_storefront_head"
      Rails.application.config.spree_storefront.body_end_partials << 'spree/shared/vetfort_ai_consultant'
    end

    console do
      require 'vetfort/console'

      Object.include Vetfort::Console
    end
    # initializer 'spree_vetfort_extension_v5.helpers' do |app|
    #   ActiveSupport.on_load(:action_controller) do
    #     app.helpers.include SpreeVetfortExtensionV5::ProductImportsHelper
    #   end
    # end

    # config.after_initialize do
      # Rails.application.config.spree_admin.head_partials = []
      # Rails.application.config.spree_admin.body_start_partials = []
      # Rails.application.config.spree_admin.body_end_partials = []
      # Rails.application.config.spree_admin.dashboard_analytics_partials = []
      # Rails.application.config.spree_admin.dashboard_sidebar_partials = []
      # Rails.application.config.spree_admin.product_form_partials = []
      # Rails.application.config.spree_admin.product_form_sidebar_partials = []
      # Rails.application.config.spree_admin.product_dropdown_partials = []
      # Rails.application.config.spree_admin.products_filters_partials = []
      # Rails.application.config.spree_admin.order_page_header_partials = []
      # Rails.application.config.spree_admin.order_page_body_partials = []
      # Rails.application.config.spree_admin.order_page_sidebar_partials = []
      # Rails.application.config.spree_admin.order_page_summary_partials = []
      # Rails.application.config.spree_admin.order_page_dropdown_partials = []
      # Rails.application.config.spree_admin.orders_filters_partials = []
      # Rails.application.config.spree_admin.store_form_partials = []
      # Rails.application.config.spree_admin.store_nav_partials = []
      # Rails.application.config.spree_admin.settings_nav_partials = []
      # Rails.application.config.spree_admin.shipping_method_form_partials = []
      # Rails.application.config.spree_admin.store_settings_nav_partials = []
      # Rails.application.config.spree_admin.store_orders_nav_partials = []
      # Rails.application.config.spree_admin.store_products_nav_partials = []
      # Rails.application.config.spree_admin.storefront_nav_partials = []
      # Rails.application.config.spree_admin.tax_nav_partials = []
      # Rails.application.config.spree_admin.user_dropdown_partials = []
      # ----------------------- spree_storefront -----------------------
      # Rails.application.config.spree_storefront.head_partials = []
      # Rails.application.config.spree_storefront.body_start_partials = []
      # Rails.application.config.spree_storefront.body_end_partials = []
      # Rails.application.config.spree_storefront.cart_partials = []
      # Rails.application.config.spree_storefront.add_to_cart_partials = []
      # Rails.application.config.spree_storefront.remove_from_cart_partials = []
      # Rails.application.config.spree_storefront.checkout_partials = []
      # Rails.application.config.spree_storefront.checkout_complete_partials = []
      # Rails.application.config.spree_storefront.quick_checkout_partials = []
      # Rails.application.config.spree_storefront.product_partials = []
      # Rails.application.config.spree_storefront.add_to_wishlist_partials = []
    # end
  end
end
