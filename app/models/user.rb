# == Schema Information
#
# Table name: users
#
#  id         :integer          not null, primary key
#  account_id :integer
#  time_zone  :string(255)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class User < ActiveRecord::Base

  #****
  # Extensions - acts_as, extends, etc
  #****
  nilify_blanks :before => :validation

  #****
  # Non-persistent variables
  #****
  # Note: this will need to check the datetime the password was
  # generated, in order to expire and generate a new one when
  # accessed. LP17721652
  attr_accessor :fresh_password # Used to send a temporary password to new invited users

  #****
  # Associations
  #****
  has_many   :locks,         :dependent => :destroy
  has_many   :keys,          :dependent => :destroy
  # Destroy is slow and unnecessary if the reffed record has no sub-records.
  has_many   :notifications, :dependent => :delete_all
  # The user in the notification isn't the same as in the event,
  # must destroy here.  Only using this association for the destroy.
  has_many   :events,        :dependent => :destroy
  has_many   :user_devices,  :dependent => :delete_all
  has_many   :devices,       through: :user_devices
  # admin on other's locks (may also have keys)
  has_many   :locks_user,    :dependent => :delete_all
  has_many   :admined_locks, -> { where "locks_users.admin = true" }, class_name: "Lock", through: :locks_user, source: :lock
  has_many   :active_devices, -> { merge(UserDevice.active) }, class_name: "Device", through: :user_devices, source: :device

  belongs_to :account

  #****
  # Validations
  #****
  validates :account_id, :presence => true, :uniqueness => true
  validates_with StringLengthValidator

  #****
  # Scopes
  #****

  #****
  # Callbacks and associated methods
  #****

  #****
  # Class attributes and methods
  #****

  #****
  # Instance attributes and methods
  #****


  # Active Admin names records using in the following order:
  # :display_name, :full_name, :name, :username, :login, :title, :email, :to_s
  # Reconfigured Rails Admin to match.
  def display_name
    name
  end
  def name
    return "New User"  if !account
    account.full_name || account.email
  end

  if defined? rails_admin
    rails_admin do
      parent UserDevice
      weight -2
      list do
        # XXX LP17598315 follow-on:
        # Need to understand how the generic filter works.
        # It doesn't on user, except for id, some indication that there
        # is no way to filter on belongs_to association fields.
        # filters [:account]
        # Errors:
        # filters [{:accounts => :full_name }]
        # Should we move id out/right in all tables?
        field :id
        field :account do
          # Make it search on what's displayed, plus the id
          # Except id triggers a tolower(integer) SQL error.
          # Can't ref name method even with attr_accessor.
          searchable [:full_name, :email]
          #        searchable [:name, :email]
          #        searchable [{:accounts => :full_name },
          #                    {:accounts => :email },
          #                    {:accounts => :id }]
          # Apparently can't sort on multiple keys (would like to sort on :name, else full_name then email.)
          sortable :full_name
        end
        field :locks do
          label "Owned Locks"
          # Can't sort/search on has_many, table not joined.
        end
        field :user_devices do
          label "User-device"
          searchable [:user_id]
          sortable :user_id
        end
        # Show this only because there is nothing else interesting here
        field :created_at
        field :updated_at
      end
      show do # basic info screen
        field :account
        # Would be nice to show keys only if no locks (no automatic owner keys)?
        field :locks do
          label "Owned Locks"
        end
        field :admined_locks
        field :keys
        field :user_devices do
          label "User-device"
          searchable [:user_id]
          sortable :user_id
        end
        # :time_zone unused
        # "Owned locks" is better...
        #field :locks_user
        field :id
        field :created_at
        field :updated_at
      end
      edit do
        field :account
        field :locks do
          label "Owned Locks"
        end
        field :admined_locks
        field :keys
        field :user_devices do
          label "User-device"
          searchable [:user_id]
          sortable :user_id
        end
        # XXX getting error on id conflict even if we enter an available id in this field:
        # ERROR: duplicate key value violates unique constraint "users_pkey" DETAIL: Key (id)=(3) already exists.
        # Also happening in account, not other tables.
        #field :id 
      end
    end
  end

  def managed_locks
    locks_user_arel = LocksUser.arel_table
    lock_arel = Lock.arel_table
    Lock.active.includes(:locks_users).where(
          ( locks_user_arel[:user_id].eq(self.id)
            .and(locks_user_arel[:admin].eq(true)) )
          .or(lock_arel[:user_id].eq(self.id))
        )
        .references(:locks_users)
  end

  attr_accessible :account_id, :time_zone, :notification_ids, 
                  :key_ids, :lock_ids, :uuid

end
