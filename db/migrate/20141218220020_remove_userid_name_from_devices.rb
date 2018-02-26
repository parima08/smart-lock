class RemoveUseridNameFromDevices < ActiveRecord::Migration
  def change
    remove_column :devices,  :user_id, :integer, foreign_key: { deferrable: :initially_deferred }
    remove_column :devices,  :user_account_id, :integer, foreign_key: { deferrable: :initially_deferred, references: :users }
    remove_column :devices,  :name, :string
  end
end
