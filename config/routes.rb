Spree::Core::Engine.add_routes do
  resources :links, only: [:index], controller: 'spree_vetfort_extension_v5/links'

  namespace :api do
    namespace :v2 do
      namespace :payments do
        resources :paynet, only: [] do
          collection do
            post :callback
          end
        end
      end
    end
  end

  namespace :payments do
    resources :paynet, only: [] do
      collection do
        get :ok
        get :cancel
      end
    end
  end

  get '/checkout/update/:state', to: redirect { |params, request|
    "/checkout/payment?state=#{params[:state]}"
  }
end
