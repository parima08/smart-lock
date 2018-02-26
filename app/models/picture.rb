# == Schema Information
#
# Table name: pictures
#
#  id                :integer          not null, primary key
#  data_file_name    :string(255)
#  data_content_type :string(255)
#  data_file_size    :integer
#  data_updated_at   :datetime
#  taken_at          :datetime
#  lock_id           :integer
#  created_at        :datetime
#  updated_at        :datetime
#

class Picture < ActiveRecord::Base

  #****
  # Extensions - acts_as, extends, etc
  #****

  # This method associates the attribute ":data" with a file attachment
  # XXX move permissions to defaults once firmware security is worked out?
  has_attached_file :data

  #****
  # Associations
  #****

  belongs_to :lock
  # There is some infinite loop in the ActiveRecord delete/destroy machinery if you use destroy here.
  # Events now can not have a picture, so this is OK, and anyway isn't
  # normally done without deleting lock/user and therefore the event.
  has_many   :events, :dependent => :nullify

  #****
  # Validations
  #****
  validates_with StringLengthValidator
  validates_presence_of :lock
  validates_presence_of :taken_at
  validates_uniqueness_of :taken_at, scope: :lock_id, message: "duplicate picture: same time and lock"

  #****
  # Scopes
  #****

  #****
  # Callbacks and associated methods
  #****

  #****
  # Class attributes and methods
  #****

  #****
  # Instance attributes and methods
  #****

  # By default, rails_admin gets an unsigned image url that doesn't work because of S3 security.
  # Activeadmin would need an equivalent, and more - it doesn't display images at all.

  if defined? rails_admin
    rails_admin do
      list do
        field :id
        field :lock do
          sortable :name
          searchable "locks.name"
        end
        field :taken_at do
          column_width 200
        end
        field :events do
          # Can't search/sort has_many references like this without a mod (with performance implications) to RailsAdmin:
          # http://blog.endpoint.com/2013/07/hasmany-filter-in-railsadmin.html
          # searchable ["events.event_type"]
      end
        field :data do
          sortable false
          label "Image"
          pretty_value do
            bindings[:view].tag(:img, {
                                  :src =>bindings[:object].data.try(:expiring_url, GojiServer.config.s3_url_expire)
                                })
          end

          export_value do
            # Just export the url, with a very long expiration?
            # Works for json/csv but not xml, odd.
            bindings[:object].data.try(:expiring_url, 30000)
          end
        end
      end

      show do # basic info screen
        # Info:
        field :id
        field :lock
        field :taken_at
        field :events
        field :data do
          label "Image"
          pretty_value do
            bindings[:view].tag(:img, {
                                  :src =>bindings[:object].data.try(:expiring_url, GojiServer.config.s3_url_expire)
                                })
          end
        end
        field :created_at
        field :updated_at
      end

      edit do
        field :lock
        field :taken_at
        field :events
        field :data do
          label "Image"
        end
      end
    end
  end


  attr_accessible :data, :data_file_name, :data_content_type, :data_file_size, :data_updated_at, :taken_at, :lock, :lock_id, :uuid

end
