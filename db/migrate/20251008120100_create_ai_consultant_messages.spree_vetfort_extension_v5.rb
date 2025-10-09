class CreateAiConsultantMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :ai_consultant_messages do |t|
      t.references :ai_consultant_conversation, null: false, foreign_key: true, index: true
      t.string :role, null: false
      t.text :content, null: false
      t.jsonb :tool_calls, null: true, default: {}
      t.jsonb :token_usage, null: true, default: {}

      t.timestamps
    end

    add_index :ai_consultant_messages, :created_at
    add_index :ai_consultant_messages, [:ai_consultant_conversation_id, :created_at]
  end
end
