# == Schema Information
#
# DB View: full join on users+acccounts.
#  If fields are added to users, can add to view definition, or
#  access through association.
#

class UserAccount < ActiveRecord::Base

  #****
  # Extensions - acts_as, extends, etc
  #****

  #****
  # Non-persistent variables
  #****

  #****
  # Associations
  #****
  belongs_to :account

  #****
  # Validations
  #****

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

  def display_name
    name
  end
  def name
    full_name || email
  end

  if defined? rails_admin
    rails_admin do
      # Views are not writable, so don't belong in table navigation.
      visible false
    end
  end

end
