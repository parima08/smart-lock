# == Schema Information
#
# Table name: accounts
#
#  id                     :integer          not null, primary key
#  admin                  :boolean          default(FALSE)
#  first_name             :string(255)
#  last_name              :string(255)
#  full_name              :string(255)
#  email                  :string(255)
#  encrypted_password     :string(255)
#  reset_password_token   :string(255)
#  reset_password_sent_at :datetime
#  authentication_token   :string(255)    abandoned, now in user_device
#  remember_created_at    :datetime
#  sign_in_count          :integer          default(0)
#  current_sign_in_at     :datetime
#  last_sign_in_at        :datetime
#  current_sign_in_ip     :string(255)
#  last_sign_in_ip        :string(255)
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  confirmation_token     :string(255)
#  confirmed_at           :datetime
#  confirmation_sent_at   :datetime
#  unconfirmed_email      :string(255)
#  password_entropy_percent :double
#  set_password_from      :boolean   default true

class Account < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :trackable,
         :confirmable,
         :timeoutable

  # Explicity setting which fields to nilify, so we make sure we don't
  # interfere with anything devise is doing (likely not, but better safe)
  nilify_blanks only: [:first_name, :last_name, :full_name]

  #****
  # Extensions - acts_as, extends, etc
  #****

  #****
  # Associations
  #****
  has_one :user, :dependent => :destroy

  #****
  # Validations
  #****

  validates :email,                  :presence => true, :uniqueness => true # , :length => { :maximum => EventType::MAX_STRING_LENGTH }
  validates_format_of :email,        with: Devise.email_regexp, if: :email_changed?
#  validates :encrypted_password,     :presence => true, :if => :confirmed?
  validates :password,               :presence => true, :if => :password_needed
  validates :password_confirmation,  :presence => true, :if => :password_needed
  validate :password_confirmation_matches
  validates :first_name,             :presence => true, :if => :confirmed?
  validates :last_name,              :presence => true, :if => :confirmed?

  validates_with StringLengthValidator

  # Only require a password to be supplied if one doesn't exist
  # already (new confirmed test acct or new unconfirmed admin accounts, not
  # update or new user accounts pending confirmation and password
  # creation).
  def password_needed
  (admin || confirmed?) && has_no_password?
  end

  def password_confirmation_matches
    errors.add(:password_confirmation, "Password and password_confirmation must match") if   password != password_confirmation
  end

  #****
  # Scopes
  #****

  #****
  # Callbacks and associated methods
  #****
  before_save :update_full_name

  # XXX expunge once apps are integrated to user_device
  # Unless sysadmin needs it?
  # ensures devise will save an auth_token if unspecified
  before_save :ensure_authentication_token
  # See: https://gist.github.com/josevalim/fb706b1e933ef01e4fb6
  def ensure_authentication_token
    if authentication_token.blank?
      self.authentication_token = generate_authentication_token
    end
  end

  private def generate_authentication_token
    loop do
      token = Devise.friendly_token
      break token unless Account.where(authentication_token: token).first
    end
  end

  # XXX expunge, replace with a full_name method
  # Will this break lock.rb user_account.full_name search?
  def update_full_name
    self.full_name = self.first_name + ' ' + self.last_name rescue nil
  end


  #****
  # Class attributes and methods
  #****

  def new_temp_password
    pass = self.class.random_password
    self.password = pass
    self.password_confirmation = pass
    self.user.fresh_password = pass
    return pass
  end

  def self.random_password
    return [Forgery::Basic.color, sprintf("%03d",rand(1000))].join.downcase
  end

  # Custom find by email that ignores case
  def self.first_by_email(email_address)
    # TODO consider eager loading the user
    # Devise downcases all the emails when Accounts are created
    where(email: email_address.try(:downcase)).first
  end

  #****
  # Instance attributes and methods
  #****

  # For Rails/Active Admin, see user.rb:
  # Also for a non-nil full_name.
  def display_name
    name
  end
  def name
    return "New Account"  if !id
    full_name || email
  end

  if defined? rails_admin
    rails_admin do
      parent User
      list do
        field :id
        field :full_name
        field :email
        field :admin do
          label "Sysadmin"
        end
        field :current_sign_in_at do
          label "Last Sysadmin Sign in"
        end
        field :user  # sorting on has_one's off by default.
      end
      show do # basic info screen
        field :full_name
        field :email
        field :admin do
          label "Sysadmin"
        end
        field :first_name
        field :last_name
        field :sign_in_count
        field :current_sign_in_at do
          label "Last Sysadmin Sign in"
        end
        field :current_sign_in_ip do
          label "Last Sysadmin Sign in IP Address"
        end
        field :unconfirmed_email
        field :confirmation_token
        field :confirmation_sent_at
        field :confirmed_at
        field :user
        field :password_entropy_percent do
          label "Password Score %"
        end
        field :set_password_from
        field :uuid
        field :id
        field :created_at
        field :updated_at
      end
      edit do
        field :email
        field :admin do
          label "Sysadmin"
        end
        field :first_name
        field :last_name
        field :password do
          help ''
        end
        field :password_confirmation do
          help ''
        end
        field :password_entropy_percent do
          # Can't make this read-only here, or new JS-set value won't be posted.  Set in JS.
          label "Password Score %"
          help ''
        end
        field :set_password_from do
          read_only true
          help ''
        end
        field :sign_in_count
        field :last_sign_in_at
        field :last_sign_in_ip
        field :unconfirmed_email
        field :confirmation_token
        field :confirmation_sent_at
        field :confirmed_at
        field :user
      end
    end
  end

    # following methods are required for 'confirmations with user passwords' override

  # new function to set the password without knowing the current password used in our confirmation controller.
  def attempt_set_password(params)
    p = {}
    p[:password] = params[:password]
    p[:password_confirmation] = params[:password_confirmation]
    update(p)
  end

  # new function to return whether a password has been set
  def has_no_password?
    self.encrypted_password.blank?
  end

  # new function to provide access to protected method unless_confirmed
  def only_if_unconfirmed
    # unless_confirmed doesn't exist in devise 2.x
    pending_any_confirmation {yield}
  end

  # end of methods required for 'confirmation with user passwords' override

  # This is the current logic to figure out if an account
  # has a temporary password assigned to it.
  # Extracting to this method however, as it may change in the future
  def has_temporary_password?
    self.confirmed? == false && self.encrypted_password.present?
  end

  # Confirm, and then run save, all in a transaction so if save fails, we'll rollback
  # confirm! doesn't run validations, hence the need for this
  def confirm_and_save!
    Account.transaction do
      confirm!
      save!
    end
  end

  attr_accessible :admin, :first_name, :last_name, :full_name, :email, :password, :set_password_from,
                  :password_confirmation, :remember_me, :user_id, :user, :confirmed_at,
                  :confirmation_token, :confirmation_sent_at, :uuid, :password_entropy_percent

end
