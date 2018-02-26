class AddVersionFieldsToDevices < ActiveRecord::Migration
  def change
    add_column :devices, :os_version, :string
    add_column :devices, :app_version, :string
    add_column :devices, :device_model, :string
  end
end
