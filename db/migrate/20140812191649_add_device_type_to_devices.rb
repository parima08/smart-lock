class AddDeviceTypeToDevices < ActiveRecord::Migration
  def change
    add_column :devices, :device_type, :string, :default => "iOS"
  end
end
