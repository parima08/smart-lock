class CreateUserDevicesTable < ActiveRecord::Migration
  def change
    create_table :user_devices do |t|
      t.integer  "user_id",         foreign_key: { deferrable: :initially_deferred }
      t.integer  "user_account_id", foreign_key: { deferrable: :initially_deferred, references: :users }
      t.integer  "device_id",       foreign_key: { deferrable: :initially_deferred }
      t.string   "name"          # unused, device nickname
      t.string   "confirmation_token"
      t.datetime "confirmed_at"
      t.string   "authentication_token"
      t.boolean  "authenticated",     default: false
      t.datetime "decommissioned_at"
      t.binary   "private_key"   # openSSL private key pem file
      t.datetime "keys_sent_at"  # Keys have been sent to device
      t.uuid     "uuid"
    end
  end
end
