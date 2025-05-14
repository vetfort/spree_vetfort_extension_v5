# encoding: UTF-8
lib = File.expand_path('../lib/', __FILE__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)

require 'spree_vetfort_extension_v5/version'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_vetfort_extension_v5'
  s.version     = SpreeVetfortExtensionV5::VERSION
  s.summary     = "Spree v5 Vetfort Extension"
  s.required_ruby_version = '>= 3.4'

  s.author    = 'Vladimir Railean'
  s.email     = 'raileanv@gmail.com'
  s.homepage  = 'https://github.com/vetfort/spree_vetfort_extension_v5'
  s.license = 'AGPL-3.0-or-later'

  s.files        = Dir["{app,config,db,lib,vendor}/**/*", "LICENSE.md", "Rakefile", "README.md"].reject { |f| f.match(/^spec/) && !f.match(/^spec\/fixtures/) }
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'spree', '>= 5.0.3'
  s.add_dependency 'spree_storefront', '>= 5.0.3'
  s.add_dependency 'spree_admin', '>= 5.0.3'
  s.add_dependency 'spree_extension'

  s.add_dependency 'mjml-rails'
  s.add_dependency 'mrml'

  s.add_dependency 'ahoy_matey'
  s.add_dependency 'browser'
  s.add_dependency 'geocoder', '~> 1.8'

  s.add_dependency 'dry-validation'
  s.add_dependency 'dry-monads'
  s.add_dependency 'dry-struct'
  s.add_dependency 'dry-system'
  s.add_dependency 'rainbow'
  s.add_dependency 'httparty'
  s.add_dependency 'view_component'

  s.add_development_dependency 'spree_dev_tools'
end
