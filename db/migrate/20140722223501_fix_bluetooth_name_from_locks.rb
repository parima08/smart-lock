#changes bluetooth_name to bluetooth_address

class FixBluetoothNameFromLocks < ActiveRecord::Migration
  def change
  	rename_column :locks, :bluetooth_name, :bluetooth_address
  end
end
