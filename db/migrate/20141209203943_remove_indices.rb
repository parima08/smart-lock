class RemoveIndices < ActiveRecord::Migration
  def change
    remove_index(:devices, column: :user_id, :name => "index_devices_on_user_id")
    remove_index(:locks_users, column: :lock_id, :name => "index_locks_users_on_lock_id")
    remove_index(:locks_users, column: :user_id, :name => "index_locks_users_on_user_id")
    remove_index(:keys, column: :lock_id, :name => "index_keys_on_lock_id")
    remove_index(:keys, column: :user_id, :name => "index_keys_on_user_id")
    remove_index(:locks, column: :user_id, :name => "index_locks_on_user_id")
    remove_index(:notifications, column: :key_id, :name => "index_notifications_on_key_id")
    remove_index(:notifications, column: :lock_id, :name => "index_notifications_on_lock_id")
    remove_index(:notifications, column: :user_id, :name => "index_notifications_on_user_id")
  end
end
