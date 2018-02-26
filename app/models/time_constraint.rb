# == Schema Information
#
# Table name: time_constraints
#
#  id         :integer          not null, primary key
#  key_id     :integer
#  monday     :boolean
#  tuesday    :boolean
#  wednesday  :boolean
#  thursday   :boolean
#  friday     :boolean
#  saturday   :boolean
#  sunday     :boolean
#  start_time :time
#  end_time   :time
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class TimeConstraint < ActiveRecord::Base

  #****
  # Extensions - acts_as, extends, etc
  #****

  #****
  # Associations
  #****
  belongs_to :key

  #****
  # Validations
  #****
  validates :key,        presence: true
  validates :start_time, valid_time_or_empty: true # XXX remove, deprecated
  validates :end_time,   valid_time_or_empty: true # XXX remove, deprecated
  validates :start_offset, valid_integer_or_empty: true # Custom validator, see validtors folder
  validates :end_offset, valid_integer_or_empty: true

  validate :start_and_end_time
  validate :start_and_end_offset

  def start_and_end_time
    if end_time && start_time && end_time < start_time
      errors.add(:end_time, Util.VALIDATOR_MSGS[:TIME_ORDER])
    end
  end

  def start_and_end_offset

    # Don't distract from more useful bad-integer error messages.
    if errors.messages[:start_offset] || errors.messages[:end_offset]
      return
    end
    if end_offset && start_offset && end_offset < start_offset
      errors.add(:end_offset, Util.VALIDATOR_MSGS[:OFFSET_ORDER])
    end
  end


  #****
  # Scopes
  #****

  #****
  # Callbacks and associated methods
  #****

=begin
  # No longer needed - was upsetting key's seq_no and the only place
  # TimeConstraint.create/save/update is called is in key.rb
  after_save :save_key

  # save the associated key to update the key's seq_no
  def save_key
    self.key.save!
  end
=end

  #****
  # Class attributes and methods
  #****

  def self.get_days_bitmask(tc)
    bits = 0b0000000
    days_of_week = [:sunday, :monday, :tuesday, :wednesday, :thursday, :friday, :saturday]
    bit_value_table = {}
    # convert ruby boolean to 0,1 hash table
    days_of_week.each do |day|
      bit_value_table[day] = tc.send(day) ? 1 : 0
    end
    bit_value_table.each_with_index do |(k,v), i|
      bits = bits | (v << (6 - i))
    end
    return bits.to_i
  end

  #****
  # Instance attributes and methods
  #****

  # For Rails Admin, see user.rb:
  def name
    return "New Time Constraint"  if !id
    # Not clear when this field is accesed for an invalid, unsaved TC record.
    key ? ("time constraint " + key.name) : "unattached time constraint"
  end

  # Format signed minutes
  def self.offset_to_time(offset)
    return nil if !offset
    dh = offset.abs.divmod(60*24)
    hm = dh[1].divmod(60)
    abs = hm[0].to_s + ":" + hm[1].to_s
    abs = dh[0].to_s + " day " + abs if dh[0] != 0
    offset < 0 ? "-" + abs : abs
  end

  if defined? rails_admin
    rails_admin do
      parent Key
      list do
        field :id
        field :key  # Not sure why this sorts on name when key->lock doesn't.
        field :monday
        field :tuesday
        field :wednesday
        field :thursday
        field :friday
        field :saturday
        field :sunday
      end
      show do # basic info screen
        field :key
        field :start_offset do
          label "Start time (from start of day)"
          formatted_value do
            TimeConstraint.offset_to_time(value)
          end
        end
        field :end_offset do
          label "End time (from start of day)"
          formatted_value do
            TimeConstraint.offset_to_time(value)
          end
        end
        field :monday
        field :tuesday
        field :wednesday
        field :thursday
        field :friday
        field :saturday
        field :sunday
        field :uuid
        field :id
        field :created_at
        field :updated_at
      end
      edit do
        field :key
        field :monday
        field :tuesday
        field :wednesday
        field :thursday
        field :friday
        field :saturday
        field :sunday
        field :start_offset
        field :end_offset
      end
    end
  end

  attr_accessible :key_id, :start_time, :end_time,
                  :monday, :tuesday, :wednesday, :thursday,
                  :friday, :saturday, :sunday,
                  :start_offset, :end_offset, :uuid

end
