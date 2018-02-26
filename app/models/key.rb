# == Schema Information
#
# Table name: keys
#
#  id                             :integer          not null, primary key
#  lock_id                        :integer
#  user_id                        :integer
#  original_key_id                :integer
#  user_account_id                :integer          RA clone of user_id
#  sharer_user_id                 :integer
#  revoked                        :datetime
#  replaced_at                    :datetime
#  name                           :string(255)
#  is_fob                         :boolean          default(FALSE)
#  use_count                      :integer
#  use_limit                      :integer
#  start_date                     :datetime
#  end_date                       :datetime
#  notify_owner                   :boolean          default(FALSE)
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  last_used                      :datetime
#  seq_no                         :integer          default(0)
#  pin_code                       :string(4)
#  notify_locked                  :boolean          default(FALSE)
#  notify_unlocked                :boolean          default(FALSE)
#  notify_denied                  :boolean          default(FALSE)
#  expired_notification_generated :boolean          default(FALSE)
#  auto_unlock                    :boolean          default(FALSE)
#  auto_generated                 :boolean          default(FALSE)
#

class Key < ActiveRecord::Base
  #****
  # Extensions - acts_as, extends, etc
  #****
  include DataNormalizer

  PIN_REGEX = /\A\d{4}\z/

  #****
  # Non-persistent variables
  # We could persist replacement for easier key tracing.
  #****
  attr_accessor :extra, :no_share, :change_uuid

  #****
  # Associations
  #****
  belongs_to :lock
  belongs_to :user
  belongs_to :user_account, :primary_key => :user_id
  belongs_to :sharer,  :class_name => 'User', :foreign_key => 'sharer_user_id'
  belongs_to :revoker, :class_name => 'User', :foreign_key => 'revoker_user_id'
  belongs_to :key,     :class_name => 'Key',  :foreign_key => 'original_key_id'
  has_many   :notifications,       :dependent => :delete_all
  # events only reffs notifications, above delete takes care of them.
  has_many   :events,              :dependent => :delete_all
  has_many   :time_constraints,    :dependent => :delete_all
  has_many   :rails_admin_events, -> { order('created_at desc').limit(30) }, :class_name => 'Event'
  has_many   :rails_admin_notifications, -> { order('created_at desc').limit(30) }, :class_name => 'Notification'
  #****
  # Validations
  #****
  validates :lock,            :presence => true
  validates :user,            :presence => true
  validates :sharer,          :presence => true
  validates :name,            :presence => true
  validates :revoker, :presence => true, :if => :revoked?

  # obsolete, expunge
  validates :pin_code,        :format   => { :with => PIN_REGEX },  :allow_blank => true
  validates :start_date,      valid_date_or_empty: true # Custom validator, see validators folder
  validates :end_date,        valid_date_or_empty: true # Custom validator, see validators folder
  validate :start_and_end_date 

  validates_associated :time_constraints

  # This works because revoked is a timestamp, or null
  # Should there ever be the need for two keys revoked at the same time, the single key
  # limitation would no longer apply anyway
  # The advantage of this method, is a custom validator gets a bit tricky, as you have to
  # handle or exclude update cases, etc.
  validates_uniqueness_of :user_id, scope: [:lock_id, :replaced_at, :revoked], message: "user already has active key for this lock"

  def start_and_end_date
    # skipped if either date is invalid - good
    if end_date && start_date && end_date < start_date
      errors.add(:end_date, Util.VALIDATOR_MSGS[:DATE_ORDER])
    end
  end
  #TODO: need validation after lock.commission date

  #****
  # Scopes
  #****
  scope :not_revoked, -> {
    where(revoked: nil)
  }

  scope :active_keys, -> {
    where(revoked: nil).where(replaced_at: nil).joins(:lock).merge(Lock.active)
  }

=begin
  scope :unexpired_keys, -> {
    where('end_date IS NULL OR end_date >= ? AND revoked IS NULL', Time.now)
  }
