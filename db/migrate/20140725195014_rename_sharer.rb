class RenameSharer < ActiveRecord::Migration
  def change
    rename_column :keys, :inviter_user_id, :sharer_user_id
  end
end
