class KeysController < ApplicationController
  include ActionView::Helpers::TextHelper

  before_filter :json_authenticate

  respond_to :json

  #GET /keys :authtoken
  def index
    # Get keys owned by authenticated user
    # Apparently we are making the apps filter out (for display) keys
    # belonging to the locks the user owns/admins?  Probably should be
    # filtered here?  But then the app would have to search both lock
    # and key lists to send the right key to the lock.
    keys = Key.active_keys.includes(:lock => { :user => :account })
              .where(:user_id => @current_account.user.id).includes(:time_constraints).references(:key)

    json =[]
    keys.each do |key|
      key_data = get_key_data_hash(key)
      key_info = get_key_info_hash(key)
      key_info[:lock_owner_display_name]= key.lock.user.display_name
      key_info[:lock_time_zone] = key.lock.time_zone
      key_info[:sharer_display_name]= key.try(:sharer).try(:display_name)
      if key.user_id == key.lock.user_id
        key_info[:lock_owner_key] = true
        # Obsolete, can be removed now.
        key_info[:auto_generated] = true
      end
      # If it's pending, it's not anymore, update it
      # Small performance hit and slightly fishy that a GET would change
      # values, but much easier than more app work and another endpoint
      if key.pending?
        # Readonly prior to this due to joins
        Key.find(key.id).update(pending: false)
      end
      json << get_key_hash(key_data, key_info, "signed")
    end
    # json={signed=base64(Ge(kdata)), kdata = base64(Lid, Aid, Kid, Kdata)}?
    render :json => json
  end

  def create
    return if params_missing([ :lock_id, :email ], params)
    # Per LP16183403, for alpha 1 we restrict one active key per user
    # Note this includes expired: can't issue new key if there is one that is expired.
    user = Account.first_by_email(params[:email]).try(:user)
    if user && user.keys.active_keys.where(:lock_id => params[:lock_id]).exists?
      return render_error(409, "Active key for this user and lock already exists!")
    end

    # LP17249232: remove key_data after no longer used in apps
    # Note: handles admin flag
    if params[:key_data]
      params << params[:key_data]
    end
    params[:uuid] = request.uuid
    key = create_new_key(params[:lock_id], params[:email],
                         @current_account.user, params)
    # Check our added .error (e.g. taken from validation .errors)
    if key[:error].present?
      #switch statements on the error
      case(key[:error])
      when 403
        render_error(403, :NOT_KEY_ADMIN)
      when 422
        render_error(422, key[:msg])
      # Cannot get other errors here.
      end
    else
      render :json => get_key_unsigned_hash(key)
    end
  end

  #PUT /keys/id
  def update
    key = Key.find_by_id(params[:id])
    return render_error_modelname(404, :MISSING_RECORD, Key) if !key
    return render_error(403, :ADMIN_ACCESS) if !key.lock.owner_and_admins.include?(@current_account.user)

    # Is it a resend request? Then just retrigger the notification.
    if params[:resend] == "true"
      # Note that a resend on the owner's key does nothing and isn't a
      # valid use case.
      # If account email not verified, must present confirmation token.
      # Must generate a new password, old one is hashed.
      user = key.user
      if ! user.account.confirmed_at
        user.fresh_password = user.account.new_temp_password
        user.account.save!
      end
      key.key_shared_notification
      render :json => get_key_unsigned_hash(key)
      return
    end

    current_is_owner = key.lock.user_id == @current_account.user.id
    is_admin = key.is_admin()
    becoming_admin = ApplicationController.string_to_boolean(params["admin"])
    new_has_tcs = # better: get_time_constraints_hash(key) != "[]"  ??
        (params[:start_date].present? ||
         params[:end_date].present? ||
         # XXX minor bug: can have a noop time constraint,
         # e.g. all days allowed, or start_time 00:00/nil/end_time 24:00/nil.
         # Should be avoided in app, we hope.
         # See handling in old get_time_constraints_hash(), which
         # also needs to be restored to normalize tc's before comparison.
         # Including sorting multiple tc's - we should not depend on
         # either app or .each ordering - if we end up supporting
         # multiple tc's at the app ui.
         ((params["time_constraints"] != nil) &&
          (params["time_constraints"].count != 0)))

    # Here, above minor causes error but not a time-restriction difference.
    # Policy:
    if !current_is_owner && (is_admin || becoming_admin)
      return render_error(403, :ADMIN_NOT_OWNER)
    end

    # Policy: invalid to end up admin true with time-restrictions!
    # App should be enforcing this (A.3, S.3), so should we.
    # XXX apply rule to create too.
    if ApplicationController.string_to_boolean(params["admin"]) && new_has_tcs
      return render_error(422, Util.VALIDATOR_MSGS[:ADMIN_KEY_UNLIMITED])
    end

    # Grab existing time constraints to check for any change, to
    # send access_changed event.
    old_tc = get_time_constraints_hash_for_comparison(key)

    # Assign attributes to params, based on list allowed in API spec
    key.assign_attributes(params_key_allowed)
    # Explicitly set these so that they are wiped if they are not present (params[__date] would be nil)
    key.start_date = params[:start_date]
    key.end_date   = params[:end_date]
    tc_key = key.dup # shallow copy, no tc's, no id/created_at/updated_at

    tc = params_time_constraints_allowed[:time_constraints]
    if tc
      tc.each do |tc|
        tc["uuid"] = request.uuid
        tc_key.time_constraints.new(tc)
      end
    end
    new_tc = get_time_constraints_hash_for_comparison(tc_key)
    @ok = true
    new_key = nil
    key.transaction do

    # Remove all existing time constraints, we'll re-create them
    # Only supporting one right now, but removing all just in case

      # If any secure parameters change, create a new key and mark the
      # old one replaced, along with it's time constraints.
      # Currently the modifiable secure params and tc hash are one and the same.
      if (new_tc == old_tc)
        # Just preserve the old unchanged, saved tc's.
        new_key = key
        save_no_share(new_key)
      else
        # Save new_key with no tc's to get key id, so we can save tc's
        # separately. See below.
        new_key = key.dup
        new_key.uuid = request.uuid

        # Clear expired notification flag on edit
        new_key.expired_notification_generated = false

        # Set exactly the same as new create time to make them relatable.
        # Could do something more explicit in the db, but for now it's
        # just for sysadmin searching.
        key.reload
        key.replaced_at = new_key.created_at = DateTime.now
        # db failures only, to default handler.
        key.save!
        save_no_share(new_key)
        # Save tc's separately, so key validator doesn't fail on tc errors
        # and return garbage messages
        # Might be worth unraveling why the messages area lost.
        # Do not share unchanged tc's between old and new, so old can
        # be archived out.
        tc_key.time_constraints.each do |tc|
          tc.key_id = new_key.id
          if !tc.save
            render_validation_error(tc)
            @ok = false
            raise ActiveRecord::Rollback
          end
        end
        new_key.time_constraints = tc_key.time_constraints
      end


      # This validates all the time_constraints as well
      # But it loses all the tc validation messages!
      # if !key.valid? render_validation_error(key)...

      # Never invalid, but can have db exception:
      LocksUser.set_admin(new_key.lock, @current_account.user.id,
                          new_key.user, params["admin"])
    end # End Transaction

    return if !@ok
    # Fire access_changed.
    # My call: no additional access_changed notification if they
    # get admin, yes if the lose it.  Easiest to just
    # not generate the event. See also LP17755057
    # Don't lose key changes on an exception here (outside transaction)
    if !becoming_admin
      #new_key.time_constraints.reload
      if (new_tc != old_tc)
        # This pattern is optional so errors say "Event"
        ev = access_changed_event(new_key)
        if ev
          return render_error(422, ModelUtil::format_validation_error(ev))
        end
      end
    end

    render :json => get_key_unsigned_hash(new_key)
  end

  private def save_no_share(new_key)
    return if new_key.save_no_share
    render_validation_error(new_key)
    @ok = false
    raise ActiveRecord::Rollback
  end


  #DELETE /keys/id
  def destroy
    json = []
    #make sure that the key is owner, owns the key
    return if params_missing([ :id ], params)

    key = Key.active_keys.readonly(false).find_by_id(params[:id])
    if key
      # Passing who is revoking the key to model for use in event creation callback
      key.revoker = @current_account.user
      # owner can revoke both admin and guest keys
      if key.lock.user == @current_account.user
        key.revoke!(nil, request.uuid)
        if key.lock.owner_and_admins.include?(key.user)
          #checks that this if this is the last key, delete LocksUser record
          all_user_keys = Key.where(:user_id => key.user.id, :lock_id => key.lock.id).active_keys
          if all_user_keys.count == 0
            lu = LocksUser.where(:user_id => key.user.id,
                                 :lock_id => key.lock.id).first.try(:destroy)
          end
        end
        render_success
        #admin can only delete guest keys (not other admins)
      elsif key.lock.admins.include?(@current_account.user) && !key.lock.owner_and_admins.include?(key.user)
        key.revoke!(nil, request.uuid)
        render_success
      else
        render_error(401, :UNAUTHORIZED)
      end
    else
      key = Key.find_by_id(params[:id])
      key ? render_error(422, "Key is already revoked") :
        render_error_modelname(404, :MISSING_RECORD, Key)
    end
  end

  private def params_key_allowed
    params.permit(:is_fob,
                  :use_limit,
                  :use_count,  # not implemented, may not need to expose writability
                  :start_date,
                  :end_date,
                  :notify_owner,
                  :pin_code,
                  :notify_locked,
                  :notify_unlocked,
                  :notify_denied,
                  :auto_unlock,
                  )
  end

  private def params_time_constraints_allowed
   params.permit(:time_constraints => [
                    :sunday,
                    :monday,
                    :tuesday,
                    :wednesday,
                    :thursday,
                    :friday,
                    :saturday,
                    :start_time,
                    :end_time,
                    :start_offset,
                    :end_offset
                   ]
                 )
  end

  private def access_changed_event(key)
    ev = Event.new(lock: key.lock,
                   key: key,
                   user: @current_account.user,
                   event_type: "access_changed",
                   event_time: Time.now,
                   uuid: request.uuid,
                 )
    return ev if !ev.save
  end
end
