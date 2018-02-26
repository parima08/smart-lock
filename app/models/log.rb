class Log < ActiveRecord::Base

  #****
  # Extensions - acts_as, extends, etc
  #****

  #****
  # Associations
  #****
  belongs_to :lock
  belongs_to :device
  belongs_to :log_data

  #****
  # Validations
  #****
  # lock/device id may be omitted, but if present, must be valid
  validates :lock,         :presence => true, :if => :lock_id
  validates :device,       :presence => true, :if => :device_id
  # blank defaults to lock
  validates :source,       inclusion: { in: Device::DEVICE_TYPES.concat(["lock"]) }, allow_blank: true  # default "lock"
  validates :fault_time,   :presence => true
  # XXX really should validate that if source is "lock", lock_id is
  # present, or "device", device_id is present.
  validates_with StringLengthValidator
  #****
  # Scopes
  #****

  # Could use this instead of get_lock_id?
  scope :by_id_or_serial, -> (lock_id, lock_serial) {
    # No nice "OR" query in Rails that I know of, dropping to SQL...
    where('"lock_id" = ? OR "lock_serial" = ?',
          lock_id.blank? ? nil : lock_id,
          lock_serial.blank? ? nil : lock_serial)
  }

  #****
  # Callbacks and associated methods
  #****

  #****
  # Class attributes and methods
  #****

  #****
  # Instance attributes and methods
  #****

  # For Rails Admin, see user.rb:
  def name
    return "New Log"  if !id
    source.capitalize + " log at " + fault_time.strftime("%FT%T")
  end

  if defined? rails_admin
    rails_admin do
      list do
        field :id
        field :source
        field :lock do
          sortable :name
          searchable "locks.name"
        end
        field :device
        field :fault_type
        field :fault_time
        field :log_data
      end
      show do # basic info screen
        field :source
        field :lock
        field :device
        field :fault_type
        field :fault_time
        field :log_data
        field :log_info do
          pretty_value do
            LogData.format_data(bindings[:object].log_data)
          end
        end
        field :id
        field :created_at
        field :updated_at
      end
      edit do
        field :source
        field :lock
        field :device
        field :fault_type
        field :fault_time
        field :log_data
      end
    end
  end

  def log_info
    return nil if !log_data_id
    return log_data.info
  end

  attr_accessible :lock_id, :device_id, :source, :fault_time, :fault_type, :log_data_id, :uuid
  @@settable = accessible_attributes.to_a
  def self.settable
    @@settable
  end
end
