class FirmwareVersions < ActiveRecord::Base
  #****
  # Extensions - acts_as, extends, etc
  #****

  #****
  # Associations 
  #****

  #****
  # Validations
  #****

  validates_with FirmwareVersionValidator, :fields => [:default_required_internal_version, :default_required_external_version]

  #****
  # Scopes
  #****

  #****
  # Callbacks and associated methods
  #****

  #****
  # Class attributes and methods
  #****
  def self.firmware_version_dropdown(type)
    Firmware.where(for_external: type).pluck(:version).uniq
  end

  #****
  # Instance attributes and methods
  #****


  if defined? rails_admin
    rails_admin do 
      list do 
        field :id
        field :default_required_external_version
        field :default_required_internal_version
      end
      show do
        field :id
        field :default_required_external_version
        field :default_required_internal_version
      end
      edit do
        field :default_required_external_version, :enum do
          enum do
            FirmwareVersions.firmware_version_dropdown(true)
          end
        end
        field :default_required_internal_version, :enum do 
          enum do
            FirmwareVersions.firmware_version_dropdown(false)
          end
        end
      end
    end
  end

  attr_accessible :id, :default_required_external_version, :default_required_internal_version
end
