# == Schema Information
#
# Table name: locks
#
#  id                 :integer          not null, primary key
#  user_id            :integer
#  user_account_id    :integer          RA clone of user_id
#  name               :string(255)
#  commission_date    :datetime
#  decommission_date  :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  seq_no             :integer          default(0)
#  image_file_name    :string(255)
#  image_content_type :string(255)
#  image_file_size    :integer
#  image_updated_at   :datetime
#  bolt_state             :string(255)
#  bluetooth_address  :string(255)
#  orientation        :string(259)
#  auto_unlock_owner  :boolean
#  auto_unlock_others :boolean
#  notify_locked      :boolean          default(FALSE)
#  notify_unlocked    :boolean          default(FALSE)
#  notify_denied      :boolean          default(FALSE)
#  internal_version   :string(255)
#  external_version   :string(255)
#  internal_hw_version         :string(255)
#  external_hw_version         :string(255)
#  required_internal_version   :string(255)
#  required_external_version   :string(255)
#  battery_level     :integer
#  battery_state     :string(255)
#  reboot            :boolean
#  debug_log         :debug_log
#  time_zone         :string
#

class Lock < ActiveRecord::Base

  #****
  # Extensions - acts_as, extends, etc
  #****
  include DataNormalizer
  has_attached_file :image

  #****
  # Associations
  #****
  # The lock owner
  belongs_to :user

  # All RailsAdmin search uses SQL, searched fields must be real DB fields.
  # RA assumes default foreign key and config field names match to
  # connect up search, and can only search 1-level associations.
  # Association must be belongs_to, not has_one/many, so RailsAdmin search
  # will join it.
  # Abandoned solution to searching user_account view:
  # - :user_account association shares user_id foreign key with :user.
  # - :user_account must be listed ahead of user to be connected by RA
  #   to field name by foreign_key in RailsAdmin factories/association.rb
  #   Also see note on has_many limitation below.
  # - Docs claim primary_key defaults to id, but not so - because of foreign_key?
  #belongs_to :user_account, :primary_key => :id, :foreign_key => :user_id
  # primary_key override here keeps view definition simple.
  belongs_to :user_account, :primary_key => :user_id

  has_many   :keys, :dependent => :destroy
  has_many   :notifications, :dependent => :delete_all
  # events only reffs notifications, above delete takes care of them.
  has_many   :events, :dependent => :delete_all
   has_many   :rails_admin_events, -> { order('created_at desc').limit(30) }, :class_name => 'Event'
  has_many   :rails_admin_notifications, -> { order('created_at desc').limit(30) },  :class_name => 'Notification'
  has_many   :pictures, :dependent => :destroy
  # admins for this lock
  has_many   :locks_users,    :dependent => :delete_all
  accepts_nested_attributes_for :locks_users, :allow_destroy => true
  # Get all non-owner user-lock relations (admins).
  # Can we now do select => "distinct users.*", as a user cannot have two locks_user records?
  has_many   :users, :through => :locks_users do
    # Get an array of all users with admin access to the lock.
    # Include the user's account.
    # Here, we don't care about keys, we just want to enumerate the admin users.
    # returns: Relation of joined models: locks. + keys. + users. +users.accounts
    # http://www.spacevatican.org/2008/8/8/nested-includes-and-joins/
    def admins
      # XXX is this includes working?
      result = where('admin = true').includes(:account)
=begin
      return result
      # There should never be two locks_user records (enforced in controller).
      #uni = result.uniq! {|item| id }
      uni = result.uniq! {|item| item.users.id }
      return uni ? uni : result
