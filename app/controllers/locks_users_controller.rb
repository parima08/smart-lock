class LocksUsersController < ApplicationController

  before_filter :json_authenticate

  respond_to :json


  # This controller isn't used in the app, instead admin is CRUD 
  # through /keys.
  #
  # Add/update a lock_id->user_id join table entry.
  # Path /locks_users/<lock_id>
  # Used for both make and remove admin access, the record is never
  # deleted until the lock or user record is deleted.
  def update #PUT
    return if params_missing([ :lock_id, :user_id ], params)

    lock_id = params[:lock_id]
    user_id = params[:user_id]
    admin = params[:admin]
    # validate: @current_user is owner/admin for (lock_)id
    # Why can't they document the basics: find*() return one/array
    # of ActiveRecord::Base objects, where() returns a relation, e.g.
    # ActiveRecord:Relation:ActiveRecord_Relation_Lock
    # find is annoying because it exceptions when not found!
    # lock = Lock.includes(:users).find(lock_id)
    lock = Lock.includes(:users).find_by_id(lock_id)
    return render_error_modelname(404, :MISSING_RECORD, Lock) if lock == nil

    if ! lock.account_is_admin?(@current_account)
      return render_error(403, :ADMIN_ACCESS)
    end
    # XXX validate: user_id is not owner of lock if admin == true
    # XXX use scopes, to stop deprecated message
    # XXX validate: valid admin boolean true/false (1 silently fails)
    user = User.find_by_id(user_id)
    return render_error_modelname(404, :MISSING_RECORD, User) if user == nil
    lu = LocksUser.where(:lock_id => lock_id,
                         :user_id => user_id).first
    if lu
      lu.admin = admin
      lu.sharer_user_id = @current_account.user.id
    else
      lu = LocksUser.new(:lock_id => lock_id,
                         :sharer_user_id => @current_account.user.id,
                         :user_id => user_id,
                         :admin   => admin)
    end
    lu.save!

    # Create/delete the key that gives this administrator 24/7 access.
    # If the user already had a 24x7 key, this assumes that it
    # should be kept when admin is enabled then disabled.
    # Not how things are done now - so this is buggy, and only use
    # of obsolete key.auto_generated.
    if admin != nil
      if admin
        if ! Key.has_24_7(lock_id, user_id)
          # Validation errors possible here if user already has a
          # time-limited key.  Need to delete non-24x7 key first.
          key = create_user_key(lock.id, user, @current_account.user)
          # This hack goes away (actually this whole endpoint!)
          key.auto_generated = true
          key.save!
        end
      else
        # For now, all auto_generated keys are 24/7, revoke the one created above.
        # Really should be revoked to preserve history.
        Key.auto_generated(lock_id, user_id).try(:delete)
      end
    end

    render_success
  end

end
