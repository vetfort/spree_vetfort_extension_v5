Spree::Core::Engine.add_routes do
  resources :links, only: [:index], controller: 'spree_vetfort_extension_v5/links'
end