=end

  #****
  # Callbacks and associated methods
  #****
  after_create  :set_fields
  after_create  :key_created
  before_save   :update_seq_no
  after_save    :key_updated
  # See lock.rb
  after_validation :clone_user_id
  after_destroy :key_changed

  private def set_fields
    # Don't change if already copied from old key on key access change.
    self.original_key_id = id if original_key_id.nil?
    #Must be after_create so id is set, hence two saves.
    self.save!
  end

  private def update_seq_no
    self.seq_no += 1
  end

  def key_shared_notification
    Event.create!(user: sharer,
                  key: self,
                  lock: lock,
                  event_type: EventType::KEY_SHARED,
                  event_time: Time.now,
                  uuid: self.try(:uuid),
                  extra: {
                    fresh_password: self.user.fresh_password,
                  })
  end

  private def key_created
    key_shared_notification if !no_share
    key_changed
  end

  private def key_updated
    # Not creating an event for an expired notification
    key_revoked_notify if self.revoked?
    # Assumes that all updates that affect credentials mark this key
    # replaced, and create a new key (which will update credentials).
    # An odd change from sysadmin or post-revocation would just
    # trigger a useless lock update.
    # key_changed if self.replaced_at
  end

  def key_revoked_notify
    Event.create!(user: revoker,
                  key: self,
                  lock: lock,
                  event_type: EventType::KEY_REVOKED,
                  event_time: Time.now,
                  uuid: self.try(:change_uuid),
                  )
    key_changed
  end

  private def key_changed
    lock.credentials_changed
  end

  #****
  # Class attributes and methods
  #****

  # Persist any key payload time constraints.
  # API supports multiple time_constraints for a key, UI does not.
  # Returns: nil on success, failed record with errors on validation error.
  def self.process_time_constraints(key_data, key)
    return if ! key_data["time_constraints"]
   
    key_data["time_constraints"].each do |tc|
      # XXX obsolete, remove (until then, discarded, not validated)
      start_time = Time.parse(tc["start_time"]) rescue nil
      end_time   = Time.parse(tc["end_time"]) rescue nil
      tc = key.time_constraints.new(
                                    :monday     => tc["monday"],
                                    :tuesday    => tc["tuesday"],
                                    :wednesday  => tc["wednesday"],
                                    :thursday   => tc["thursday"],
                                    :friday     => tc["friday"],
                                    :saturday   => tc["saturday"],
                                    :sunday     => tc["sunday"],
                                    :start_time => start_time,
                                    :end_time   => end_time,
                                    :start_offset=> tc["start_offset"],
                                    :end_offset => tc["end_offset"],
                                    uuid: key_data && key_data["uuid"],
                                   )
      return tc if !tc.save
    end
    return nil  # Otherwise it returns key_data["time_constraints"]!!
  end

  # notifications for expired keys
  def self.notify_expired_keys
    unnotified_expired_keys = self.active_keys.where('keys.end_date IS NOT NULL AND keys.end_date < ? AND keys.expired_notification_generated = ?', Time.now, false).readonly(false).to_a
    unnotified_expired_keys.each do |k|
      event = Event.create!(user: k.user,
                            key: k,
                            lock: k.lock,
                            event_type: EventType::KEY_EXPIRED,
                            event_time: Time.now,
                            # Not from a request, no uuid.
                            )
      if event
        k.expired_notification_generated = true
        k.save!
      end
    end
  end

  # Is there an unrestricted key for this lock+user?
  def self.has_24_7(lock_id, user_id)
    keys = self.where(:lock_id => lock_id,
                      :user_id => user_id,
                      :start_date => nil,
                      # Technically, start_date < now is also unrestricted, not handling this case.
                      :end_date => nil,
                      :replaced_at => nil,
                      :revoked => nil)
                      # not checking use_* - not used.
    keys.each do |key|
      if TimeConstraint.where(:key_id => key.id).count == 0
        return true
      end
    end
    return false
  end

  # Find an auto_generated key.  Currently there should only ever be one.
  # This is obsolete, only used to remove the auto_generated key
  # in the unused PUT locks_keys, when setting admin false.
  def self.auto_generated(lock_id, user_id)
    self.where(:lock_id => lock_id,
               :user_id => user_id,
               :auto_generated => true).first
  end

  # applies some domain logic to how new keys should be named
  def self.construct_name(user, lock)
    # We no longer talk about "keys" to the user.  So repurpose this field for lock name.
    # XXX Stop double-dimensioning!
    # Expunge this field and method in favor of 1) app looking up lock name from lock_id 2) insert at payload generate
    lock.name
