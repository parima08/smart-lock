# == Schema Information
#
# Table name: firmwares
#
#  id                :integer          not null, primary key
#  version           :string(255)
#  description       :string(255)
#  for_external      :boolean
#  download_url      :string(255)
#  data_file_name    :string(255)
#  data_content_type :string(255)
#  data_file_size    :integer
#  data_updated_at   :datetime
#  created_at        :datetime
#  updated_at        :datetime
#

class Firmware < ActiveRecord::Base

  HTTP_HOST = 's3.amazonaws.com'
  HTTP_BUCKET = '/goji-firmware/'
  HTTP_ROOT = 'http://' + HTTP_HOST + HTTP_BUCKET
  # Before we care about security, we should be able to get rid of ftp.
  FTP_USER = 'gate-kpepzd'
  FTP_PASS = 'sa4YjpxjxWIi'
  FTP_HOST = 'ftp.cloudgates.net'
  FTP_ROOT = 'ftp://' + FTP_USER + ':' + FTP_PASS + '@' + FTP_HOST + '/'
  # Will eventually replace v2 with %h, expand when saving firmware record.
  RELATIVE_PATH = ":for_external/v2/:version"

  #****
  # Extensions - acts_as, extends, etc
  #****
  nilify_blanks :before => :validation

  # This method associates the attribute ":data" with a file attachment
  # Path is hardware version-dependent, only v2 for alpha, later based on
  # hardware_version.major version string supplied in upload POST.
  # http://s3.amazonaws.com/goji-firmware/external/v2/vers_str/?AWSID...
  has_attached_file :data, 
    # Remove public_read once we decide to secure firmware images,
    # determine the max lock download start delay, and figure out how
    # to add (:expiring_url, GojiServer.config.s3_url_expire).  Then
    # we believe the url will be secure (LP17463971).  Basically,
    # download_url needs to be generated on the fly from paperclip
    # data object instead of stored in database.  Should work through
    # FTP as well as long as the lock downloads the requested firmware
    # update immediately after sync.
    :s3_permissions => :public_read,
    path: RELATIVE_PATH,
    :s3_credentials => {
      # Same bucket for all deployments, including dev.
      :bucket => 'goji-firmware',
      :access_key_id => ENV['AWS_ACCESS_KEY_ID_FIRMWARE_UPLOAD'],
      :secret_access_key => ENV['AWS_SECRET_ACCESS_KEY_FIRMWARE_UPLOAD'],
      # XXX how can we get Paperclip to use general write access key for upload, but special
      # firmware read-only key for generating the download URL?
    }

  #****
  # Associations
  #****

  #****
  # Validations
  #****

  validates :version,         :presence => true, :uniqueness => { scope: :for_external }
  validates :download_url,    :presence => true 
 validates :for_external,    :inclusion => { in: [true, false] }
  validates :data_file_name,  :presence => true
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

  def self.external_string(for_external) # boolean
    for_external ? "external" : "internal"
  end

  #****
  # Instance attributes and methods
  #****

  # For Rails Admin, see user.rb:
  def name
    return "New Firmware" if !id
    version + " (" + description.to_s + ") " +
      " (" + (for_external ? "internal" : "external") + ")"
  end

  if defined? rails_admin
    rails_admin do
      parent Lock
      list do
        field :id
        field :version
        field :description
        field :for_external
        field :download_url
      end
      show do # basic info screen
        field :version
        field :description
        field :for_external
        field :download_url
        field :data
        field :id
        field :created_at
        field :updated_at 
      end
    end
  end

  attr_accessible :data, :data_file_name, :data_content_type, :data_file_size, :data_updated_at, :version, :description, :for_external, :download_url, :uuid

  Paperclip.interpolates :for_external do |attachment, style|
    Firmware.external_string(attachment.instance.for_external)
  end
  Paperclip.interpolates :version do |attachment, style|
    attachment.instance.version
  end

end
