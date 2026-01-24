# pin Stimulus dependencies
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
# pin Rails request JS (currently missing in the host)
pin "@rails/request.js", to: "@rails/request.js"
pin "pubsub-js" # @1.9.5
pin "spree_vetfort_extension_v5/storefront", to: "spree_vetfort_extension_v5/storefront.js", preload: true

# engine modules
pin_all_from SpreeVetfortExtensionV5::Engine.root.join("app/javascript/spree_vetfort_extension_v5"),
             under: "spree_vetfort_extension_v5"
