# == Schema Information
#
# Table name: devices
#
#  id          :integer          not null, primary key
#  user_id     :integer
#  user_account_id    :integer          RA clone of user_id
#  name        :string(255)
#  ua_token    :string(255)
#  created_at  :datetime
#  updated_at  :datetime
#  device_type :string(255)      default("iOS")
#  endpoint_arn:string(255)      AWS Endpoint ARN
#

class Device < ActiveRecord::Base
  #****
  # Extensions - acts_as, extends, etc
  #****
  include DataNormalizer

  #****
  # Constants
  #****

  # iosdevelopment is used for iOS APNS Sandbox (xcode local developer builds)
  DEVICE_TYPES = ["iOS", "iosdevelopment", "android"]

  #****
  # Associations
  #****
  has_many   :user_devices,    :dependent => :delete_all
  has_many   :user, through: :user_devices

  #****
  # Validations
  #****
  # This may not be sent by the app if notifications are disabled.
  #validates_presence_of :ua_token
  validates_uniqueness_of :ua_token, scope: [:device_type], message: "device record already exists for this ua_token and device_type"
  validates               :device_type, presence: true, inclusion: {in: DEVICE_TYPES, message: "Can not be: %{value}"}
  validates_with StringLengthValidator

  #****
  # Scopes
  #****

  # Does the device appear valid to send pushes?
  scope :pushable, -> {
    where(endpoint_disabled_at: nil).where.not(endpoint_arn: nil)
  }


  #****
  # Callbacks and associated methods
  #****
  nilify_blanks :before => :validation

  before_create :update_push_endpoint

  #
  # Registers the device with AWS and stores returned ARN endpoint
  #
  def new_push_endpoint
    # no ua_token, not notification.
    return if ApplicationController.is_empty(ua_token)
    begin
        if ENV["NO_AWS_SNS"]
          result = {endpoint_arn: "arn:aws:sns:stub-test-only/" + rand(100000).to_s}
        else
          client = AWS::SNS.new.client

          result = client.create_platform_endpoint(
                      platform_application_arn: GojiServer.config.aws_push_arn[device_type.downcase.to_sym],
                      token: ua_token,
                   )
        end
        self.endpoint_arn = result[:endpoint_arn]
    rescue AWS::Errors::Base => e
      ErrorRecorder.notice_exception("AWS SNS Failure : Create Platform Endpoint failed for #{ua_token}, #{id}", e, {ua_token: ua_token, device_id: id})
      # Do we raise here? No, we could run through and fix later if AWS is down or something. We still want device record created, and we're only catching specific error
    end
    return true
  end

  # Updates the push token status with AWS
  # Can be called through a callback, or also on it's own
  def update_push_endpoint
    return if ApplicationController.is_empty(ua_token)

    if !endpoint_arn.present?
      new_push_endpoint
    end
    # Exception above? abort.
    return if !endpoint_arn.present?

    client = AWS::SNS.new.client
    begin
      # Try and mark as enabled (since this should only be called when we know we have the latest from the app)
      begin
        if ENV["NO_AWS_SNS"]
          result = {} # Presently we don't need a result, but placeholder
        else
          result = client.set_endpoint_attributes(endpoint_arn: endpoint_arn, attributes: {"Enabled" => "true", "Token" => ua_token})
        end
      rescue AWS::SNS::Errors::NotFoundException
        new_push_endpoint
      end

    self.endpoint_disabled_at = nil

    rescue AWS::Errors::Base => e
      ErrorRecorder.notice_exception("AWS SNS Failure : Set Endpoint Attributes failed for #{endpoint_arn}", e, {ua_token: ua_token, device_id: id, endpoint_arn: endpoint_arn})
    end

    return true # Don't block before_create if this fails
  end


  #****
  # Class attributes and methods
  #****
=begin
  # This is currently not implemented, as we don't presently have a reliable way to track notification read/unread counts
  def reset_apn_badge!
    push_notification  = {
      audience: {
        device_token: [self.ua_token]
      },
      notification: {
        # Platform specific overrides
        ios: {
          badge: 0,
        }
      },
      device_types: ["ios"]
    }

    logger.info "======="
    logger.info push_notification

    result = Urbanairship.push(push_notification.merge(version: 3))

    logger.info result
    logger.info "======="

    return result # Used by unit tests to check for success
  end
