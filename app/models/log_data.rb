require 'hex_string'

class LogData < ActiveRecord::Base

  #****
  # Extensions - acts_as, extends, etc
  #****

  #****
  # Associations
  #****
  has_one    :log, :dependent => :delete

  #****
  # Validations
  #****
  # blank defaults to binary
  validates :data_type,      :inclusion => { :in => ["text", "binary" ] }, allow_blank: true  # default "binary"
  validates :data,      :presence => true

  #****
  # Callbacks and associated methods
  #****

  #****
  # Class attributes and methods
  #****
  def self.format_data(object, onlylink = false)
    #creates a link to be able to download the log as a file
    link = ActionController::Base.helpers.link_to("Download" , 
        Rails.application.routes.url_helpers.utility_download_log_file_path( :log_data_id => object.id ),
         :method => :post,
         :class => "btn" )
    if object.data_type == "text" && !onlylink
      reformat = ActionController::Base.helpers.simple_format(object.data)
      log_html = %{<div class= 'log_info' style="overflow-y: scroll; height: 400px">
          #{reformat}
        </div>}.html_safe
      return link + log_html 
    else
      return link
    end
  end
  #****
  # Instance attributes and methods
  #****

  def name
    return "New LogData"  if !id
    return log.name if log
    "detached " + data_type.capitalize + " log"
  end

  if defined? rails_admin
    rails_admin do
      parent Log
      list do
        field :id
        field :data_type
        field :info do 
          pretty_value do
            LogData.format_data(bindings[:object], true)
          end
        end
        field :log
      end
      show do # basic info screen
        field :data_type
        field :info do
          #TBD: In post-alpha, according to the API spec, it will eventually be
          # application/x-www-form-urlencoded from the apps and
          # multipart/form-data from the firmware
          pretty_value do
            LogData.format_data(bindings[:object])
          end
        end
        field :log
        field :id
        field :created_at
        field :updated_at
      end
      edit do
        field :data_type
        field :data, :text do
          html_attributes rows: 20, cols: 52
        end
        field :log
      end
    end
  end



  def info
    return data if data_type == "text"
    # TBD: for binary data run the converter to text info utility
    return data.to_hex_string
  end

  attr_accessible :data_type, :data, :uuid
  @@settable = accessible_attributes.to_a
  def self.settable
    @@settable
  end
end
