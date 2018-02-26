class LockLastSync < ActiveRecord::Migration
  def change
    add_column :locks, :last_sync, :datetime 
  end
end
