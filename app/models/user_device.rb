# == Schema Information
#   Table name: user_devices
#
#    t.integer  "user_id"
#    t.integer  "user_account_id"
#    t.integer  "device_id"
#    t.string   "name"
#    t.string   "confirmation_token"
#    t.datetime "confirmed_at"
#    t.string   "authentication_token"
#    t.boolean  "authenticated"
#    t.datetime "decommissioned_at"
#    t.binary   "private_key"
#    t.datetime "keys_sent_at"

class UserDevice < ActiveRecord::Base
  #****
  # Extensions - acts_as, extends, etc
  #****
  include DataNormalizer

  #****
  # Associations
  #****
  belongs_to :device
  belongs_to :user
  belongs_to :user_account, :primary_key => :user_id

  #****
  # Validations
  #****
  validates :user_id,           :presence => true
  validates :device_id,         :presence => true

  #****
  # Scopes
  #****
  scope :confirmed, -> {
    where.not(:confirmed_at => nil)
  }

  scope :active, -> {
    confirmed.where(decommissioned_at: nil).where.not(authenticated_at: nil)
  }

  scope :decommissioned, -> {
    confirmed.where.not(decommissioned_at: nil)
  }


  scope :not_in_use, -> {
    where('confirmed_at IS NULL OR keys_sent_at IS NULL')
  }

  #****
  # Callbacks and associated methods
  #****
  # ensures devise will save an auth_token if unspecified
  before_save :ensure_confirmation_token, unless: :confirmed_at

  # We don't support updating the private_key.
  after_create  :update_credentials
  # decommissioning TBD
  after_destroy :update_credentials

  # See lock.rb
  after_validation :clone_user_id

  def create_confirmation_event
    Event.create!(user_id: self.user_id,
                  key: nil,
                  lock: nil,
                  event_type: EventType::USER_DEVICE_CONFIRMED,
                  event_time: Time.now,
                  uuid: uuid,
                  extra: {
                    id: "#{self.id}",
                    confirmation_token: "#{self.confirmation_token}"
                  })
  end

  # See: https://gist.github.com/josevalim/fb706b1e933ef01e4fb6
  # We always create a new token at login.
  def login
    self.authentication_token = generate_authentication_token
    self.authenticated_at = DateTime.now
    return save
  end

  def logout
    self.authenticated_at = nil
    self.authentication_token = nil
    return save
  end

  private def generate_authentication_token
    loop do
      token = Devise.friendly_token
      break token unless UserDevice.where(authentication_token: token).first
    end
  end

  private def ensure_confirmation_token
    if confirmation_token.blank?
      self.confirmation_token = generate_confirmation_token
    end
  end

  private def generate_confirmation_token
    token = Digest::SHA256.hexdigest([Time.now, rand].join)[0..20]
    #confirmation_token = Devise.token_generator.digest(self, :confirmation_token, confirmation_token)
  end

  def update_credentials
    # All locks for all of user's keys must have credential package resent.
    user.keys.each do |key|
      key.lock.credentials_changed
    end
  end

  #****
  # Instance attributes and methods
  # sharer_user_id required here for .new() parameter to work.
  #****

  def mark_as_confirmed
    # TODO prepend "device_" to confirmation_token after column rename
    self.confirmation_token = nil
    self.confirmed_at = DateTime.now
  end

  # For Rails Admin, see user.rb:
  def display_name
    # Somehow RailsAdmin add record starts with an empty record.
    return "New User_Device" if !id
    uname = user_account.try(:full_name)
    dname = device.try(:id)
    return uname + "'s device #" + dname.to_s if dname && uname
    return "#" + id.to_s
  end

  if defined? rails_admin
    rails_admin do
      weight -3
      list do
        field :user_account do
          visible false
          label "user name/email"
          searchable ["user_accounts.email", "user_accounts.full_name"]
        end
        field :ua_token do
          label "Notify-user id"
          visible false
          searchable ["devices.ua_token"]
        end
        field :endpoint_arn do
          label "Amazon SNS id"
          visible false
          searchable ["devices.endpoint_arn"]
        end

        field :id do
          column_width 40
        end
        # See lock.rb
        field :user do
          column_width 140
          label "Registered user"
          sortable false
          searchable false
        end
        field :device do
          column_width 80
        end
        field :device_type do
          label "Device type"
          column_width 55
          pretty_value do
            bindings[:object].device.device_type
          end
          searchable ["devices.device_type"]
        end
        field :confirmed_at do
          column_width 150
        end
        field :authenticated_at do
          # XXX Set date width in shared global?
          column_width 150
        end
        field :keys_sent_at do
          column_width 150
        end
        # If we need to ignore decommmissioned devices, use a default search.
        #field :decommissioned_at
      end
      show do # basic info screen
        field :user do
          label "Registered user"
        end
        field :device do
          pretty_value do
            ud = bindings[:object]
            arn = ud.device.endpoint_arn
            "#" + ud.device_id.to_s +
              " (" + ud.device.device_type + "), Notify-user id=" +
              ud.device.ua_token + ", AWS-SNS ID=" +
              (arn ? arn : "")
          end
        end
=begin
        # This field name must match belongs_to foreign key
        # for RailsAdmin to connect it up.
        # But only last occurance of a field name is used.
        # Hence ugly combo field above for now...
        field :device_type do
          label "Device type"
          pretty_value do
            bindings[:object].device.device_type
          end
        end
        field :ua_token do
          label "Notify-user id"
          pretty_value do
            bindings[:object].device.ua_token
          end
        end
        field :endpoint_arn do
          label "Amazon SNS id"
          pretty_value do
            bindings[:object].device.endpoint_arn
          end
        end
=end
        field :private_key
        field :confirmed_at
        field :confirmation_token
        field :authenticated_at
        field :authentication_token
        field :keys_sent_at
        field :decommissioned_at
        # Info:
        field :uuid
        field :id
        field :created_at
        field :updated_at
      end
      edit do
        field :user do
          label "Registered user"
        end
        field :device
        field :private_key
        field :confirmed_at
        field :confirmation_token
        field :authenticated_at
        field :authentication_token
        field :keys_sent_at
        field :decommissioned_at
      end
    end

    attr_accessible :user, :device, :user_id, :device_id, :confirmed_at, :confirmation_token, :authenticated_at, :authentication_token,
          :decommissioned_at, :keys_sent_at, :name, :private_key,
          :uuid
  end
end
