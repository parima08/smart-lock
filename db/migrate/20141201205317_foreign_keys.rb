class ForeignKeys < ActiveRecord::Migration
  def up
    change_column :users, :account_id, :integer, foreign_key: { deferrable: :initially_deferred }
    change_column :devices, :user_id, :integer, foreign_key: { deferrable: :initially_deferred }
    change_column :locks, :user_id, :integer, foreign_key: { deferrable: :initially_deferred }
    change_column :locks_users, :lock_id, :integer, foreign_key: { deferrable: :initially_deferred }
    change_column :locks_users, :user_id, :integer, foreign_key: { deferrable: :initially_deferred }
    change_column :keys, :lock_id, :integer, foreign_key: { deferrable: :initially_deferred }
    change_column :keys, :user_id, :integer, foreign_key: { deferrable: :initially_deferred }
    change_column :keys, :sharer_user_id, :integer, foreign_key: { deferrable: :initially_deferred, references: :users }
    change_column :events, :key_id, :integer, foreign_key: { deferrable: :initially_deferred }
    change_column :events, :lock_id, :integer, foreign_key: { deferrable: :initially_deferred }
    change_column :events, :user_id, :integer, foreign_key: { deferrable: :initially_deferred }
    change_column :events, :picture_id, :integer, foreign_key: { deferrable: :initially_deferred }
    change_column :notifications, :picture_id, :integer, foreign_key: { deferrable: :initially_deferred }
    change_column :notifications, :user_id, :integer, foreign_key: { deferrable: :initially_deferred }
    change_column :notifications, :lock_id, :integer, foreign_key: { deferrable: :initially_deferred }
    change_column :notifications, :key_id, :integer, foreign_key: { deferrable: :initially_deferred }
    change_column :time_constraints, :key_id, :integer, foreign_key: { deferrable: :initially_deferred }
    change_column :notifications, :event_id, :integer, foreign_key: { deferrable: :initially_deferred }
    change_column :events, :admin_user_id, :integer, foreign_key: { deferrable: :initially_deferred, references: :users }
    change_column :keys, :revoker_user_id, :integer, foreign_key: { deferrable: :initially_deferred, references: :users }
    change_column :logs, :lock_id, :integer, foreign_key: { deferrable: :initially_deferred }
# LP19008046: Temporarily disabled because we delete devices on logout, but keep logs.
#    change_column :logs, :device_id, :integer, foreign_key: { deferrable: :initially_deferred }
    change_column :logs, :log_data_id, :integer, foreign_key: { deferrable: :initially_deferred }
  end
  def down
    change_column :users, :account_id, :integer, foreign_key: false
    change_column :devices, :user_id, :integer, foreign_key: false
    change_column :locks, :user_id, :integer, foreign_key: false
    change_column :locks_users, :lock_id, :integer, foreign_key: false
    change_column :locks_users, :user_id, :integer, foreign_key: false
    change_column :keys, :lock_id, :integer, foreign_key: false
    change_column :keys, :user_id, :integer, foreign_key: false
    change_column :keys, :sharer_user_id, :integer, foreign_key: false
    change_column :events, :key_id, :integer, foreign_key: false
    change_column :events, :lock_id, :integer, foreign_key: false
    change_column :events, :user_id, :integer, foreign_key: false
    change_column :events, :picture_id, :integer, foreign_key: false
    change_column :notifications, :picture_id, :integer, foreign_key: false
    change_column :notifications, :user_id, :integer, foreign_key: false
    change_column :notifications, :lock_id, :integer, foreign_key: false
    change_column :notifications, :key_id, :integer, foreign_key: false
    change_column :time_constraints, :key_id, :integer, foreign_key: false
    change_column :notifications, :event_id, :integer, foreign_key: false
    change_column :events, :admin_user_id, :integer, foreign_key: false
    change_column :keys, :revoker_user_id, :integer, foreign_key: false
    change_column :logs, :lock_id, :integer, foreign_key: false
#    change_column :logs, :device_id, :integer, foreign_key: false
    change_column :logs, :log_data_id, :integer, foreign_key: false
  end
end
