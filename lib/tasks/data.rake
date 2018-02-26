require_relative 'locks.rb'
require_relative 'init_users.rb'
LOCKS = [
  {:email  => 'glenn.widener@room5.com',
      :name            => "GlennW's Door",
      :orientation        => "left",
      :commission_date => Time.now,
      :bluetooth_address  => "LOCK-GLEN"
  },
  {:email  => 'gabriel.bestard@gojiaccess.com',
      :name            => "Front Door",
      :orientation        => "left",
      :commission_date => Time.now,
      :bluetooth_address  => "@:BC.6A.29.AB.EE.31"
  },
  {:email  => 'gabriel.bestard@gojiaccess.com',
      :name            => "Back Door",
      :orientation        => "left",
      :commission_date => Time.now,
      :bluetooth_address  => "LOCK-GABRIEL"
  },
  {:email  => 'steven.bakondi@gojiaccess.com',
      :name            => "Home",
      :orientation        => "left",
      :commission_date => Time.now,
      :bluetooth_address  => "LOCK-STEVENBHOME"
  },
  {:email  => 'dautermann@mac.com',
      :name            => "MichaelD's Door",
      :orientation        => "left",
      :commission_date => Time.now,
      :bluetooth_address  => "@:BC.6A.29.AB.ED.EE"
  },
  {:email  => 'avinash.mohan@room5.com',
      :name            => "AvinashM's Door",
      :orientation        => "left",
      :commission_date => Time.now,
      :bluetooth_address  => "LOCK-AVINASHM"
  },
  {:email  => 'lars.finander@room5.com',
      :name            => "LarsF's Door",
      :orientation        => "left",
      :commission_date => Time.now,
      :bluetooth_address  => "@:BC.6A.29.AB.EE.31",
      :lock_serial     => "LARSF_SERIAL"
  },
  {:email  => 'rocky.sherriff@room5.com',
      :name            => "RockyS's Door",
      :orientation        => "left",
      :commission_date => Time.now,
      :bluetooth_address  => "@:BC.6A.29.AB.EE.1F",
      :lock_serial     => "ROCKY_DOOR_SERIAL"
  },
  {:email  => 'steven.reid@room5.com',
      :name            => "StevenR's Door",
      :orientation        => "left",
      :commission_date => Time.now,
      :bluetooth_address  => "LOCK-STEVENR"
  },
  {:email  => 'sakluger@gmail.com',
      :name            => "SashaK's Door",
      :orientation        => "left",
      :commission_date => Time.now,
      :bluetooth_address  => "LOCK-SASHAK"
  },
  {:email  => 'johngray@mac.com',
      :name            => "JohnG's Door",
      :orientation        => "left",
      :commission_date => Time.now,
      :bluetooth_address  => "LOCK-JOHNG"
  },
  {:email  => 'hmsdragon@gmail.com',
      :name            => "HowardS's Door",
      :orientation        => "left",
      :commission_date => Time.now,
      :bluetooth_address  => "LOCK-HOWARDS"
  },
  {:email  => 'parima.shah@room5.com',
      :name            => "ParimaS's Door",
      :orientation        => "left",
      :commission_date => Time.now,
      :bluetooth_address  => "LOCK-PARIMAS"
  },
  {:email  => 'ron.langhi@room5.com',
      :name            => "RonL's Door",
      :orientation        => "left",
      :commission_date => Time.now,
      :bluetooth_address  => "LOCK-RONL"
  },
  {:email  => 'daniel.arvidsson@room5.com',
      :name            => "DanielA's Door",
      :orientation        => "left",
      :commission_date => Time.now,
      :bluetooth_address  => "EDB-5B-8D-E8"
  },
  {:email  => 'warren.fox@room5.com',
      :name            => "WarrenF's Door",
      :orientation        => "left",
      :commission_date => Time.now,
      :bluetooth_address  => "@:BC.6A.29.AB.EE.F9",
      :lock_serial     => "WARRENF_DOOR"
  },
  {:email  => 'tom.mccurdie@gojiaccess.com',
      :name            => "TomM's Door",
      :orientation        => "left",
      :commission_date => Time.now,
      :bluetooth_address  => "EDB-00-27-57"
  },
  {:email  => 'william.schmidt@room5.com',
      :name            => "WilliamS's Door",
      :orientation        => "left",
      :commission_date => Time.now,
      :bluetooth_address  => "LOCK-WILLIAM",
      :lock_serial     => "WILLIAM_DOOR"
  },
  {:email  => 'goji-owner@room5.com',
      :name            => "GojiOwner's Door",
      :orientation        => "left",
      :commission_date => Time.now,
      :bluetooth_address  => "@:BC.6A.29.AB.EE.31",
      :lock_serial     => "GOJIOWNER_SERIAL"
  },
  {:email  => 'mark.vanderpol@room5.com',
      :name            => "MarkV's Door",
      :orientation        => "left",
      :commission_date => Time.now,
      :bluetooth_address  => "@:BC.6A.29.AB.D8.E9",
      :lock_serial     => "MARKV_SERIAL"
  },
  {:email  => 'patrick.mealey@room5.com',
      :name            => "PatrickM's Door",
      :orientation        => "left",
      :commission_date => Time.now,
      :bluetooth_address  => "PATRICKM-BLE",
      :lock_serial     => "PATRICKM_SERIAL"
  },
  {:email  => 'radovan.lekanovic@room5.com',
      :name            => "RadovanL's Door",
      :orientation        => "left",
      :commission_date => Time.now,
      :bluetooth_address  => "RADOVAN-BLE",
      :lock_serial     => "RADOVANL_SERIAL"
  },
  {:email  => 'joseph.hutchins@room5.com',
      :name            => "JosephH's Door",
      :orientation        => "left",
      :commission_date => Time.now,
      :bluetooth_address  => "JOSEPHH-BLE",
      :lock_serial     => "JOSEPHH_SERIAL"
  },
  {:email  => 'yong.lan@room5.com',
      :name            => "YongL's Door",
      :orientation        => "left",
      :commission_date => Time.now,
      :bluetooth_address  => "YONGL-BLE",
      :lock_serial     => "YONGL_SERIAL"
  },
  {:email  => 'dennis.mcghie@room5.com',
      :name            => "DennisM's Door",
      :orientation        => "left",
      :commission_date => Time.now,
      :bluetooth_address  => "DENNISM-BLE",
      :lock_serial     => "DENNISM_SERIAL"
  },
]
KEYS = [
  # required owner keys auto-generated.
  {:name => "Home",
    :orientation => "left",
    :email => 'fivestar@example.com',
    :owner => 'steven.bakondi@gojiaccess.com',
    :notify_locked => true,
    :notify_unlocked => true,
    :notify_denied   => true,
  },
  {:name => "Home",
    :orientation => "left",
    :email => 'john.doe@example.com',
    :owner => 'steven.bakondi@gojiaccess.com',
    :notify_locked => true,
    :notify_unlocked => true,
    :notify_denied   => true,
  },
  {:name => "Back Door",
    :orientation => "left",
    :email => 'sarah.smith@example.com',
    :owner => 'gabriel.bestard@gojiaccess.com',
    :notify_locked => true,
    :notify_unlocked => true,
    :notify_denied   => true,
  },
  {:name => "Front Door",
    :orientation => "left",
    :email => 'house.cleaner@example.com',
    :owner => 'gabriel.bestard@gojiaccess.com',
    :notify_locked => true,
    :notify_unlocked => true,
    :notify_denied   => true,
  },
  {:name => "Front Door",
    :orientation => "left",
    :email => 'dog.walker@example.com',
    :owner => 'gabriel.bestard@gojiaccess.com',
    :notify_locked => true,
    :notify_unlocked => true,
    :notify_denied   => true,
  },
  {:name => "Front Door",
    :orientation => "left",
    :email => 'airbnb.guest@example.com',
    :owner => 'gabriel.bestard@gojiaccess.com',
    :notify_locked => true,
    :notify_unlocked => true,
    :notify_denied   => true,
  },
  {:name => "RockyS's Door",
    :orientation => "left",
    :email => 'daniel.arvidsson@room5.com',
    :owner => 'rocky.sherriff@room5.com',
    :notify_locked => true,
    :notify_unlocked => true,
    :notify_denied   => true,
  },
  {:name => "WarrenF's Door",
    :orientation => "left",
    :email => 'daniel.arvidsson@room5.com',
    :owner => 'warren.fox@room5.com',
    :notify_locked => true,
    :notify_unlocked => true,
    :notify_denied   => true,
  },
  {:name => "ParimaS's Door",
    :orientation => "left",
    :email => 'glenn.widener@room5.com',
    :owner => 'parima.shah@room5.com',
    :notify_locked => true,
    :notify_unlocked => true,
    :notify_denied   => true,
    :admin => true
  },
  {:name => "StevenR's Door",
    :orientation => "left",
    :email => 'glenn.widener@room5.com',
    :owner => 'steven.reid@room5.com',
    :notify_locked => true,
    :notify_unlocked => true,
    :notify_denied   => true,
  },
]


