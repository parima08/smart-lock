class AddEventIdToNotification < ActiveRecord::Migration
  def change
    add_column :notifications, :event_id, :integer, foreign_key: false

    remove_column :notifications, :event_type
    remove_column :notifications, :event_string_value
    remove_column :notifications, :event_time

  end
end
