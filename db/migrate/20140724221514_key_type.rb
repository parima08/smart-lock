class KeyType < ActiveRecord::Migration
  def change
    add_column :keys, :auto_generated, :boolean, :default => false
  end
end