def delete_file(name)
  print("Deleted #{name}\n")
  rm_rf(Dir.glob(name), :verbose => false)
end

namespace :db do

  # See notes on load_users_locks.
  desc "reload the test data on a site without migrations"
  task :reload_data => [:environment] do
    clean_all
    load_users_locks
  end

  desc "clear the test data on a site without migrations"
  task :clear_data => [:environment] do
    clean_all
  end

  desc "populate test data"
  task :load_data => [:environment] do
    load_users_locks
  end

  # Add new users from init_users.rb without disturbing existing accounts.
  desc "add new users"
  task :add_users => [:environment] do
    device_id = get_test_device()
    USERS.each do |user|
      new_account(user, device_id)
    end
  end
end

DEF_TZ = "Central Time (US & Canada)"

# Create account, user, and dummy user_device for testing.
def new_account(params, device_id)
  # necessary !
  Account.reset_column_information

  first_name, last_name = params[:name].split(" ")
  user = User.new
  user.time_zone     = DEF_TZ
  account = Account.create do |a|
    # set up the user metadata first
    a.admin                 = params[:admin]
    a.email                 = params[:email]
    a.first_name            = params[:name].split(" ")[0]
    a.last_name             = params[:name].split(" ")[1..-1].join(' ')
    a.password              = params[:password]
    a.password_confirmation = params[:password]
    a.user                  = user
    a.confirmed_at          = Time.now
  end

  # Change auth token to something reasonable for easier testing/debugging
  account.authentication_token = params[:name].split(" ")[0].downcase
  if (account.save)
    user.save
    puts 'New account / user created!'
    puts 'Email   : ' << account.email
    puts 'Password: ' << account.password
  else
    puts "Email \"#{account.email}\" already exists!"
  end
  UserDevice.create!(:user_id => user.id,
                     :device_id => device_id,
		     :confirmed_at => DateTime.now)
