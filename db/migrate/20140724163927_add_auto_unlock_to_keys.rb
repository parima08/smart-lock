class AddAutoUnlockToKeys < ActiveRecord::Migration
  def change
    add_column :keys, :auto_unlock, :boolean   
  end
end
