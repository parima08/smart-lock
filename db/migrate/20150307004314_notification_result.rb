class NotificationResult < ActiveRecord::Migration
  def change
    add_column :notifications,  :devices_tried, :integer
    add_column :notifications,  :devices_sent,  :integer
  end
end
