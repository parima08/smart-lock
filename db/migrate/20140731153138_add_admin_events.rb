class AddAdminEvents < ActiveRecord::Migration
  def change
    add_column :events, :admin_user_id, :integer, foreign_key: false
  end
end
