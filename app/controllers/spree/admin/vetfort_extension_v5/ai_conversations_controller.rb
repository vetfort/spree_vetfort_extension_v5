module Spree
  module Admin
    module VetfortExtensionV5
      class AiConversationsController < Spree::Admin::BaseController
        def index
          @conversations = Spree::VetfortExtensionV5::AiConsultantConversation
                            .includes(:messages)
                            .order(created_at: :desc).all
        end

        def show
          @conversation = Spree::VetfortExtensionV5::AiConsultantConversation
                            .includes(:messages)
                            .find(params[:id])
          @messages = @conversation.messages.order(created_at: :asc)
        end
      end
    end
  end
end