class ChangeLockColEvents < ActiveRecord::Migration
  def self.up
    change_column :events, :lock_id, :integer, :null => true
  end
  def self.down
    change_column :events, :lock_id, :integer, :null => false
  end
end
