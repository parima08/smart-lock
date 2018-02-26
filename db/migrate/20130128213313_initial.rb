class Initial < ActiveRecord::Migration
	def self.up

	  # These are extensions that must be enabled in order to support this database
	  enable_extension "plpgsql"

	  create_table "accounts", force: true do |t|
	    t.boolean  "admin",                  default: false  # admin has access to firmware upload and db admin web pages.
	    t.string   "first_name"
	    t.string   "last_name"
	    t.string   "full_name"                 # to be removed
	    t.string   "email"
	    t.string   "encrypted_password"
	    t.string   "reset_password_token"
	    t.datetime "reset_password_sent_at"
	    t.string   "authentication_token"    # unused, in user_device
	    t.datetime "remember_created_at"
	    t.integer  "sign_in_count",          default: 0
	    t.datetime "current_sign_in_at"
	    t.datetime "last_sign_in_at"
	    t.string   "current_sign_in_ip"
	    t.string   "last_sign_in_ip"
	    t.datetime "created_at",                             null: false
	    t.datetime "updated_at",                             null: false
	    t.string   "confirmation_token"
	    t.datetime "confirmed_at"        # email is confirmed
	    t.datetime "confirmation_sent_at"
	    t.string   "unconfirmed_email"   # unused currently, do not support email change.
	  end

	  add_index "accounts", ["confirmation_token"], name: "index_accounts_on_confirmation_token", using: :btree

	  create_table "users", force: true do |t|
	    t.integer  "account_id", foreign_key: false
	    t.string   "time_zone"
	    t.datetime "created_at", null: false
	    t.datetime "updated_at", null: false
	  end

	  create_table "devices", force: true do |t|
	    t.integer  "user_id", foreign_key: false
	    t.string   "name"          # unused, device nickname
	    t.string   "apn_token"	# renamed to ua_token
	    #t.string   "device_type"   default: "iOS"   # or "android"
            #t.string   "endpoint_arn"  # AWS notification id
	    t.datetime "created_at"
	    t.datetime "updated_at"
	  end

          add_index "devices", ["user_id"], name: "index_devices_on_user_id", using: :btree

	  create_table "locks", force: true do |t|
	    t.integer  "user_id", foreign_key: false             # lock owner
	    t.string   "name"                # owner-set displayed lock name
	    t.datetime "commission_date"
	    t.string   "lock_serial"         # STMicro Embedded Serial No.
	    t.datetime "created_at",                                         null: false
	    t.datetime "updated_at",                                         null: false
	    t.integer  "seq_no",             default: 0  # unused, expunge
	    t.string   "image_file_name"
	    t.string   "image_content_type"
	    t.integer  "image_file_size"
	    t.datetime "image_updated_at"
	    t.string   "status"              # Remvoed, replaced with bolt_state
	    # t.string   "reported_wifi_status"         default: "up"         # LockCommState::LOCK_COMM_UP, LockCommState::LOCK_COMM_DOWN
	    # t.datetime "reported_wifi_time"
	    t.string   "bluetooth_name"      # changed to bluetooth_address
	    t.string   "location"            # removed, see orientation
            # t.string   "orientation"         # "left", "right"
	    # t.boolean  "auto_unlock_owner"   # owner auto unlocks
	    # t.boolean  "auto_unlock_others"  # others allowed to auto unlock
            # t.string  "internal_version"           # existing board firmware
            # t.string  "external_version"
	    # t.string  "required_internal_version"  # board firmware OTA trigger
	    # t.string  "required_external_version"
	    # t.string  "internal_hw_version"  # info only for alpha
	    # t.string  "external_hw_version"
	    # t.integer  "battery_level"    # 0-100
	    # t.string  "battery_state"     # BatteryState::OK, BatteryState::LOW
            # notification groups TBD
	    t.boolean  "notify_locked",      default: true
	    t.boolean  "notify_unlocked",    default: true
	    t.boolean  "notify_denied",      default: true
            # t.datetime "decommission_date"
	  end

          add_index "locks", ["user_id"], name: "index_locks_on_user_id", using: :btree
	  add_index "locks", ["lock_serial"], name: "index_locks_on_lock_serial", unique: true

	  create_table "locks_users", force: true do |t|
	    t.integer  "lock_id", foreign_key: false
	    t.integer  "user_id", foreign_key: false
	    t.boolean  "admin",                                     default: false
	  end

          add_index "locks_users", ["lock_id"], name: "index_locks_users_on_lock_id", using: :btree
          add_index "locks_users", ["user_id"], name: "index_locks_users_on_user_id", using: :btree

	  create_table "keys", force: true do |t|
	    t.integer  "lock_id", foreign_key: false
	    t.integer  "user_id", foreign_key: false          # key owner
	    t.integer  "inviter_user_id", foreign_key: false  # key issuer, changed to sharer_user_id
	    #t.integer "revoker_user_id", foreign_key: false
	    t.datetime "revoked"
	    t.string   "name"             # Was auto-generated key name, now lock name, cached for app.  Will remove, see code notes.
	    t.boolean  "is_fob",                                    default: false
	    t.boolean  "pending",                                    default: true
	    t.integer  "use_count"        # Unused
	    t.integer  "use_limit"        # Unused
	    t.datetime "start_date"
	    t.datetime "end_date"
	    t.boolean  "notify_owner",                              default: true
	    # t.boolean  "auto_unlock"    # request auto_unlock
	    # t.boolean "auto_generated", 			    default => false  # for lock owner/admin; obsolete, see locks_users_controller.rb
	    t.datetime "created_at",                                                null: false
	    t.datetime "updated_at",                                                null: false
	    t.datetime "last_used"                                  # deprecated
	    t.integer  "seq_no",                                    default: 0  # unused, expunge
	    t.string   "image_file_name"                                             # for all keys for a lock+user?
	    t.string   "image_content_type"
	    t.integer  "image_file_size"
	    t.integer  "identifier"                                 # unused? (dup of id)
	    t.datetime "image_updated_at"
	    t.string   "pin_code",                       limit: 4   # deprecated
            # display_nane is erratic, redundant, replaced, and being expunged.
	    t.string   "display_name",                   limit: 12  # removed, generating user_display_name on the fly
            # unused in sprint 2, may move/copy to locks_users for notification groups:
	    t.boolean  "notify_locked",                             default: true
	    t.boolean  "notify_unlocked",                           default: true
	    t.boolean  "notify_denied",                             default: true
	    t.boolean  "expired_notification_generated",            default: false
	  end

          add_index "keys", ["lock_id"], name: "index_keys_on_lock_id", using: :btree
          add_index "keys", ["user_id"], name: "index_keys_on_user_id", using: :btree

          # unused in prototype, should be used?
	  create_table "event_templates", force: true do |t|
	    t.string   "event_type"       # equals events.event_type
	    t.string   "message"          # how does this relate to config/locales/devise.en.yml?
	    t.string   "description"
	    t.datetime "created_at",  null: false
	    t.datetime "updated_at",  null: false
	  end

	  create_table "pictures", force: true do |t|
	    t.string   "data_file_name"
	    t.string   "data_content_type"
	    t.integer  "data_file_size"
	    t.datetime "data_updated_at"
	    t.datetime "created_at"
	    t.datetime "updated_at"
	  end

          #add_index "events", ["lock_id"], name: "index_events_on_lock_id", using: :btree

	  create_table "events", force: true do |t|
	    t.integer  "key_id", foreign_key: false         # null except on lock/key_* events
	    t.integer  "lock_id", foreign_key: false,      null: false  # "event source lock", required at the API except for keyShared/Revoked/Expired events, where it is copied from key's lock.
	    t.integer  "user_id", foreign_key: false        # User who caused the event, if any
	    #t.integer "admin_user_id", foreign_key: false  # admin_shared/revoked: User gaining/losing admin
	    t.integer  "picture_id", foreign_key: false
	    t.string   "event_type"   # equals Notifications.EVENT_TYPES, e.g. access, wifi, key_shared
	    t.string   "string_value" # battery "low", wifi "down", access "lock", "unlock", "deny"
	    t.integer  "int_value"    # unused (yet)
            # t.string "result"     # new S6: bolt state after access lock/unlock: lock, unlocked, unknown?
	    t.datetime "event_time"
	    t.datetime "created_at",  null: false
	    t.datetime "updated_at",  null: false
	  end

	  create_table "notifications", force: true do |t|
	    t.integer  "picture_id", foreign_key: false
	    t.integer  "user_id", foreign_key: false # recipient
	    t.integer  "lock_id", foreign_key: false
	    t.integer  "key_id", foreign_key: false
	    # t.integer "event_id", foreign_key: false
	    t.string   "event_type" # removed, replaced with event_id
	    t.string   "event_string_value" # removed, replaced with event_id
	    t.datetime "event_time" # removed, replaced with event_id
	    # t.boolean "admin"      # message goes to owner/admin
	    t.string   "message"
	    t.string   "recipient"  # unused, remove
	    t.datetime "read_date"  # set for one of the outstanding notifications, but not read currently.
	    t.datetime "created_at",        null: false
	    t.datetime "updated_at",        null: false
	  end

          add_index "notifications", ["key_id"], name: "index_notifications_on_key_id", using: :btree
          add_index "notifications", ["lock_id"], name: "index_notifications_on_lock_id", using: :btree
          add_index "notifications", ["user_id"], name: "index_notifications_on_user_id", using: :btree

	  create_table "rails_admin_histories", force: true do |t|
	    t.text     "message"
	    t.string   "username"
	    t.integer  "item"
	    t.string   "table"
	    t.integer  "month"
	    t.integer  "year",       limit: 8
	    t.datetime "created_at",           null: false
	    t.datetime "updated_at",           null: false
	  end

	  add_index "rails_admin_histories", ["item", "table", "month", "year"], name: "index_rails_admin_histories", using: :btree

	  create_table "time_constraints", force: true do |t|
	    t.integer  "key_id", foreign_key: false
	    t.boolean  "monday"
	    t.boolean  "tuesday"
	    t.boolean  "wednesday"
	    t.boolean  "thursday"
	    t.boolean  "friday"
	    t.boolean  "saturday"
	    t.boolean  "sunday"
	    t.time     "start_time" # XXX remove (now using *_offset)
	    t.time     "end_time"   # XXX remove
			# t.integer "start_offset"
			# t.integer "end_offset"
	    t.datetime "created_at", null: false
	    t.datetime "updated_at", null: false
	  end

          # Typically, two matching entries for internal and external,
          # but not required.
	  #create_table "firmware", force: true do |t|
          #  t.string   "version"        # version string, for locks table
          #  t.string   "description"
          #  t.boolean  "for_external"    # for external board, else internal
          #  t.string   "download_url"    # generated
	  #  t.string   "data_file_name"  # firmware image
	  #  t.string   "data_content_type"
	  #  t.integer  "data_file_size"
	  #  t.datetime "data_updated_at"
	  #  t.datetime "created_at", null: false
	  #  t.datetime "updated_at", null: false
	  #end
          #add_index :firmwares, ["version", "for_external"], name: "index_firmwares", using: :btree, unique: true

=begin
          # Future, when all firmware doesn't support all hardware:
	  create_table "hardware_version", force: true do |t|
            t.string   "major", #version string
            t.string   "minor", #version string, no firmware dependencies
            t.string   "description"
            t.boolean  "is_external"
            t.boolean  "is_internal"
	  end
	  create_table "hardware_firmware_version", force: true do |t|
            t_integer "hardware_version_id"
            t_integer "firmware_version_id"
	  end
=end
	end

	def self.down
		raise ActiveRecord::IrreversibleMigration
	end
end
