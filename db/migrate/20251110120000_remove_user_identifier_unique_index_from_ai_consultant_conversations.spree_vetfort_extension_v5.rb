class RemoveUserIdentifierUniqueIndexFromAiConsultantConversations < ActiveRecord::Migration[7.2]
  def change
    remove_index :ai_consultant_conversations, :user_identifier, unique: true
    add_index :ai_consultant_conversations, :user_identifier
  end
end
