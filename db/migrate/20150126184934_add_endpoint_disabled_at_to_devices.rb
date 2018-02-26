class AddEndpointDisabledAtToDevices < ActiveRecord::Migration
  def change
    add_column :devices, :endpoint_disabled_at, :timestamp
  end
end
