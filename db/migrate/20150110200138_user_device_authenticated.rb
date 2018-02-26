class UserDeviceAuthenticated < ActiveRecord::Migration
  def change
    remove_column :user_devices, :authenticated,    :integer, default: false
    add_column    :user_devices, :authenticated_at, :datetime
    add_column    :user_devices, :created_at, :datetime
    add_column    :user_devices, :updated_at, :datetime
  end
end
