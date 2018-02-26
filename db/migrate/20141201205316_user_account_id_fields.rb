class UserAccountIdFields < ActiveRecord::Migration
  def change
    # Cannot have schema_plus's foreign_key constraint refer to a view.
    add_column :locks, :user_account_id, :integer, index: true, foreign_key: { deferrable: :initially_deferred, references: :users }
    add_column :devices, :user_account_id, :integer, index: true, foreign_key: { deferrable: :initially_deferred, references: :users }
    add_column :events, :user_account_id, :integer, index: true, foreign_key: { deferrable: :initially_deferred, references: :users }
    add_column :keys, :user_account_id, :integer, index: true, foreign_key: { deferrable: :initially_deferred, references: :users }
    add_column :locks_users, :user_account_id, :integer, index: true, foreign_key: { deferrable: :initially_deferred, references: :users }
    add_column :notifications, :user_account_id, :integer, index: true, foreign_key: { deferrable: :initially_deferred, references: :users }
    remove_index(:logs, column: :lock_id, name: :index_logs_on_lock_id)
# LP19008046: Temporarily disabled because we delete devices on logout, but keep logs.
# Deleting devices will go away for beta - will be formally decommissioned/archived.
#    remove_index(:logs, column: :device_id, name: :index_logs_on_device_id)
  end
end
