# == Schema Information
#
# Table name: events
#
#  id            :integer          not null, primary key
#  key_id        :integer          (null on non-key events)
#  lock_id       :integer
#  user_id       :integer          user that inititated the event, if applicable
#  user_account_id :integer        RA clone of user_id
#  picture_id    :integer
#  event_type    :string(255)
#  string_value  :string(255)
#  int_value     :integer
#  event_time    :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  admin_user_id :integer          user gaining or losing admin status
#  bolt_state    :string(255)
#

class Event < ActiveRecord::Base
  #****
  # Extensions - acts_as, extends, etc
  #****
  include DataNormalizer

  #****
  # Associations
  #****
  belongs_to :key
  belongs_to :lock
  belongs_to :picture
  belongs_to :user
  belongs_to :user_account, :primary_key => :user_id
  belongs_to :admin, :class_name => "User", :foreign_key => "admin_user_id"
  has_many   :notifications, :dependent => :delete_all

  #****
  # Validations
  #****
  #XXX LP18520885, post-beta:
  # test for required *_values per type, func shared with notifications
  # test for not-allowed int_values per type
  # Test for required key/lock id per type.
  # Need to nail down failure cases reported on lock/unlock,
  # e.g. hardware failure + invalid key, so we can validate key/lock
  # relationship on all non-key-rejection cases.
  #
  # Then code checks below can be simpler.
  validates_presence_of :lock, :if=> :is_not_device_confirm_type?
  validates_presence_of :key,  :if => :key_id?
  validates_presence_of :user, :if => :user_id?
  validates_presence_of :admin, :if => :admin_user_id?
  validates_presence_of :event_time
  validates_presence_of :event_type
  validates_presence_of :bolt_state,  :if => :is_lock?
  # validator if - clauses don't take an expression, only a method!
  validates_presence_of :string_value,:if => :is_lock?
  validates_presence_of :string_value,:if => :is_status?
  validates :event_type, inclusion: {
    in: EventType.values,
    message: ApplicationController.MESSAGES[:BAD_PARAM],
  }, allow_nil: true  # nil caught above, don't fire misleading not-in-list error
  validates :string_value, inclusion: {
    in: lambda {|e| e.string_values_for e.event_type},
    message: ApplicationController.MESSAGES[:BAD_PARAM],
  }, allow_nil: true
  validates :bolt_state, inclusion: {
    in: BoltState.values,
    message: ApplicationController.MESSAGES[:BAD_PARAM],
  }, allow_nil: true
  # XXX need to validate for other required fields per other event_types.

  #We don't really need to call this, because the string length will always be
  #less than 255 characters with the use of constants...
  validates_with StringLengthValidator
  validate :items_related_to_lock

   def items_related_to_lock
    errors[:base] << ApplicationController.MESSAGES[:NOT_BELONGING] % 'Key' if key && lock && !self.is_lock? && !(key.lock == lock)
    if lock && user && ( self.is_lock? ? lock.keys.select {  |key| key.user == user }.empty? : !lock.owner_and_admins.include?(user) )
      errors[:base] << ApplicationController.MESSAGES[:NOT_BELONGING] % 'Lock'
    end
  end

  def is_lock?
    (event_type == EventType::LOCK) ||
    (event_type == EventType::UNLOCK)
  end

  def is_status?
    (event_type == EventType::BATTERY) ||
    (event_type == EventType::PROXIMITY) ||
    (event_type == EventType::LOCK_COM)
  end

  def is_not_device_confirm_type?
    !(event_type == EventType::USER_DEVICE_CONFIRMED)
  end

  def gets_photo?
    (event_type == EventType::PROXIMITY) ||
      is_lock?
  end

  def string_values_for(event_type)
    case event_type
    when EventType::LOCK, EventType::UNLOCK
      CommandResult.values
    when EventType::BATTERY
      BatteryState.values
    when EventType::PROXIMITY
      ProximityEventType.values
    when EventType::LOCK_COM
      LockCommState.values
    else
      # All other event types are not allowed a string_value at this time
      # Should the need arise, consider :unless option on the validator
      [nil]
    end
  end

  #****
  # Scopes
  #****

  #****
  # Callbacks and associated methods
  #****
  nilify_blanks before: :validation
  before_validation :resolve_relationships
  before_validation :normalize_to_nil
  # See lock.rb
  after_validation :clone_user_id

  def resolve_relationships
    # Ignore any user_id in lock events, it's bogus.
    # Ignore any lock_id in battery/wifi/proximity, ditto.
    # This allows sloppy unit tests.
    # Should throw 400 in controller, per notes.
    if (event_type &&
        (event_type == EventType::LOCK ||
         event_type == EventType::UNLOCK ||
         event_type == EventType::BATTERY ||
         event_type == EventType::LOCK_COM ||
         event_type == EventType::PROXIMITY))
      if (event_type == EventType::BATTERY ||
        event_type == EventType::LOCK_COM ||
        event_type == EventType::PROXIMITY)
        self.key_id = nil
        self.key = nil
      end
      self.user_id = nil
      self.user = nil
    end
    # If we are given a key, but no user, we fill in the user
    # But if we have a user, we can't assume it'll match the key
    self.user = self.key.user if self.key && self.user.nil?
  end

  @@EVENT_ERROR_MESSAGES= [
    "No error message defined",
    " rejected updated key package from server",
    " was unable to update its internal software version. Goji customer support is working on this issue and will let you know when it is resolved",
    " was unable to update its external software version. Goji customer support is working on this issue and will let you know when it is resolved",
  ]

  def get_event_error_message(event_int_value)
    event_int_value = ErrorEventCode::ERR_EV_CODE_UNDEFINED if event_int_value.nil?
    if event_int_value == ErrorEventCode::ERR_EV_CODE_UNDEFINED ||
      event_int_value > ErrorEventCode::ERR_EV_CODE_EXTERNAL_OTA_FAILURE
      return @@EVENT_ERROR_MESSAGES[ErrorEventCode::ERR_EV_CODE_UNDEFINED]
    else
      return "Your Goji Lock " + Lock.find_by_id(lock_id).name + @@EVENT_ERROR_MESSAGES[event_int_value]
    end
  end

  def is_error_event_for_sysadmin_alert_notify
    sysadmin_alert_notify = false
    if (self.event_type == EventType::ERROR_NOTIFY_SYSADMIN ||
       self.event_type == EventType::ERROR_NOTIFY_OWNER_ADMIN)
      key_word = nil
      if self.event_type == EventType::ERROR_NOTIFY_SYSADMIN
        key_word ="Sysadmin: Error Event Alert:"
        sysadmin_alert_notify = true
      else
        key_word ="OwnerAdmin: Error Event Alert:"
      end
      msg = "#{key_word} " + get_event_error_message(self.int_value)
      logger.warn(msg)
    end
    sysadmin_alert_notify
  end

  def normalize_to_nil
    nilify_zeros :user_id, :key_id, :admin_user_id, :picture_id
    true
  end

  # We want to be sure the event record is created regardless of
  # exceptions here, hence after_commit.  Be warned: any exceptions in
  # after_commit disappear except for logging until we change the
  # config in Rails 4.2!
  after_commit :create_notification, on: :create

  def create_notification
    if is_error_event_for_sysadmin_alert_notify
      #Goji sysadmin notification is handed through keyword in the log to Papertrail.
      return
    end
    # This (or related methods) gets to decide who gets notifications when an event happens
    # The Notification then decides how the notification gets sent and the message contents.
    # Suppressing Notifications in some cases

    return true if event_type == EventType::KEY_REVOKED && key && key.expired?
    # Guest notifications.
    # Only send shared to users other than the owner
    # (yes to new admins).
    # Owner key shared only at lock create.
    # LOCK_DECOMMISSIONED triggers KEY_REVOKED to guests, DECOMMISSIONED to owner/admins.
    # Admins is a spec departure, but I think better.
    # Send directly, rather than actually marking keys revoked,
    # else if we un-decommission, we won't be able to distinguish
    # real keys from previously revoked keys.
    oa = lock.owner_and_admins if !lock.nil?
    user_to_notify_id = event_type.start_with?("admin_") ? admin_user_id :
                        key.nil? ? nil : key.user_id

    if (event_type == EventType::LOCK_DECOMMISSIONED)
      self.event_type = EventType::KEY_REVOKED
      # Make KEY_REVOKED send an email
      self.extra = { original: EventType::LOCK_DECOMMISSIONED }
      lock.keys.not_revoked.order('created_at DESC').each do |key|
        # Original spec said send KEY_REVOKED to all but owner,
        # could do that here with special-case below.
        next if oa.include?(key.user)
        self.key = key
        send_guest_notification(key.user.id)
        self.key = nil
      end
      self.event_type = EventType::LOCK_DECOMMISSIONED
      self.extra = nil
    elsif (event_type == EventType::USER_DEVICE_CONFIRMED)
      send_guest_notification(self.user.id)
      # No lock, no additional admin notification.
      return
    else
      send_guest_notification(user_to_notify_id)
    end

    # Owner/admin notifications.
    oa.each do |to_user|
      # Don't send messages to the person who triggered them.
      # They know they did it.  Including lock/unlock key owner.
      if ((self.user_id != to_user.id) &&
          # Don't send admin/owner message to recipient of primary message above.
          # An owner/admin should never get denied!
          (user_to_notify_id != to_user.id))
        nt = Notification.create!(:user_id => to_user.id,
                                  :lock => lock,
                                  :key  => key,   # may be nil for some types
                                  :event => self,
                                  :admin => true,
                                  :extra => extra,
                                  :uuid => uuid
                                  )
        #XXX report a create db error to the event source?  Or mark the notification
        #record as failed for later resend?  Need a story here.
      end
    end if oa
  end

  def send_guest_notification(user_to_notify_id)
    if (event_type != EventType::KEY_SHARED ||
        (user_to_notify_id != lock.user_id)) &&
        ((event_type == EventType::KEY_SHARED ||
          event_type == EventType::KEY_REVOKED ||
          event_type == EventType::KEY_EXPIRED ||
          event_type == EventType::ADMIN_SHARED ||
          event_type == EventType::ADMIN_REVOKED ||
          event_type == EventType::USER_DEVICE_CONFIRMED ||
          event_type == EventType::ACCESS_CHANGED))

      nt = Notification.create!(:user_id => user_to_notify_id,
                                :lock => lock,
                                :key  => key,   # may be nil for some types
                                :event => self,
                                :extra => extra,
                                :uuid => uuid
                                )
    end
  end

  #****
  # Class attributes and methods
  #****

  #****
  # Instance attributes and methods
  #****

  # For Rails Admin, see user.rb:
  def name
    return "New Event"  if !id
    event_type +
      (key.try(:name)  ? (" " + key.name) :
       lock.try(:name) ? (" on " + lock.name) :
       lock.try(:id)   ? (" on lock #" + lock.id.to_s) :
       user.try(:name) ? (" for " + user.name) : "") +
      " (#" + id.to_s + ")"
  end

  if defined? rails_admin
    rails_admin do
      weight -1
      list do
        field :id
        field :lock do
          sortable :name
          searchable "locks.name"
        end
        field :event_type do
          label "Type"
        end
        field :event_time do
          label "Time"
        end
        field :key
        field :user do
          label "Triggering user"
          sortable false
          searchable false
        end
        # See lock.rb
        field :user_account do
          visible false
          label "Triggering user name/email"
          searchable ["user_accounts.email", "user_accounts.full_name"]
        end
        # XXX Doesn't fit, there are ways to adjust field width and count.
        field :bolt_state
        field :string_value
        field :int_value
      end
      show do # basic info screen
        field :lock
        field :event_type do
          label "Type"
        end
        field :event_time do
          label "Time"
        end
        # Ideally, show these only if they exist for event_type (followon to LP18371627)
        # See include_fields_if?
        field :key
        field :user
        field :admin
        field :bolt_state
        field :string_value
        field :int_value
        field :picture
        field :notifications
        field :id
        field :created_at
        field :updated_at
      end
      edit do
        field :lock
        field :event_type do
          label "Type"
        end
        field :event_time do
          label "Time"
        end
        field :key
        field :user
        field :admin
        field :bolt_state
        field :string_value
        field :int_value
        field :picture
        field :notifications
      end
    end
  end

  # Generic hash for adding extra data that will get sent along to the notification
  # Required for all email notifications to generate img urls back to server.
  attr_accessor :extra

  attr_accessible :key_id, :lock_id, :user_id, :admin_user_id, :picture_id, :admin,
                  :key,    :lock,    :user,    :admin_user,    :picture,
                  :event_type, :string_value, :int_value, :event_time, :extra,
                  :bolt_state, :uuid
end
