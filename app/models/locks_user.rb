# == Schema Information
#
# Table name: locks_users
#
#  id                 :integer          not null, primary key
#  user_id            :integer
#  user_account_id    :integer          RA clone of user_id
#  lock_id            :integer
#  admin              :boolean          default(FALSE)
#

class LocksUser < ActiveRecord::Base

  #****
  # Extensions - acts_as, extends, etc
  #****
  include DataNormalizer
  @sharer_user_id
  attr_accessor :sharer_user_id
  attr_accessor :skip_admin_event

  #****
  # Associations
  #****
  belongs_to :lock
  belongs_to :user
  belongs_to :user_account, :primary_key => :user_id

  #****
  # Validations
  #****
  validates :user_id,         :presence => true
  validates :lock_id,         :presence => true
  # XXX force lock+user uniqueness: joint primary key??

  #****
  # Scopes
  #****

  #****
  # Callbacks and associated methods
  #****
  # around_save fired on both new and update events
  # New key creation will skip_admin_event
  around_save    :admin_notification
  # See lock.rb
  after_validation :clone_user_id

  def admin_notification
    # Check if the admin flag changed, but we don't have it normally in an after_save, so we use the
    # around_save type callback to store it before, and look afterwords
    did_change = self.admin_changed?

    # Run the rest of the creation code
    yield

    if !self.skip_admin_event && did_change
      # Technically, the key and the admin status are separate, but only the server can
      # really tell this is the case, everyone else sees them together. So we're going to
      # add the key to the event.
      # However, since there's only one key per user-lock, this won't be invalid
      # Adding here, since it's needed by both the push notification and in the admin emails
      the_key = lock.active_keys.where(user_id: user_id).first
      Event.create!(user_id: @sharer_user_id,
                    admin_user_id: user_id,
                    lock: lock,
                    key: the_key,
                    event_type: admin ? EventType::ADMIN_SHARED : EventType::ADMIN_REVOKED,
                    event_time: Time.now)
    end
  end


  #****
  # Class attributes and methods
  #****

  # Set admin status if admin flag is in request, only if
  # requestor is lock owner (enforcing app UI rules).
  # Don't create duplicate LocksUser records.
  # This creates slight behavioral differences between false and nil,
  # which should not have exernal effects.
  def self.set_admin(lock, sharer_user_id,
                     to_user, # changed admin rights
                     admin,   # string
                     skip_admin_event = false)

    if ((lock.user.id != sharer_user_id) || (admin == nil))
      return;
    end

    admin = ApplicationController.string_to_boolean(admin)
    lu = LocksUser.where(:lock_id => lock.id,
                         :user_id => to_user.id)
    if (lu.count > 0)
      lu = lu[0]
      lu.admin = admin
      # sharer_user_id is not persisted, and rightly so, it's the updating user!
      lu.sharer_user_id = sharer_user_id
    else
      lu = LocksUser.new(:lock_id => lock.id,
                         :sharer_user_id => sharer_user_id,
                         :user_id => to_user.id,
                         :admin => admin)
    end
    lu.skip_admin_event = skip_admin_event
    lu.save!
  end

  #****
  # Instance attributes and methods
  # sharer_user_id required here for .new() parameter to work.
  #****

  # For Rails Admin, see user.rb:
  def name
    # Somehow RailsAdmin add record starts with an empty record.
    lname = lock.try(:name)
    uname = user.try(:name)
    return lname + " -> " + uname if lname && uname
    return "New LocksUser"
  end

  if defined? rails_admin
    rails_admin do
      parent Lock
      weight -2
      list do
        field :id
        field :lock do
          sortable :name
          searchable "locks.name"
        end
        field :user do
          label "Managing user"
          sortable false
          searchable false
        end
        # See lock.rb
        field :user_account do
          visible false
          label "Managing user name/email"
          searchable ["user_accounts.email", "user_accounts.full_name"]
        end
        field :admin
      end
      show do # basic info screen
        field :lock
        field :user
        field :admin
        field :id
        field :created_at
        field :updated_at
      end
      edit do
        field :lock
        field :user
        field :admin
      end
    end
  end

  attr_accessible :user_id, :lock_id, :admin, :sharer_user_id, :uuid

end
