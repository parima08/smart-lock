# == Schema Information
#
# Table name: notifications
#
#  id         :integer          not null, primary key
#  user_id    :integer          recipient
#  user_account_id :integer     RA clone of user_id
#  lock_id    :integer
#  key_id     :integer
#  message    :string(255)
#  read_date  :datetime         XXX obsolete?
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  event_id   :integer
#  admin      :boolean          is message being sent to an owner/admin?
#

class Notification < ActiveRecord::Base

  #****
  # Extensions - acts_as, extends, etc
  #****
  include DataNormalizer

  # XXX performance: use synbols instead of strings for all constants.
  # Also add an agostic string/symbol compare: a.to_s == b.to_s

  #****
  # Non-persistent variables
  #****
  attr_accessor :push_result
  attr_accessor :extra

  #****
  # Associations
  #****
  belongs_to :user
  belongs_to :user_account, :primary_key => :user_id
  belongs_to :lock
  belongs_to :key
  belongs_to :event

  #****
  # Validations
  #XXX validate for required event_string_values per event_type, func shared with events
  # XXX validate key presence per event type
  # XXX validate admin_user presence per event type
  #****
  validates :user,    :presence => true
  validates_presence_of :lock, :if=> :is_not_device_confirm_type?
  validates :event,   :presence => true
  validates_with StringLengthValidator

  #****
  # Scopes
  #****

  #****
  # Callbacks and associated methods
  #****
  before_validation :normalize_to_nil
  before_create :build_message
  # Allow send_push to modify notification record, but always save it.
  before_create :send_push
  after_create :send_email
  # See lock.rb
  after_validation :clone_user_id

  def normalize_to_nil
    nilify_zeros :key_id
    true
  end

  def is_not_device_confirm_type?
    return true if event.nil?
    event.is_not_device_confirm_type?
  end


  private def l(key, options = {})
    # TODO: Set the locale (:en) here based on the self.user's preference
    I18n.t(key, options.reverse_merge({locale: :en, scope: :NOTIFICATION}))
  end

  def build_message
    # XXX add "was" field and differentiate for *Was* events.
    # better field name? (change in event.rb)
    message = nil
    # assumes caller has validated required fields per event_type
    if !lock.nil?
      lock_name         = "#{lock.name}"
    end
    event_time_string = "#{Notification.fdt(event.event_time)}"
    target_user       = event.admin_user_id ? User.find_by_id(event.admin_user_id) : key ? key.user : nil

    target_user_name =  target_user ?  "#{target_user.display_name}" : nil
    case event.event_type
    # TBD: for NLS: strings from event_templates.message?
    when EventType::LOCK
      case event.string_value
      when CommandResult::SUCCESS
        # message = "#{lock_name} was locked at #{event_time_string} by #{target_user_name}"
        message = l(:LOCK_SUCCESS, lockName: lock_name, eventTimeString: event_time_string, targetUserName: target_user_name)
      else
        message = self.class.access_failure_message(lock_name, target_user_name, event.event_type, event.string_value, event.bolt_state)
      end
    when EventType::UNLOCK
      case event.string_value
      when CommandResult::SUCCESS
        # message = "#{lock_name} was unlocked at #{event_time_string} by #{target_user_name}"
        message = l(:UNLOCK_SUCCESS, lockName: lock_name, eventTimeString: event_time_string, targetUserName: target_user_name)
      else
        message = self.class.access_failure_message(lock_name, target_user_name, event.event_type, event.string_value, event.bolt_state)
      end
    when EventType::LOCK_COM
      case event.string_value
      when LockCommState::LOCK_COMM_DOWN
        message = "#{lock_name} has lost connection to the Goji service"
      when LockCommState::LOCK_COMM_UP
        message = "#{lock_name} has regained connection to the Goji service"
      end
    when EventType::BATTERY
      case event.string_value
      when BatteryState::LOW
        message ="Replace battery in #{lock_name} soon"
      when BatteryState::OK
        message = "Battery level in #{lock_name} is okay"
      end
    when EventType::PROXIMITY
      message = "Someone is near #{lock_name}"
    when EventType::KEY_SHARED
      lock_owner        = "#{lock.user.display_name}"
      # We might not want to reveal the owner v.s. admin, but it's useful
      # for debugging at least.

      if lock.user.id == key.sharer_user_id
        message = admin ?
          "#{lock_owner} has invited #{target_user_name} to access #{lock_name}" :
          "#{lock_owner} has invited you to access #{lock_name}"
      else
        sharer            = User.find_by_id(key.sharer_user_id)
        # Should never be missing
        if sharer != nil
          message = admin ?
            "#{sharer.display_name} has invited #{target_user_name} to access #{lock_name} owned by #{lock_owner}" :
            "#{sharer.display_name} has invited you to access #{lock_name} owned by #{lock_owner}"
        end
      end
    when EventType::KEY_REVOKED
      message = admin ?
        "#{target_user_name}'s access to #{lock_name} has been cancelled" :
                         "Your access to #{lock_name} has been cancelled"
    when EventType::KEY_EXPIRED
      message = admin ?
        "#{target_user_name}'s access to #{lock_name} has expired" :
                         "Your access to #{lock_name} has expired"
    when EventType::ADMIN_SHARED
      lock_owner        = "#{lock.user.display_name}"
      message =  admin ?
        "#{target_user_name} is now a manager for #{lock_name}" :
                       "You are now a manager for #{lock_name} owned by #{lock_owner}"
    when EventType::ADMIN_REVOKED
      message =  admin ?
        "#{target_user_name} is no longer a manager of #{lock_name}" :
                         "Your are no longer a manager of #{lock_name}"
    when EventType::ACCESS_CHANGED
      message = admin ?
        "#{target_user_name}'s access times for #{lock_name} have been changed" :
                         "Your access times for #{lock_name} have been changed"
    when EventType::LOCK_DECOMMISSIONED
        message = "#{lock_name} was taken out of service at #{event_time_string}"
    when EventType::USER_DEVICE_CONFIRMED
      # This is not a message for anyone but the user to confirm.
      # LP20979209 todo: implement confirmation screen in app and confiamtion endpoint in server.
      message = "A new device has tried to access your Goji account.  Check your email to add this device to your account"
    when EventType::ERROR_NOTIFY_OWNER_ADMIN
      message = event.get_event_error_message(event.int_value)
    end
    self.message = message ? (message + ".") : nil
  end

  #
  # Locked/Unlocked Failure Cases
  #
  def self.access_failure_message(lock_name, target_user_name, event_type, event_result, bolt_state)
     message = "#{target_user_name} tried to "
     action_past_tense = ""
    if event_type == EventType::LOCK
      message += "lock "
      action_past_tense = "locked"
    elsif event_type == EventType::UNLOCK
      message += "unlock "
      action_past_tense = "unlocked"
    end
    message += "#{lock_name} "

    case event_result
      when CommandResult::INVALID_KEY
        message += "without valid access"
      when CommandResult::OUTSIDE_TIME_DAY
        message += "out of the the allowed access time"
      when CommandResult::USE_EXCEEDED
        message += "but is out of access uses"
      when CommandResult::EXPIRED
        message += "but no longer is allowed access"
      when CommandResult::HARDWARE_FAILURE
        # Note that the message completely changes here per UX specifications
        message = "#{lock_name} failed to be #{action_past_tense} by #{target_user_name} and "
        case bolt_state
          when BoltState::LOCKED
            message += "is still locked"
          when BoltState::UNLOCKED
            message += "is still unlocked"
          when BoltState::FAILED
            message += "status is unknown"
          # Should never see this!
          when BoltState::MOVING
            message += "is still moving"
        end
    end
    message
  end

  # push notification to all of user_id's devices where they are
  # confirmed and authenticated.
  def send_push
    # Be sure we save notification record, catch and log all exceptions, always return true.
    destinations = user.active_devices.merge(Device.pushable)
    logger.debug("sending " + destinations.count.to_s + " notifications")
    # Record expected and actual notification counts for test and auditing.
    self.devices_tried = destinations.count
    self.devices_sent = 0
    self.push_result = []
    return true if destinations.empty?

    # http://docs.aws.amazon.com/sns/latest/dg/mobile-push-send-custommessage.html
    custom_data = apn_payload
    apns = custom_data.merge({
      "aps" => {
        "alert" => message,
        "sound" => "default",
      }
    }).to_json
    gcm = {
      "data" => custom_data.merge({
        "message" => message
      })
    }.to_json
    # Put together in Amazon format, such that any platform could receive it
    aws_message = {
      "default" => message,
      "APNS" => apns,
      "APNS_SANDBOX" => apns,
      "GCM" => gcm,
    }.to_json

    client = AWS::SNS.new.client
    #send notification to activated devices only
    destinations.each do |device|
      # Try/catching all non-fatal exceptions since we want to keep
      # processing, even if a single push fails, and be sure to save
      # notification record.
      begin
        if ENV["NO_AWS_SNS"]
          result = {:message_id=>"511ba014-22d3-5430-897c-ed61f6ff021f", :response_metadata=>{:request_id=>"5d2a8593-7312-51cb-b844-c8e6a73ea7e4"}}
        else
          result = client.publish(
            message: aws_message,
            target_arn: device.endpoint_arn,
            message_structure: 'json'
          )
        end
        # Push result used mostly just for automated tests
        self.push_result << {device.endpoint_arn => result}
        self.devices_sent += 1
      rescue AWS::SNS::Errors::EndpointDisabled => ex
        # This endpoint is disabled. Make a note of it in the log.
        # Some pushes (access, soon new device) are important, therefore so is failure
        ErrorRecorder.notice_exception("AWS SNS endpoint disabled", ex, {target_arn: device.endpoint_arn, device_id: device.id})
        device.endpoint_disabled_at = DateTime.now
        device.save # If the save fails here, non-critical
        self.push_result << {device.endpoint_arn => "EndpointDisabled"}
      rescue => ex
        # Log the exception to be addressed, but keepx going since
        # other endpoints/emails need to go out.
        # TODO Someday, we could be clever about this, and if no notification method works, then don't save/put it back in the queue for retry
        self.push_result << { device.endpoint_arn => ex }
        ErrorRecorder.notice_exception((ex.class == AWS::Errors::Base) ? "AWS SNS Failure" : "unusual exception sending device notice",
                                       ex,
                                       {target_arn: device.endpoint_arn, device_id: device.id})
      end
    end
    return true
  end

  def send_email
    # Depending on email log lines to tell if email actually got sent.
    # Be sure we save notification record, catch and log all exceptions, always return true.
    # We never send email on owner/admin notifications, only to key
    # owners.  Except decommissioning.
    type = event.event_type
    return true if admin && (type != EventType::LOCK_DECOMMISSIONED)
    begin

      if (type == EventType::KEY_SHARED ||
          type == EventType::KEY_REVOKED ||
          type == EventType::ADMIN_SHARED ||
          type == EventType::ADMIN_REVOKED ||
          type == EventType::ACCESS_CHANGED ||
          type == EventType::LOCK_DECOMMISSIONED ||
          (extra && extra[:original] == EventType::LOCK_DECOMMISSIONED))  # special KEY_REVOKED
        #result =
        Mailer.send_email(type, lock, key,
                          event.user || (key && key.sharer), # from
                          user,                              # to
                          extra, extra && extra[:fresh_password]).deliver!
        #result
      elsif (type == EventType::USER_DEVICE_CONFIRMED)
        Mailer.send_email(type, nil, nil,
                          nil,                               # from Goji server
                          user,                              # to
                          extra, nil).deliver!
      end
    rescue => ex
      # Log the exception but keep going
      ErrorRecorder.notice_exception("unusual exception sending notification email",
                                     ex,
                                     { user_id: user.id })
    end
    return true
  end

  #****
  # Class attributes and methods
  #****

  # format datetime for notification strings
  def self.fdt(datetime)
    # TODO using PST for alpha1
    # %P case is backward - %P to get lower case!
    !datetime.blank? ? datetime.in_time_zone("Pacific Time (US & Canada)").strftime("%I:%M%P") : '-'
  end

  #****
  # Instance attributes and methods
  #****

  # For Rails Admin, see user.rb:
  def name
    return "New Notification"  if !id
    from = (event.user || (key && key.sharer))
    # Need id to be distinguishable in event lists.
    event.event_type + (from.try(:name) ? " from " + from.name : "") +
      (user.try(:name) ? (" to " + user.name) : "") +
      " (#" + id.to_s + ")"
  end

  if defined? rails_admin
    rails_admin do
      parent Event
      list do
        field :id
        field :lock do
          sortable :name
          searchable "locks.name"
        end
        field :type do
          searchable [{:events => :event_type}]
          # Wiki lies, this is a syntax error:
          # sortable {:events => :event_type}
          sortable "events.event_type"
        end
        field :key
        field :user do
          label "Recipient"
          sortable false
          searchable false
        end
        # See lock.rb
        field :user_account do
          visible false
          label "Recipient user name/email"
          searchable ["user_accounts.email", "user_accounts.full_name"]
        end
        field :event do
          sortable :event_type
      end
      end
      show do # basic info screen
        field :lock
        field :type
        field :key
        field :user
        field :message
        field :admin
        # event fields
        field :time
        field :string_value
        field :int_value

        field :event
        field :devices_tried
        field :devices_sent
        # field :read_date # obsolete?
        field :id
        field :created_at
        field :updated_at
      end
      edit do
        field :lock
        field :key
        field :user
        field :message
        field :admin
        field :event
        field :devices_tried
        field :devices_sent
        # field :read_date
      end
    end
  end

  def type
    event.event_type
  end

  def time
    event.event_time
  end

  def int_value
    event.int_value
  end

  def string_value
    event.string_value
  end

  def apn_payload
    # Per Daniel's request, we're making this look very similar to
    # GET /events, but just with less information
    # Android doesn't like multi-level or null values. Trying a ""
    # empty string
    payload = {
                id:           event.id,
                event_type:   event.event_type,
                string_value: (event.string_value || ""),
                int_value:    (event.int_value || ""),
                lock_id:      (event.lock_id || ""),
                key_id:       (event.key_id || ""),
                user_id:      (event.user_id || ""),
                user_display_name: (event.user.try(:display_name) || ""),
              }
    if (event.event_type == EventType::USER_DEVICE_CONFIRMED)
      payload[:device_confirmation_token] = extra ? extra[:confirmation_token] : ""
      payload[:user_device_id] = extra ? extra[:id] : ""
    end

    return payload
  end

    # nice boolean - human readable true/false
  def nb(bool)
    bool ? 'Yes' : 'No'
  end

  attr_accessible :user_id, :lock_id, :key_id, :event_id,
                  :read_date, :message, :admin, :extra, :user, :lock,
                  :devices_tried, :devices_sent, :recipient,
                  :key, :event, :uuid

end
