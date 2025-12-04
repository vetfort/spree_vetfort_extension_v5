class AddProductsAndRawJsonToAiConsultantMessages < ActiveRecord::Migration[7.1]
  def change
    table = :ai_consultant_messages
    if ActiveRecord::Base.connection.adapter_name =~ /sqlite/i
      add_column table, :products, :json, default: '[]', null: false
    else
      add_column table, :products, :jsonb, default: [], null: false
    end
    add_column table, :raw_json, :text
  end
end
