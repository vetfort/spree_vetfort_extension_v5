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

  namespace :admin do
    namespace :vetfort_extension_v5 do
      resources :product_imports, only: %i[index show new edit create update] do
        collection do
          get :template
        end
        member do
          post :import
          patch :remap_column
          patch :update_common
          patch :manage_columns
          patch :remove_column
        end

        resources :product_import_rows, only: %i[update]
      end
    end
  end

  get '/checkout/update/:state', to: redirect { |params, request|
    "/checkout/payment?state=#{params[:state]}"
  }
end
