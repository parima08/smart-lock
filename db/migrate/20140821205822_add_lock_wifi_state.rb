class AddLockWifiState < ActiveRecord::Migration
  def change
    add_column :locks, :reported_wifi_status, :string, :default => "up"
    add_column :locks, :reported_wifi_time, :datetime
  end
end