=begin
    # leftover from prototype
      key_name = "#{lock.name} Key"
    if user.account.id != lock.user.account.id
      key_name = "#{lock.user.account.first_name}'s " + key_name
    end
    return key_name
=end
  end

  # from_user must be owner/admin
  def self.create_new_key(lock_id, email, from_user, key_data = nil, extra = nil)
    lock = Lock.find(lock_id)
    if lock.owner_and_admins.include?(from_user)
      account = Account.first_by_email(email)
      if account.nil?
        # create an account for an unknown (new) user
        account = Account.new(email: email, user: User.new,
                              uuid: key_data && key_data["uuid"])
        account.new_temp_password
        account.skip_confirmation_notification!
        account.save!
      elsif account.has_temporary_password?
        # per LP18330658, we'll regenerate the temp password and share it again
        account.new_temp_password
        account.save!
      end
      return self.create_user_key(lock_id, account.user,
                                  from_user, key_data, extra)
    else
      return :error => 403
    end
  end

  # lower-level key creation, no user-level notification.  Really?
  def self.create_key(lock_id, to_user, from_user, key_hash, extra = nil)
    self.create_user_key(lock_id, to_user, from_user, key_hash, extra)
  end

  # from_user should not be nil
  # returns:
  # Saved Key object on success.
  # A hash containing :error value on validation error,
  # Exception on other (e.g. db) errors.
  def self.create_user_key(lock_id, to_user, from_user, key_data = nil, extra = nil)
    # create the key and notify existing user
    lock = Lock.find(lock_id)
    key_name = self.construct_name(to_user, lock) # TODO DEPRECATED
    # If this is a commissioning key, then not pending, no new-key
    # event/notification
    owner_key = (from_user != to_user)
    # key_data always present now.
    key = nil
    if key_data
      # Creating key with optional information
      # Transaction is global to connection/all models.
      return {:error => 422, :msg => "Cannot set Time Constraints on an Admin Key"} if key_data["time_constraints"] && key_data["admin"] == true
      Key.transaction do
        key = self.new(lock: lock,
                       user: to_user,
                       name: key_name,
                       pending: owner_key,
                       no_share: owner_key,
                       sharer: from_user,
                       is_fob: key_data["is_fob"],
                       use_limit: key_data["use_limit"],
                       start_date: key_data["start_date"],
                       end_date: key_data["end_date"],
                       notify_owner: key_data["notify_owner"],
                       pin_code: key_data["pin_code"],
                       notify_locked: key_data["notify_locked"],
                       notify_unlocked: key_data["notify_unlocked"],
                       notify_denied: key_data["notify_denied"],
                       auto_unlock: key_data["auto_unlock"],
                       uuid: key_data && key_data["uuid"],
                       extra: extra,
                       )
        if !key.save
          # We believe that .save exceptions on any non-validate errors.
          # format_validation_error is more informative than global
          # rescue (gives model class name).
          key = {:error => 422, :msg => ModelUtil::format_validation_error(key)}
          # Leaves transaction, but that's all, hence key set above.
          raise ActiveRecord::Rollback
        end

        # Exceptions on non-validation errors
        # not .save!, so we can include classname in error message
        tc = process_time_constraints(key_data, key)
        if tc
          key = {:error => 422, :msg => ModelUtil::format_validation_error(tc)}
          raise ActiveRecord::Rollback
        end
        # Create/update the locks-user record (only if owner and admin not nil)
        # XXX LP17278223: invalid to set admin true with time-restrictions!
        # App should be enforcing this (A.3, S.3), so should we.
        # Share code with keys_controller PUT.
        LocksUser.set_admin(lock, from_user.id, to_user, key_data["admin"], skip_admin_event=true)

      end # End Transaction
    else
      # just a basic key (unused outside key_test.rb, test_helper_core)
      key = self.create!(lock: lock,
                         user: to_user,
                         name: key_name,
                         pending: owner_key,
                         no_share: owner_key,
                         sharer: from_user,
                         uuid: key_data && key_data["uuid"],
                         extra: extra,
                         )
    end
    return key
  end

  # Suppress share event on new key on key time changes
  def save_no_share
    self.no_share = true
    save
  end

  #****
  # Instance attributes and methods
  #****

  def name
    return "New Key" if !id
    return "for " + user.account.name
  end

  if defined? rails_admin
    rails_admin do
      parent Lock
      weight -3
      list do
        field :id
        field :lock do
          sortable "locks.name"
          searchable "locks.name" 
        end

        # See lock.rb
        field :user do
          label "Key owner"
          sortable false
          searchable false
        end
        field :user_account do
          visible false
          label "Key owner name/email"
          searchable ["user_accounts.email", "user_accounts.full_name"]
        end
        field :sharer do
          sortable false
        end
        field :time_constraints
        field :replaced_at do
          visible false
          searchable true
        end
        field :revoked do
          visible false
          searchable true
        end
        # LP18818003: hide expired keys.  Date filter needs a test for before/after now!
        # So for now, make available, but can't prepopulate in TOOLS navigation link.
        field :end_date do
          label "Expires"
          visible false
          searchable true
        end
      end
      show do # basic info screen
        field :lock
        field :user do
          label do
            "Key owner"
          end
        end
        field :sharer
        # Rules: (desired section labels)
        field :time_constraints
        field :start_date
        field :end_date
        field :auto_unlock
        # Status:
        field :seq_no
        field :pending
        field :replaced_at
        field :original_key_id
        field :revoked
        field :expired_notification_generated
        # notify_*, last_used, pin_code, display_name unused/deprecated, is_fob, image TBD
        # Related:
        field :rails_admin_events do
          label "Recent Events"
        end
        field :rails_admin_notifications do
          label "Recent Notifications"
        end
