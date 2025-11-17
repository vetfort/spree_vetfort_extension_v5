Spree::Core::Engine.add_routes do
  resources :links, only: [:index], controller: 'spree_vetfort_extension_v5/links'

  # AI Consultant endpoints
  resources :ai_conversations, only: [:create, :index], controller: 'spree_vetfort_extension_v5/ai_conversations', path: 'ai_conversations' do
    post :active_conversation, on: :collection

    resources :ai_messages, only: [:create], controller: 'spree_vetfort_extension_v5/ai_messages'
  end

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
          get :import_map_common_property_select_options
          get :import_map_common_option_select_options
        end
        member do
          post :import
          patch :remap_column
          patch :update_common
          patch :manage_columns
          patch :remove_column
        end

        resources :product_import_rows, only: %i[update] do
          member do
            post :import
            get :import_map_row_taxons_select_options
            get :import_map_row_properties_select_options
          end
        end
      end
    end
  end

  get '/checkout/update/:state', to: redirect { |params, request|
    "/checkout/payment?state=#{params[:state]}"
  }
end
