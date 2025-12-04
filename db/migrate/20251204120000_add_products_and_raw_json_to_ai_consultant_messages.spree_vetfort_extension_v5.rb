class AddProductsAndRawJsonToAiConsultantMessages < ActiveRecord::Migration[7.1]
  def change
    if ActiveRecord::Base.connection.adapter_name =~ /sqlite/i
      add_column :spree_vetfort_extension_v5_ai_consultant_messages, :products, :json, default: '[]', null: false
    else
      add_column :spree_vetfort_extension_v5_ai_consultant_messages, :products, :jsonb, default: [], null: false
    end
    add_column :spree_vetfort_extension_v5_ai_consultant_messages, :raw_json, :text
  end
end
