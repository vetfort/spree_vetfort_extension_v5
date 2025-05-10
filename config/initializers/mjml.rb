require 'mjml-rails'

Mjml.setup do |config|
  config.template_language = :erb
  config.beautify = true
  config.minify = true
  config.use_mrml = true
end