=end

  # Find device record for a ua_token.
  # Note that we handle the case where the device isn't reporting
  # ua_token (doesn't include parameter), with a shared device record.
  def self.get_from_token(params)
    Device.where(:ua_token => params[:ua_token],
                 :device_type => params[:device_type]).first

  end

  # Find device record from request payload, by id or ua_token.
  def self.get_from_request(params)
    # Lookup by ua_token first, so if device is switched between test
    # servers with different device id's it's self-healing.
    # This assumes its a truly global uuid.
    device = get_from_token(params)
    return device if device
    # XXX LP19010907: An error fetching by device_id likely indicates
    # a brute-force attack and should be reported to sysadmin.
    # Could shift later to a uuid for the device_id with no app change.
    find_by_id(params[:device_id])
  end


  #****
  # Instance attributes and methods
  #****

  def display_name
    return "New Device" if !id
    return "Device #" + id.to_s
  end

   def format_user_devices(view = "list")
    ud = user_devices
    active = ud.active
    decommissioned = ud.decommissioned
    not_in_use = ud.not_in_use
    #if confirmed/keys_sent at, but hasn't ever been authenticated/decommissioned
    other = ud - active - not_in_use - decommissioned
    if view == "list"
      html_string = %{<div class="dm_user_devices">}
      html_string += construct_user_device_link(active, "green") if active
      html_string += construct_user_device_link(not_in_use, "red") if not_in_use
      html_string += construct_user_device_link(decommissioned, "orange") if decommissioned
      html_string += construct_user_device_link(other) if other
      html_string += %{</div>}
      return html_string.html_safe
    elsif view == "show"
      html_string = %{<div class ="dm_show_user_devices"> }
      html_string +=  "<h5>Active: </h5><div class='active'> " +
                      construct_user_device_link(active, "green") +
                      "</div><hr>" if active
      html_string += "<h5>Not in Use: </h5><div class='not_in_use'> " +
                      construct_user_device_link(not_in_use) +
                      "</div><hr>" if not_in_use
      html_string += "<h5>Decommissioned: </h5><div class='decommissioned'> " +
                      construct_user_device_link(decommissioned) +
                      "</div><hr>" if decommissioned
      html_string += "<h5>Not Fully Commissioned Yet: </h5><div class='other'> " +
                      construct_user_device_link(other) +
                      "</div><hr>" if other
      html_string += "</div>"
      return html_string.html_safe
    end
  end

  def construct_user_device_link(elements, color = "black")
    html_string = ""
    elements.each do |e|
      link = RailsAdmin::Engine.routes.url_helpers.show_path(model_name: 'user_device', id: e.id)
      html_string += %{<a href="#{link}" class="#{color}">#{e.display_name}</a> }
    end
    return html_string
  end

  def last_server_access
    #the last server access from the device is when the
    #active user last accessed the server (presumably using that)
    #device.
    active = Device.user_devices.active.updated_at
  end

  if defined? rails_admin
    rails_admin do
      parent UserDevice
      weight -1
      list do
        field :id do
          column_width 40
        end
        field :device_type
        field :ua_token do
          label "Push Token"
        end
        field :endpoint_arn do
          label "Amazon SNS id"
        end
        field :endpoint_disabled_at do
          label "Endpoint Disabled"
        end
        field :user_devices do
          label "User-device"
          searchable [:user_id]
          sortable :user_id
        end
      end
      show do # basic info screen
        field :device_type
        field :ua_token do
          label "Push Token"
        end
        field :endpoint_arn do
          label "Amazon SNS id"
        end
        field :endpoint_disabled_at do
          label "Endpoint Disabled"
        end
        field :user_devices do
          label "User-device"
          searchable [:user_id]
          sortable :user_id
        end
        field :os_version
        field :app_version
        field :device_model
        field :uuid
        field :id
        field :created_at
        field :updated_at
      end
      edit do  # and new
        field :device_type
        field :ua_token do
          label "Push Token"
        end
        field :endpoint_arn do
          label "Amazon SNS id"
        end
        field :endpoint_disabled_at do
          label "Endpoint Disabled"
        end
        field :os_version
        field :app_version
        field :device_model
      end
    end
  end

  # Full list of mass-updatable fields:
  # Excluded: endpoint_arn, endpoint_disabled_at
  @@all_attributes = [ :ua_token, :device_type, :uuid, 
                       :os_version, :app_version, :device_model ]
  # API request payloads:
  @@settable = @@all_attributes - [:uuid]
  def self.settable
    @@settable
  end

  # For overloaded API device creation/update.  ua_token should be
  # there but sometimes isn't.
  @@required = @@settable - [:ua_token]
  def self.required
    @@required
  end

  # new()/update(), including sysadmin (sysadmin edit/new silently
  # ignores if not listed here), 
  # default model-specific API response payload:
  attr_accessible *@@all_attributes

  # Extra excludes from response payloads (get_payload_hash()).
  # There are no Device response payloads any more.
=begin
  @@response_exclude = [:uuid]
  def self.response_exclude
    @@response_exclude
  end
=end

end
