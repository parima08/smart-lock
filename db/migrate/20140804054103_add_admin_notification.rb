class AddAdminNotification < ActiveRecord::Migration
  def change
    add_column :notifications, :admin, :boolean	# message goes to owner/admin
  end
end