end

# Create a lock either from original data (lock_attr has :email), or
# saved data assuming matching user already created. (lock_attr has :user_id)
# Also create the required owner key.
def make_lock(lock_attr)
  if lock_attr[:id]
    # saved data
    account = User.find(lock_attr[:user_id]).account
    # Just for puts:
    lock_attr[:email] = account.email
  else
    account = Account.find_by_email(lock_attr[:email])
    lock_attr[:user_id] = account.user.id
  end
  puts 'Creating Lock for... ' + lock_attr[:email]
  if !lock_attr[:lock_serial]
    # (only in original case)
    lock_attr[:lock_serial] = 'SERIAL-' + lock_attr[:name] + account.user.id.to_s
  end
  lock_attr.delete :email
  lock = Lock.new(lock_attr)
  lock.id = lock_attr[:id] if lock_attr[:id]
  lock.save!
  # Create required owner's key.
  # Perhaps should be dumping and restoring keys too?
  make_key({
             :name => lock.name,
             :orientation => "left",
             :email => lock.user.account.email,
             :owner => lock.user.account.email,
             :notify_locked => true,
             :notify_unlocked => true,
             :notify_denied   => true,
           })
end

def clean_all
    # remove all, even admin, risky if we were to do from admin ui.
    # Could put transaction around this rather than ordering (to avoid foreign_key errors)
    TimeConstraint.delete_all
    Notification.delete_all
    LocksUser.delete_all
    Event.delete_all
    Picture.destroy_all
    Key.delete_all
    # use destroy_all on Lock and Picture, not delete_all, to delete S3 images
    Lock.destroy_all
    Device.delete_all
    User.delete_all
    Account.delete_all
