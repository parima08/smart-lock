class AddRevokerUserIdToKey < ActiveRecord::Migration
  def change
    add_column :keys, :revoker_user_id, :integer, foreign_key: false
  end
end