=begin
          # https://github.com/sferik/rails_admin/wiki/Associations-scoping
          # XXX LP18519865: not working, comments out there confirm not implemented for views, and it doesn't default to showing only 30.
          associated_collection_cache_all true
          associated_collection_cache_all false
           associated_collection_scope do
            Proc.new { |scope|
              scope = scope.where(id: 18)
              scope = scope.limit(3)
            }
          end
=end
        #end
        # Info:
        field :uuid
        field :id
        field :created_at
        field :updated_at
      end

      edit do
        # XXX DRY: how to use include_fields with a list defined once for edit and info?
        #list =  [ :name, :lock, :user, :sharer ]
        #include_fields list
        field :lock
        field :user do
          label "Key Owner"
        end
        field :sharer
        field :time_constraints
        field :start_date
        field :end_date
        field :auto_unlock
        field :seq_no
        field :pending
        field :replaced_at
        field :original_key_id
        field :revoked
        field :expired_notification_generated
        #field :events
        #field :notifications
      end
    end
  end

  def last_access
    # DRY with lock.rb?
    last_access = Event.where(:key_id => self.id, :event_type => [EventType::LOCK, EventType::UNLOCK]).order('event_time DESC').first
  last_access.try(:event_time)
  end

  def get_locks_users()
    # So, which is more efficient?  Does it matter?
    #lu = LocksUser.where(:user_id => user_id,
    #                     :lock_id => lock.id).first
    lock.locks_users.where(user_id: user_id).first
  end
  def is_admin()
    lu_target = get_locks_users()
    lu_target && lu_target.admin
  end

  # Note that this only considers keys with a fixed end date
  # It's very possible to have a key that currently won't work,
  # but is not expired (due to TimeConstraints)
  def expired?
    self.end_date.present? && (self.end_date < Time.now)
  end

  def revoked?
    self.revoked ? true : false
  end

  # uuid allowed to be nil only when called in tests.
  def revoke!(the_user = nil, uuid = nil)
    self.revoker = the_user if the_user
    self.revoked = Time.now
    self.change_uuid = uuid
    self.save!
  end

  attr_accessible :lock_id, :user_id, :sharer_user_id,
                  :lock, :user, :sharer, :revoked, :replaced_at, 
                  :original_key_id, :name,
                  :is_fob, :pending, :use_count, :use_limit,
                  :start_date, :end_date, :notify_owner,
                  :pin_code, :notification_ids, :time_constraint_ids,
                  :notify_locked, :notify_unlocked, :notify_denied,
                  :auto_unlock, :extra, :uuid #, :change_uuid
end