end

def make_key(key_attr)
  puts 'Making Key... ' + key_attr[:email]
  owner_account    = Account.find_by_email(key_attr[:owner])
  key_user_account = Account.find_by_email(key_attr[:email])
  lock    = Lock.where(:user_id  => owner_account.user.id,
                       :name     => key_attr[:name]).first
  # If the lock gets deleted from the live database, skip it's canned keys.
  if lock
    key = Key.create!(:user_id      => key_user_account.user.id,
                      :lock_id      => lock.id,
                      :name         => Key.construct_name(key_user_account.user, lock),
                      :sharer_user_id => owner_account.user.id,
                      :notify_locked => key_attr[:notify_locked],
                      :notify_unlocked => key_attr[:notify_unlocked],
                      :notify_denied => key_attr[:notify_denied],
                      :pending => false,
                      )
  else
    puts 'Lock has been deleted, key skipped!'
  end
end

# Load test data, from captured locks.rb REAL_* if they exist, else
# initial data in init_users.rb and embedded at the top of this file.
#
# Empty the locks.rb saved data file to init from original canned data.
#
# To add new canned accounts in init_users.rb to locks.rb, do this init
# with an empty locks.rb, or run "rake db:add_users" on an active database.
# Recapture entries to locks.rb (rake capture_locks:locks), then collect
# the new entries and add to the existing entries in locks.rb and checkin.

def load_users_locks(admin = false)
  return if Rails.env.test?

  # Create the anonymous device that test users need to upload_firmware.sh.
  anon_device = get_test_device()
  anon_device = Device.create!(device_type: "iosdevelopment") if !anon_device
  puts "use anon_device id=" + anon_device.id.to_s + " in upload_firmware.sh."

  if (defined? REAL_Lock) != nil && REAL_Lock.count > 0
    REAL_Account.each do |account_attr|
      account = Account.new(account_attr)
      # Bypass devise password encryption.  It generates
      # encrypted_password when password is set.
      account.password = "junk"
      account.password_confirmation = "junk"
      account.encrypted_password = account_attr[:encrypted_password]
      account.authentication_token = account_attr[:authentication_token]
      # Force the id for refs in user
      account.id = account_attr[:id]
      account.save!
    end
    REAL_User.each do |user_attr|
      # Force the id for refs in lock
      user = User.new(user_attr)
      user.id = user_attr[:id]
      user.save!
      UserDevice.create!(:user_id => user.id,
                         :device_id => anon_device.id,
			 :confirmed_at => DateTime.now)
    end
    REAL_Lock.each do |lock|
      make_lock(lock)
    end
  else

    USERS.each do |user|
      new_account(user, anon_device.id)
    end
    LOCKS.each do |lock|
      make_lock(lock)
    end
  end
  # These keys are extra non-owner keys that we aren't saving.
  KEYS.each do |key|
    make_key(key)
  end

    # Database hackery to reset auto increment counters, so we get consistent numbers
    # without having to drop the entire database
    # For the reload_data usage.
    # Based on http://joncairns.com/2013/01/reset-postgresql-auto-increment-value-in-rails/
    ['accounts','users','keys','locks','events','notifications','time_constraints','devices','locks_users'].each do |table|
      result = ActiveRecord::Base.connection.execute("SELECT id FROM #{table} ORDER BY id DESC LIMIT 1")
      ai_val = result.any? ? (result.first['id'].to_i + 1) : 1
      puts "Resetting auto increment ID for #{table} to #{ai_val}"
      ActiveRecord::Base.connection.execute("ALTER SEQUENCE #{table}_id_seq RESTART WITH #{ai_val}")
    end

end # load_users_locks()

def get_test_device
  Device.where(ua_token: nil, device_type: "iosdevelopment").first
end

