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

    initializer 'spree_vetfort_extension_v5.importmap', before: 'importmap' do |app|
      app.config.importmap.paths << root.join('config/importmap.rb')
      # https://github.com/rails/importmap-rails?tab=readme-ov-file#sweeping-the-cache-in-development-and-test
      app.config.importmap.cache_sweepers << root.join('app/javascript')
    end

    def self.activate
      Dir.glob(File.join(File.dirname(__FILE__), '../../app/**/*_decorator*.rb')) do |c|
        Rails.configuration.cache_classes ? require(c) : load(c)
      end
    end

    config.to_prepare(&method(:activate).to_proc)
  end
end