=end
    end
  end

  #****
  # Validations
  #****
  validates :user_id,         :presence => true
  # Can't do this because of user recommissioning their lock.
  #validates :commission_date, :presence => true, :on => :update
  validates :bluetooth_address,  :presence => true,
                              :format => { :with => /\A[^\ _]+\z/,
                                           :message => "only alphanumeric and hyphens allowed"}
  validates :bolt_state,      :inclusion => { :in => BoltState.values,
                                              :message => "%{value} is not a valid %{attribute}"}, allow_nil: true
  validate                    :one_not_decommissioned

  validates :orientation,     :inclusion => { :in => OrientationType.values,
                                              :message => "%{value} is not a valid %{attribute}"}, allow_nil: true
  firmware_strings = [:name, :orientation, :internal_version, :external_version, :bluetooth_address,
                      :battery_state, :internal_hw_version, :external_hw_version, :bolt_state,
                      :required_internal_version, :required_external_version]
  firmware_strings.each do |n|
    validates_length_of n, maximum: StringLength::STRLIM_GENERAL.to_i
  end

  #not really needed because all string lengths are being checked
  validates_with StringLengthValidator, :exclude => firmware_strings.map{|a| a.to_s}
  validates_with FirmwareVersionValidator, :fields => [:required_external_version, :required_internal_version]

  # Can't be decommissioned unless it's been commisioned at one point
  # This help preserve integrity of various checks that look at both fields
  validates :commission_date, presence: {message: "can't be decommissioned without having been commissioned"}, if: :decommission_date

  # Disallowed at controller, but can't check with DB index now.
  def one_not_decommissioned
    # where not id == me, to make sure we don't block saving ourself when we're not active
    actives = Lock.not_decommissioned.where(lock_serial: lock_serial).where.not(id: self.id)
    if (actives.count > 0)
      errors.add(:lock_serial, ": multiple active locks for one serial not allowed")
    end
  end

  #****
  # Scopes
  #****

  scope :not_decommissioned, -> {
    where(decommission_date: nil)
  }

  scope :active, -> {
    where(decommission_date: nil).where.not(commission_date: nil)
  }

  def active()
    commission_date && !decommission_date
  end

  #
  # Find locks which match either id or lock_serial.
  # There will never be more than one active, but there could be
  # additional lock_serial matches that are not commissioned.
  #
  scope :by_id_or_lock_serial, -> (lock_id, serial) {
    if lock_id.blank? || serial.blank?
      # No nice "OR" query in Rails that I know of, dropping to SQL...
      where('"locks"."id" = ? OR ("locks"."lock_serial" = ? and "locks"."lock_serial" is not null)',
            lock_id.blank? ? nil : lock_id,
            serial.blank?  ? nil : serial)
    else
      where(id: lock_id, lock_serial: serial)
    end
  }

  # Get active lock matching id/lock_serial.
  def self.get_active(params)
    self.get_locks(params).active.first
  end

  def self.get_locks(params)
    Lock.by_id_or_lock_serial(params[:id] ? params[:id] : params[:lock_id],
                              params[:lock_serial])
  end

  def credentials_changed
    return if new_credentials
    self.new_credentials = true
    save!
  end

  # Get priority lock matching id/lock_serial: active first.
  # Need to get not-yet-active lock during commissioning PUT.
  # Probably need to allow non-"active" locks to send events.
  # Will get confused though if there are multiple not not-yet-active
  # or decomissioned lock records.
  def self.get_active_else_not(params)
    locks = self.get_locks(params)
    active_lock = locks.active.first
    return active_lock if active_lock
    uncommissioned = locks.where(commission_date: nil)
    return uncommissioned.first if uncommissioned.count > 0
    locks.first
  end

  # Returns nil if lock.field required*version is absent,
  # else relation with matching firmware record if any.
  def get_firmware(field)
    FirmwareVersionValidator.get_firmware(self, field)
  end

  #****
  # Callbacks and associated methods
  #****
  before_save   :update_seq_no
  nilify_blanks :before => :validation
  # For RailsAdmin search, see above.
  after_validation :clone_user_id

  def update_seq_no
    self.seq_no += 1
  end


  #****
  # Class attributes and methods
  #****
  # Create wifi events based on loss/resumption of status sync.
  def self.check_active
    # Must be slightly longer than longest sync interval to prevent
    # sloppy sync timing from triggering a false down event.  Sync
    # interval currently 10 minutes in devel, production will be
    # longer.
    # Sync interval will ultimately be configurable, at least
    # per-firmware version, so ideally sync interval will be reported
    # to server at provisioning/fw update and max of all devices
    # computed, rather than this duplicate constant.
    prev_sync = Time.now - (@test_mode ? 1.second : (GojiServer.config.status_sync_time + 10.seconds))
    quiet = Lock.active.where("commission_date < ? AND (last_sync IS NULL OR last_sync < ?) AND reported_wifi_status = ?",
                       prev_sync, prev_sync, LockCommState::LOCK_COMM_UP).to_a
    # no uuid available here (clock process)
    send_wifi_events(quiet, LockCommState::LOCK_COMM_DOWN)
    active = Lock.active.where("last_sync > reported_wifi_time AND reported_wifi_status = ?", LockCommState::LOCK_COMM_DOWN).to_a
    send_wifi_events(active, LockCommState::LOCK_COMM_UP)
  end

  # Collect wifi status from any lock access, and generate wifi events
  # since the lock isn't sending them currently.
  def update_with_wifi(status, uuid = nil)
    # We only want to do this when wifi status changes.
    if reported_wifi_status != status
      return create_wifi_event(status, uuid)
    else
      save
    end
  end

  # uuid allowed to be nil only when called in tests.
  def self.send_wifi_events(quiet, status, uuid = nil)
    quiet.each do |lock|
      lock.create_wifi_event(status, uuid)
    end
  end
  # exposed only for testing
  #private_class_method :send_wifi_events

  def create_wifi_event(status, uuid)
    self.reported_wifi_status = status
    # Make reported_wifi_time slightly later than
    # updated_at, to cancel out the compute time here.
    # So we won't think it's a subsequent real update from the lock.
    self.reported_wifi_time = Time.now + 1.second
    return false if !save
    Event.create!(lock_id: id,
                  event_type: EventType::LOCK_COM,
                  string_value: status,
                  event_time: Time.now,
                  uuid: uuid,
                  )
    return true
  end


  #****
  # Instance attributes and methods
  #****

  def commissioned?
    return !commission_date.nil?
  end

  def decommissioned?
    return !decommission_date.nil?
  end

  # Would be nice to put a generic one of these in a helper...
  def display_name
    return "New Lock" if !id
    return "Lock #" + id.to_s if name.blank?
    return name
  end

  #****
  # Rails Admin formatting methods
  #****

  def format_binary_status(status, trueval)
    status = status.nil? ?         ["gray",  "fa fa-question"] :
             (status == trueval) ? ["green", "fa fa-arrow-up"] :
                                   ["red",   "fa fa-arrow-down"]
    return %{<span class='#{status[0]}'>
              <i class='#{status[1]}'></i></span>
            </span>}.html_safe
  end

  def format_wifi_status
    format_binary_status(reported_wifi_status, LockCommState::LOCK_COMM_UP)
  end

  def format_battery_state
    format_binary_status(battery_state, BatteryState::OK)
  end

  def format_sync_time
    age = last_sync ? (Time.now - last_sync) : 0
    time = last_sync ? (age < 1.day) ? last_sync.strftime("%H:%M") :  last_sync.strftime("%m/%d/%y %H:%M") : "?"
    time_color = !last_sync ? "red" :
                 (age > GojiServer.config.status_sync_time * 2) ? "red" :
                 (age > GojiServer.config.status_sync_time) ? "orange" : "green"
    return %{<span class="#{time_color}">#{time}</span> }.html_safe
  end

  def format_bolt_state
    color = bolt_state == BoltState::FAILED ? "red" : "green"
    icon = nil
    case bolt_state
      when BoltState::UNLOCKED
        icon = "fa-unlock"
      when BoltState::LOCKED
        icon = "fa-lock"
      when BoltState::FAILED
        icon = "fa-close"
      when BoltState::MOVING
        icon = "fa-spinner"
    end
    return %{<span class='#{color}' title = "#{bolt_state}">
              <i class = "fa #{icon}"></i>
            </span>}.html_safe
  end

  def error_count(view = nil, time = nil)
    # Not sure why this gets called first with no args by RailsAdmin in show screen.
    return if !view
    #events where - low battery, wifi down, and bolt state failures
    t = Event.arel_table
    start_time = time ? time : commission_date
    errors = Event.where( t[:lock_id].eq(id).and(t[:created_at].gt(start_time))
        .and(t[:event_type].eq(EventType::BATTERY).and(t[:string_value].eq(BatteryState::LOW))
        .or(t[:event_type].eq(EventType::LOCK_COM).and(t[:string_value].eq(LockCommState::LOCK_COMM_DOWN)))
        .or(t[:event_type].eq(EventType::UNLOCK).and(t[:bolt_state].eq(BoltState::LOCKED).or(t[:bolt_state].eq(BoltState::FAILED))))
        .or(t[:event_type].eq(EventType::LOCK).and(t[:bolt_state].eq(BoltState::UNLOCKED).or(t[:bolt_state].eq(BoltState::FAILED))))))
    if view == "list"
      errors.count
    else
      bolt_state_errors = errors.select {|error| error.event_type == EventType::LOCK || error.event_type == EventType::UNLOCK }
      low_battery_errors = errors.select {|error| error.event_type == EventType::BATTERY}
      wifi_down_errors = errors.select {|error| error.event_type == EventType::LOCK_COM}
      return %{<div>
            <p> Bolt State Failures: #{bolt_state_errors.count} </p>
            <p> Battery Low Errors: #{low_battery_errors.count} </p>
            <p> Wifi Down Errors: #{wifi_down_errors.count} </p>
          </div>}.html_safe
    end
  end

  def wifi_downtime(time = nil)
    start_time = commission_date
    # Nothing to report if not yet commissioned.
    return "0%" if !start_time

    #find all wifi events for that object...
    #calculate how much time it took from that event to go back to up...
    wifi_events = Event.where(lock_id: id, event_type: EventType::LOCK_COM, event_time: (start_time..Time.now)).order(event_time: :asc)
    down_time = 0
    # takes into account the time it takes from a reported down to switch to a reported up
    wifi_events.each_with_index do |event, index|
      next if event.string_value == LockCommState::LOCK_COMM_UP
      # in case two downs are reported in a row, this takes care of the time lapsed between them
      if index > 0 && wifi_events[index-1].string_value == LockCommState::LOCK_COMM_DOWN
        down_time += event.event_time - wifi_events[index - 1].event_time
      end
      # time from down to up/end
      if index < wifi_events.length-1
        #logger.debug("# events:" + wifi_events.length.to_s)
        if wifi_events[index+1].string_value == LockCommState::LOCK_COMM_UP
          down_time += wifi_events[index + 1].created_at - event.created_at
        end
      else
        down_time += Time.now - event.event_time
      end
      #logger.debug("down_time=" + down_time.to_s)
    end
    total_time = Time.now - start_time
    #logger.debug("start_time=" + start_time.to_s)
    #logger.debug("total_time=" + total_time.to_s)
    return (down_time.to_f/total_time.to_f * 100).round(1).to_s + "%"
  end

  def format_software_version(field)
    # Even if there's a mismatch before commissioning, display gray.
    # XXX Else if there's a mismatch after first sync, display orange
    # (update should be in progress).  Really, this should be between
    # 1st and 2nd syncs after the requried version is changed...
    # Else if there's a mismatch after the second sync, then there's
    # an error, show red, orange if no required version set.
    required_field = read_attribute(("required_" + field.to_s).to_sym)
    color = commission_date.nil? ? "gray" :
            (read_attribute(field) == required_field) ? "green" :
            required_field ? "red" : "orange"
    return %{<span class="#{color}">#{read_attribute(field)}</span>}.html_safe
  end

 if defined? rails_admin
    rails_admin do
      weight -2
      # Really only want to change this in navigation.
      # Apparently would require RA mods.
      # label "Lock (raw)"
      # label_plural "Locks (raw)"
      list do
        # I don't see any way to avoid duplicating these blocks
        # here and in lock_management.rb.
        # Closure Procs must be defined in the rails_admin..list context to
        # call list methods.  But then they exist only in that context.
        # Works if assigned to a class variable, but that isn't thread safe.
        #  @user_account_conf = Proc.new do... end
        #  @@user_account_conf = Proc.new do... end
        #  field :user_account, &@user_account_conf
        # Tried attaching to bindings (Hash), but that's only
        # accessable from the field method blocks themselves, not from the
        # list/show blocks or field blocks.
        field :uuid
        field :id
        field :name do
          formatted_value do
            bindings[:object].display_name
          end
        end
        field :user do
          label "Owner"
          # Only thing it can search/sort is id, so we have :user_account below.
          # Sort on user ID is just too obscure, hide.
          sortable false
          searchable false
        end
=begin
          # None of these work.  No way to search on a second-level table field/method or first-level/0-level method.
          # Won't do (performance) to blindly include 2nd-level associations.
          # Unless we invent a new RailsAdmin config syntax which
          # explicitly adds 2nd-level associations to the query.
          #        searchable [{:accounts => :full_name}, {:accounts => :email}]
          #        searchable [:users => {:accounts => :full_name}, :users => {:accounts => :email}]
          #        searchable ["users.accounts.name"]
          #        searchable [:users => :name]
          #        searchable [:owner]
=end

        # This field name must match belongs_to user_account foreign key
        # for RailsAdmin to connect it up.
        field :user_account do
          visible false
          # Somehow pretty_value doesn't default to formatted_value here!
          # If you sort on this field, even pretty is rarely called,
          # sometimes one/no calls and one name is displayed for all.
          # So sorry, no sort!
          # Anyway, would have to duplicate field :user_account to
          # label the search differently, and that doesn't work.
=begin
          pretty_value do
#            puts("pretty: bindings[:object].user_account.full_name=" + bindings[:object].user_account_id.class.name)
            bindings[:object].user_account.full_name
          end
          sortable "user_accounts.full_name"
=end
          label "Owner name/email"
          # XXX I believe this will fail if we replace full_name db field with a method.
          searchable ["user_accounts.email", "user_accounts.full_name"]
        end

        field :commission_date do
          visible false
          searchable true
        end
        field :decommission_date do
          visible false
          searchable true
        end
        field :bolt_state do
          pretty_value do
            bindings[:object].format_bolt_state
          end
          column_width 50
        end
        field :keys do
          # Can't search/sort has_many references like this without a mod (with performance implications) to RailsAdmin:
          # http://blog.endpoint.com/2013/07/hasmany-filter-in-railsadmin.html
          # searchable [:name]
          # sortable "keys.name"
        end
        field :lock_serial
        field :serial_label
      end
      show do # basic info screen
        field :name do
          formatted_value do
            bindings[:object].display_name
          end
        end
        field :user do
          label "Owner"
        end
        field :administrators
        field :keys
        # Section headers would be nice: status, configuration
        field :bolt_state
        field :battery_level
        field :battery_state
        field :commission_date
        field :decommission_date
        field :lock_serial
        field :serial_label
        field :bluetooth_address
        field :auto_unlock_owner
        field :auto_unlock_others
        field :orientation
        field :image
        field :required_internal_version
        field :internal_version
        field :required_external_version
        field :external_version
        field :internal_hw_version
        field :external_hw_version
        field :reported_wifi_status
        field :reported_wifi_time
        field :last_sync
        field :new_credentials
        field :reboot do
          label "Reboot requested"
        end
        field :debug_log do
          label "Log requested"
        end
        field :rails_admin_events do
          label "Recent Events"
        end
        field :notifications do 
          label "Recent Notifications"
        end
        field :uuid
        field :id
        field :created_at
        field :updated_at
      end
      edit do
        field :name
        field :user do
          label "Owner"
        end
        field :bolt_state
        field :battery_level
        field :battery_state
        field :commission_date
        field :decommission_date
        field :lock_serial
        field :serial_label
        field :bluetooth_address
        field :auto_unlock_owner
        field :auto_unlock_others
        field :orientation
        field :image
        field :required_internal_version, :enum do
          enum do
            FirmwareVersions.firmware_version_dropdown(false)
          end
        end
        field :internal_version
        field :required_external_version, :enum do
          enum do
           FirmwareVersions.firmware_version_dropdown(true)
          end
        end
        field :external_version
        field :internal_hw_version
        field :external_hw_version
        field :reported_wifi_status
        field :reported_wifi_time
        field :last_sync
        field :new_credentials
        field :reboot do
          label "Request reboot"
        end
        field :debug_log do
          label "Request log"
        end
        # XXX This is funky; deleting records from the list doesn't
        # seem to work on any of the has_many associations, and adding
        # existing also doesn't work (e.g. transaction rollback
        # exception on keys).  Plus a locks_users record will be
        # listed even if the admin flag isn't set.
        # Expose for discussion - at the end...
        field :locks_users do
          label "Administrators" 
          active true
        end
        field :keys
        # removed because they don't work right...
        #field :events
        #field :notifications
      end
    end
  end

  # Decommission and send notifications.
  # Returns false on error.
  def do_decommission(revoker = nil, uuid = nil)
    self.decommission_date = DateTime.now
    return false if !save

    # Might as well be able to tell if it was decommissioned by
    # owner or admins.  Don't reveal which admin!
    Event.create!(lock: self,
                  user_id: (user == revoker) ? revoker.id : nil,
                  event_type: EventType::LOCK_DECOMMISSIONED,
                  event_time: Time.now,
                  uuid: uuid
                  )
    return true
  end

  def administrators
    # Just returning the relation fails, does a to_s on the relation itself.
    adms = []
    admins.all.each do |admin|
      adms << admin.name
    end
    # Would be more consistent to find the RA method used to display model lists...
    # Also, this doesn't generate RA links to the record.
    adms.join(', ')
  end

  # Shorthand:
  def admins
    # () only for readability
    users.admins()
  end

  # Include a record for the lock owner, with empty key
  # XXX may need to dedup, e.g. owner also has a locks_user that is marked admin (abnormal case) ?
  def owner_and_admins
    users.admins << self.user
  end

  def active_keys
    self.keys.active_keys
  end

  # Is account the owner/an admin for this lock?
  def account_is_admin?(account)
    return false if (account == nil) # curl test mode
    account_user_id = account.user.id
    (user.id == account_user_id) ||
      # XXX simpler/faster?: admins.include?(account.user)
    (users.where('admin = true', :user_id => account_user_id).size > 0)
    # size can be faster than .count OR .any
  end

  # XXX obsolete, remove
  def last_access
    total_accesses = []
    self.keys.each do |k|
      access = Event.where(:key_id => k.id, :event_type => [EventType::LOCK, EventType::UNLOCK]).order('event_time DESC').first
        total_accesses << access if access
    end
    unless total_accesses.empty?
      total_accesses.sort{|a,b| b.event_time <=> a.event_time}.first.event_time
    end
  end


  @test_mode = false
  class << self; attr_accessor :test_mode end

  attr_accessible :user_id, :name,
                  :image, :image_file_name, :image_content_type, :image_file_size, :image_updated_at,
                  :bolt_state, :bluetooth_address, :orientation,
                  :commission_date, :decommission_date,
                  :key_ids, :notification_ids, :notify_locked,
                  :notify_unlocked, :notify_denied, :internal_version, :external_version,
                  :required_external_version, :required_internal_version, :battery_level,
                  :internal_hw_version, :external_hw_version,
                  :battery_state, :lock_serial, :auto_unlock_owner, :auto_unlock_others, :last_access,
                  :reboot, :debug_log, :uuid, :new_credentials, :serial_label,
                  :reported_wifi_status, :reported_wifi_time, :last_sync, :locks_users_attributes, :time_zone

  @@settable = accessible_attributes.to_a
  def self.settable
    @@settable
  end
end
