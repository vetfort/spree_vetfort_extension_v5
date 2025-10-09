class CreateAiConsultantConversations < ActiveRecord::Migration[7.2]
  def change
    create_table :ai_consultant_conversations do |t|
      t.string :user_identifier, null: false
      t.string :status, null: false, default: 'active'
      t.datetime :last_activity_at, precision: 6

      t.timestamps
    end

    add_index :ai_consultant_conversations, :user_identifier, unique: true
    add_index :ai_consultant_conversations, :last_activity_at
  end
end
