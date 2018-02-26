# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20150415001556) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "accounts", force: true do |t|
    t.boolean  "admin",                    default: false
    t.string   "first_name"
    t.string   "last_name"
    t.string   "full_name"
    t.string   "email"
    t.string   "encrypted_password"
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.string   "authentication_token"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",            default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "created_at",                               null: false
    t.datetime "updated_at",                               null: false
    t.string   "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string   "unconfirmed_email"
    t.uuid     "uuid"
    t.float    "password_entropy_percent"
    t.boolean  "set_password_from",        default: true
    t.index ["confirmation_token"], :name => "index_accounts_on_confirmation_token"
  end

  create_table "devices", force: true do |t|
    t.string   "ua_token"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "device_type",          default: "iOS"
    t.string   "endpoint_arn"
    t.uuid     "uuid"
    t.string   "os_version"
    t.string   "app_version"
    t.string   "device_model"
    t.datetime "endpoint_disabled_at"
  end

  create_table "event_templates", force: true do |t|
    t.string   "event_type"
    t.string   "message"
    t.string   "description"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  create_table "users", force: true do |t|
    t.integer  "account_id"
    t.string   "time_zone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid     "uuid"
    t.index ["account_id"], :name => "fk__users_account_id"
    t.foreign_key ["account_id"], "accounts", ["id"], :on_update => :no_action, :on_delete => :no_action, :deferrable => :initially_deferred, :name => "fk_users_account_id"
  end

  create_table "locks", force: true do |t|
    t.integer  "user_id"
    t.string   "name"
    t.datetime "commission_date"
    t.string   "lock_serial"
    t.datetime "created_at",                                null: false
    t.datetime "updated_at",                                null: false
    t.integer  "seq_no",                    default: 0
    t.string   "image_file_name"
    t.string   "image_content_type"
    t.integer  "image_file_size"
    t.datetime "image_updated_at"
    t.string   "bolt_state"
    t.string   "bluetooth_address"
    t.boolean  "notify_locked",             default: true
    t.boolean  "notify_unlocked",           default: true
    t.boolean  "notify_denied",             default: true
    t.string   "internal_version"
    t.string   "external_version"
    t.string   "required_internal_version"
    t.string   "required_external_version"
    t.integer  "battery_level"
    t.string   "battery_state"
    t.string   "orientation"
    t.boolean  "auto_unlock_others"
    t.boolean  "auto_unlock_owner"
    t.string   "reported_wifi_status",      default: "up"
    t.datetime "reported_wifi_time"
    t.string   "internal_hw_version"
    t.string   "external_hw_version"
    t.boolean  "reboot",                    default: false
    t.boolean  "debug_log",                 default: false
    t.datetime "decommission_date"
    t.uuid     "uuid"
    t.integer  "user_account_id"
    t.boolean  "new_credentials",           default: true
    t.datetime "last_sync"
    t.string   "serial_label"
    t.string   "time_zone"
    t.index ["user_account_id"], :name => "index_locks_on_user_account_id"
    t.index ["user_id"], :name => "fk__locks_user_id"
    t.foreign_key ["user_account_id"], "users", ["id"], :on_update => :no_action, :on_delete => :no_action, :deferrable => :initially_deferred, :name => "fk_locks_user_account_id"
    t.foreign_key ["user_id"], "users", ["id"], :on_update => :no_action, :on_delete => :no_action, :deferrable => :initially_deferred, :name => "fk_locks_user_id"
  end

  create_table "keys", force: true do |t|
    t.integer  "lock_id"
    t.integer  "user_id"
    t.integer  "sharer_user_id"
    t.datetime "revoked"
    t.string   "name"
    t.boolean  "is_fob",                                   default: false
    t.boolean  "pending",                                  default: true
    t.integer  "use_count"
    t.integer  "use_limit"
    t.datetime "start_date"
    t.datetime "end_date"
    t.boolean  "notify_owner",                             default: true
    t.datetime "created_at",                                               null: false
    t.datetime "updated_at",                                               null: false
    t.datetime "last_used"
    t.integer  "seq_no",                                   default: 0
    t.string   "pin_code",                       limit: 4
    t.boolean  "notify_locked",                            default: true
    t.boolean  "notify_unlocked",                          default: true
    t.boolean  "notify_denied",                            default: true
    t.boolean  "expired_notification_generated",           default: false
    t.boolean  "auto_unlock"
    t.boolean  "auto_generated",                           default: false
    t.integer  "revoker_user_id"
    t.uuid     "uuid"
    t.integer  "user_account_id"
    t.datetime "replaced_at"
    t.integer  "original_key_id"
    t.index ["lock_id"], :name => "fk__keys_lock_id"
    t.index ["revoker_user_id"], :name => "fk__keys_revoker_user_id"
    t.index ["sharer_user_id"], :name => "fk__keys_sharer_user_id"
    t.index ["user_account_id"], :name => "index_keys_on_user_account_id"
    t.index ["user_id"], :name => "fk__keys_user_id"
    t.foreign_key ["lock_id"], "locks", ["id"], :on_update => :no_action, :on_delete => :no_action, :deferrable => :initially_deferred, :name => "fk_keys_lock_id"
    t.foreign_key ["original_key_id"], "keys", ["id"], :on_update => :no_action, :on_delete => :no_action, :deferrable => :initially_deferred, :name => "fk_keys_original_key_id"
    t.foreign_key ["revoker_user_id"], "users", ["id"], :on_update => :no_action, :on_delete => :no_action, :deferrable => :initially_deferred, :name => "fk_keys_revoker_user_id"
    t.foreign_key ["sharer_user_id"], "users", ["id"], :on_update => :no_action, :on_delete => :no_action, :deferrable => :initially_deferred, :name => "fk_keys_sharer_user_id"
    t.foreign_key ["user_account_id"], "users", ["id"], :on_update => :no_action, :on_delete => :no_action, :deferrable => :initially_deferred, :name => "fk_keys_user_account_id"
    t.foreign_key ["user_id"], "users", ["id"], :on_update => :no_action, :on_delete => :no_action, :deferrable => :initially_deferred, :name => "fk_keys_user_id"
  end

  create_table "pictures", force: true do |t|
    t.string   "data_file_name"
    t.string   "data_content_type"
    t.integer  "data_file_size"
    t.datetime "data_updated_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.uuid     "uuid"
    t.datetime "taken_at"
    t.integer  "lock_id"
    t.index ["taken_at", "lock_id"], :name => "index_pictures_on_taken_at", :unique => true
    t.foreign_key ["lock_id"], "locks", ["id"], :on_update => :no_action, :on_delete => :no_action, :deferrable => :initially_deferred, :name => "fk_pictures_lock_id"
  end

  create_table "events", force: true do |t|
    t.integer  "key_id"
    t.integer  "lock_id"
    t.integer  "user_id"
    t.integer  "picture_id"
    t.string   "event_type"
    t.string   "string_value"
    t.integer  "int_value"
    t.datetime "event_time"
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
    t.integer  "admin_user_id"
    t.string   "bolt_state"
    t.uuid     "uuid"
    t.integer  "user_account_id"
    t.index ["admin_user_id"], :name => "fk__events_admin_user_id"
    t.index ["key_id"], :name => "fk__events_key_id"
    t.index ["lock_id"], :name => "fk__events_lock_id"
    t.index ["picture_id"], :name => "fk__events_picture_id"
    t.index ["user_account_id"], :name => "index_events_on_user_account_id"
    t.index ["user_id"], :name => "fk__events_user_id"
    t.foreign_key ["admin_user_id"], "users", ["id"], :on_update => :no_action, :on_delete => :no_action, :deferrable => :initially_deferred, :name => "fk_events_admin_user_id"
    t.foreign_key ["key_id"], "keys", ["id"], :on_update => :no_action, :on_delete => :no_action, :deferrable => :initially_deferred, :name => "fk_events_key_id"
    t.foreign_key ["lock_id"], "locks", ["id"], :on_update => :no_action, :on_delete => :no_action, :name => "fk_events_lock_id"
    t.foreign_key ["picture_id"], "pictures", ["id"], :on_update => :no_action, :on_delete => :no_action, :deferrable => :initially_deferred, :name => "fk_events_picture_id"
    t.foreign_key ["user_account_id"], "users", ["id"], :on_update => :no_action, :on_delete => :no_action, :deferrable => :initially_deferred, :name => "fk_events_user_account_id"
    t.foreign_key ["user_id"], "users", ["id"], :on_update => :no_action, :on_delete => :no_action, :deferrable => :initially_deferred, :name => "fk_events_user_id"
  end

  create_table "firmware_versions", force: true do |t|
    t.string   "default_required_external_version"
    t.string   "default_required_internal_version"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "firmwares", force: true do |t|
    t.string   "version"
    t.string   "description"
    t.boolean  "for_external"
    t.string   "download_url"
    t.string   "data_file_name"
    t.string   "data_content_type"
    t.integer  "data_file_size"
    t.datetime "data_updated_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.uuid     "uuid"
    t.index ["version", "for_external"], :name => "index_firmwares", :unique => true
  end

  create_table "locks_users", force: true do |t|
    t.integer  "lock_id"
    t.integer  "user_id"
    t.boolean  "admin",           default: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.uuid     "uuid"
    t.integer  "user_account_id"
    t.index ["lock_id"], :name => "fk__locks_users_lock_id"
    t.index ["user_account_id"], :name => "index_locks_users_on_user_account_id"
    t.index ["user_id"], :name => "fk__locks_users_user_id"
    t.foreign_key ["lock_id"], "locks", ["id"], :on_update => :no_action, :on_delete => :no_action, :deferrable => :initially_deferred, :name => "fk_locks_users_lock_id"
    t.foreign_key ["user_account_id"], "users", ["id"], :on_update => :no_action, :on_delete => :no_action, :deferrable => :initially_deferred, :name => "fk_locks_users_user_account_id"
    t.foreign_key ["user_id"], "users", ["id"], :on_update => :no_action, :on_delete => :no_action, :deferrable => :initially_deferred, :name => "fk_locks_users_user_id"
  end

  create_table "log_data", force: true do |t|
    t.binary   "data",       null: false
    t.string   "data_type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.uuid     "uuid"
  end

  create_table "logs", force: true do |t|
    t.string   "source"
    t.integer  "lock_id"
    t.integer  "device_id"
    t.datetime "fault_time",  null: false
    t.string   "fault_type"
    t.integer  "log_data_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.uuid     "uuid"
    t.index ["device_id"], :name => "index_logs_on_device_id"
    t.index ["lock_id"], :name => "fk__logs_lock_id"
    t.index ["log_data_id"], :name => "fk__logs_log_data_id"
    t.foreign_key ["lock_id"], "locks", ["id"], :on_update => :no_action, :on_delete => :no_action, :deferrable => :initially_deferred, :name => "fk_logs_lock_id"
    t.foreign_key ["log_data_id"], "log_data", ["id"], :on_update => :no_action, :on_delete => :no_action, :deferrable => :initially_deferred, :name => "fk_logs_log_data_id"
  end

  create_table "notifications", force: true do |t|
    t.integer  "user_id"
    t.integer  "lock_id"
    t.integer  "key_id"
    t.string   "message"
    t.string   "recipient"
    t.datetime "read_date"
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
    t.integer  "event_id"
    t.boolean  "admin"
    t.uuid     "uuid"
    t.integer  "user_account_id"
    t.integer  "devices_tried"
    t.integer  "devices_sent"
    t.index ["event_id"], :name => "fk__notifications_event_id"
    t.index ["key_id"], :name => "fk__notifications_key_id"
    t.index ["lock_id"], :name => "fk__notifications_lock_id"
    t.index ["user_account_id"], :name => "index_notifications_on_user_account_id"
    t.index ["user_id"], :name => "fk__notifications_user_id"
    t.foreign_key ["event_id"], "events", ["id"], :on_update => :no_action, :on_delete => :no_action, :deferrable => :initially_deferred, :name => "fk_notifications_event_id"
    t.foreign_key ["key_id"], "keys", ["id"], :on_update => :no_action, :on_delete => :no_action, :deferrable => :initially_deferred, :name => "fk_notifications_key_id"
    t.foreign_key ["lock_id"], "locks", ["id"], :on_update => :no_action, :on_delete => :no_action, :deferrable => :initially_deferred, :name => "fk_notifications_lock_id"
    t.foreign_key ["user_account_id"], "users", ["id"], :on_update => :no_action, :on_delete => :no_action, :deferrable => :initially_deferred, :name => "fk_notifications_user_account_id"
    t.foreign_key ["user_id"], "users", ["id"], :on_update => :no_action, :on_delete => :no_action, :deferrable => :initially_deferred, :name => "fk_notifications_user_id"
  end

  create_table "rails_admin_histories", force: true do |t|
    t.text     "message"
    t.string   "username"
    t.integer  "item"
    t.string   "table"
    t.integer  "month"
    t.integer  "year",       limit: 8
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
    t.index ["item", "table", "month", "year"], :name => "index_rails_admin_histories"
  end

  create_table "time_constraints", force: true do |t|
    t.integer  "key_id"
    t.boolean  "monday"
    t.boolean  "tuesday"
    t.boolean  "wednesday"
    t.boolean  "thursday"
    t.boolean  "friday"
    t.boolean  "saturday"
    t.boolean  "sunday"
    t.time     "start_time"
    t.time     "end_time"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
    t.integer  "start_offset"
    t.integer  "end_offset"
    t.uuid     "uuid"
    t.index ["key_id"], :name => "fk__time_constraints_key_id"
    t.foreign_key ["key_id"], "keys", ["id"], :on_update => :no_action, :on_delete => :no_action, :deferrable => :initially_deferred, :name => "fk_time_constraints_key_id"
  end

  create_view "user_accounts", "SELECT u.time_zone, u.id AS user_id, a.id, a.admin, a.first_name, a.last_name, a.full_name, a.email, a.encrypted_password, a.reset_password_token, a.reset_password_sent_at, a.authentication_token, a.remember_created_at, a.sign_in_count, a.current_sign_in_at, a.last_sign_in_at, a.current_sign_in_ip, a.last_sign_in_ip, a.created_at, a.updated_at, a.confirmation_token, a.confirmed_at, a.confirmation_sent_at, a.unconfirmed_email, a.uuid FROM (users u JOIN accounts a ON ((u.account_id = a.id)))", :force => true
  create_table "user_devices", force: true do |t|
    t.integer  "user_id"
    t.integer  "user_account_id"
    t.integer  "device_id"
    t.string   "name"
    t.string   "confirmation_token"
    t.datetime "confirmed_at"
    t.string   "authentication_token"
    t.datetime "decommissioned_at"
    t.binary   "private_key"
    t.datetime "keys_sent_at"
    t.uuid     "uuid"
    t.datetime "authenticated_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["device_id"], :name => "fk__user_devices_device_id"
    t.index ["user_account_id"], :name => "fk__user_devices_user_account_id"
    t.index ["user_id"], :name => "fk__user_devices_user_id"
    t.foreign_key ["device_id"], "devices", ["id"], :on_update => :no_action, :on_delete => :no_action, :deferrable => :initially_deferred, :name => "fk_user_devices_device_id"
    t.foreign_key ["user_account_id"], "users", ["id"], :on_update => :no_action, :on_delete => :no_action, :deferrable => :initially_deferred, :name => "fk_user_devices_user_account_id"
    t.foreign_key ["user_id"], "users", ["id"], :on_update => :no_action, :on_delete => :no_action, :deferrable => :initially_deferred, :name => "fk_user_devices_user_id"
  end

end
