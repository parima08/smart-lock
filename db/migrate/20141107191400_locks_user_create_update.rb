class LocksUserCreateUpdate < ActiveRecord::Migration
  def change
    add_column :locks_users, :created_at, :datetime
    add_column :locks_users, :updated_at, :datetime
  end
end
