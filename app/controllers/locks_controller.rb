require "resolv"

class LocksController < ApplicationController

  @@lock_endpoints = [:create, :sync, :get_credentials]
  before_filter :json_authenticate, except: @@lock_endpoints
  before_filter :json_lock_auth, only: @@lock_endpoints


  #QUESTION: during commissioning, the app also accesses update- is that a problem?

  respond_to :json

  #get lock
  def index
    locks =  @current_account.user.managed_locks
    owner = []
    admin = []
    locks.each do |l|
      lock = lock_and_key_payload(l)
      if l.user_id == @current_account.user.id
        owner << lock
      elsif l.admins.include?(@current_account.user)
        admin << lock
      end
    end
    json = owner + admin
    render :json => json
  end

  #GET /locks/id
  def show
    #it is implied that params[:id] is present
    l = Lock.find_by_id(params[:id]) #find_by_id so exception is not raised
    return render_error_modelname(404, :MISSING_RECORD, Lock) unless l
    unless l.owner_and_admins.include?(@current_account.user)
      return render_error(403, :ADMIN_ACCESS)
    end

    render :json => lock_and_key_payload(l)
  end

  # PUT /locks/<id> or /locks/serial/<lock_serial>
  # This endpoint is used in both lock commissioning and lock status sync
  def update
    return if params_missing([ :id, :lock_serial ], params, true)

    lock = Lock.get_active_else_not(params)
    return render_error_modelname(404, :MISSING_RECORD, Lock) if !lock

    # Only the owner can update the lock record
    return render_error(403, :NOT_BELONGING, Lock) if lock.user_id != @current_user_device.user_id
    return render_error(404, :LOCK_DECOMMISSIONED) if lock.decommissioned?

    lock.assign_attributes(params_app_allowed)

    new_lock = false
    if !lock.commissioned?
      # New lock, set it all up
      new_lock = true
      lock.commission_date = DateTime.now
    end

    return check_save_failure(lock) if !lock.save

    # Owner's key not created until commissioning is completed (saved) successfully.
    # TODO Transaction around this and the commissioning?
    if new_lock
      key = create_user_key(lock.id, lock.user, lock.user)
      # Validation errors may fail in interesting ways here.
    end

    render_lock_reply(lock)
  end

  def sync
    return if params_missing([:lock_serial], params, true)

    lock = Lock.get_active_else_not(params)
    return render_error_modelname(404, :MISSING_RECORD, Lock) if !lock

    new_battery = params[:battery_state]
    old_battery = lock.battery_state

    lock.assign_attributes(params_lock_allowed)

    # This allows us to pass any command flags to the lock, but clears them from the database
    # so that they are a one-time request.
    lock_clone = lock.dup
    lock_clone.id = lock.id
    lock.reboot = false
    lock.debug_log = false
    lock.last_sync = Time.now

    return check_save_failure(lock) if !lock.update_with_wifi(LockCommState::LOCK_COMM_UP, request.uuid)

    # Report initial low status at/after commissioning, but not ok status.
    # Right?
    if (((old_battery != nil) && (new_battery != old_battery)) ||
        ((old_battery == nil) && (new_battery == BatteryState::LOW)))
      Event.create!(lock_id: lock.id,
                    event_type: EventType::BATTERY,
                    string_value: new_battery,
                    event_time: DateTime.now,  # Well, close...
                    uuid: request.uuid,
                    )
    end

    render_lock_reply(lock_clone)
  end


  # GET /locks/credentials/:id or /locks/credentials/serial/:lock_serial
  # Fetches the signed account/user_device id and key id data for the lock's keys.
  def get_credentials
    return if params_missing([ :id, :lock_serial ], params, true)
    return if !get_lock_id(params)
    lock = @lock || Lock.find(params[:lock_id])
    if !lock
      render_error_modelname(404, :MISSING_RECORD, Lock)
      return
    end

    json = {
      users_devices: {}, # All users_devices user+public_key over all key owners.
      keys: [], # all keys for lock.
    }
    # Don't care if lock is decommissioned?
    keys = Key.active_keys.where(lock_id: params[:lock_id]).order(:id)
    keys.each do |key|
      json[:keys] << key.id
      UserDevice.where(user_id: key.user_id).order(:id).each do |ud|
        next if json[:users_devices][ud.id]
        rsa = CryptoRSA.new(ud.private_key)
        json[:users_devices][ud.id] = {
          user_id: ud.user_id,
          public_key: rsa.get_public_key_pem
        }
      end
    end
    json[:server_time] = Time.now.utc.iso8601(9)
    json[:expire] = ApplicationController.CREDENTIAL_MAX_TRANSIT_TIME
    json[:lock] = params[:lock_id].to_i
    # Generate a signature of the json-encoded secure data.
    json_string = render_to_string :json => json
    json = {
      credentials: json,
      signature: GojiMasterKeysGen.sign(json_string),
    }
    lock.new_credentials = false
    if lock.save
      # Don't need OTA values here, done on immediately following sync.
      render :json => json
    else
      check_save_failure(lock)
    end
  end


  # POST /locks
  def create
    return if params_missing([ :user_id, :lock_serial ], params)

    json = []
    user = User.find_by_id(params[:user_id])
    if user == nil
      return render_error_modelname(404, :MISSING_RECORD, User)
    end

    # TBD: This will eventually be refactored so that it looks up a matrix
    # of required external versions and the matching internal version pair
    required_versions = FirmwareVersions.first
    if required_versions
      params[:required_external_version] = required_versions.default_required_external_version
      params[:required_internal_version] = required_versions.default_required_internal_version
    end

    # If this lock already exists:
    # If commission not completed, act as if no record exists.
    # If commissioned by same user, decommission it and create a new record.
    # If commissioned by another user, decommissoin it and steal it.  Really?
    # https://app.liquidplanner.com/space/118303/item/18198292/documents/1768311/download
    # Security proposal: recommissioning an active lock is bad.
    # Require decommissioning first.  And require phyical possession
    # of the lock to decommission if you are not sysadmin or
    # verifiably the owner (use cases #2/3):
    # New user must enter the serial # from the
    # label.  Serial # must be prepopulated in server at lock shipment
    # (uncommissioned lock record)
    # (I believe, if we can't figure out a secure way to authenticate lock
    # commissioning requests and the owner id they contain, then we
    # will always require the label serial # to commission.  Much
    # hinges on a way to secure lock requests.)
    locks = Lock.not_decommissioned.where(lock_serial: params[:lock_serial])

    # TODO SR: To me, and per above suggestion, we reduce risk quite a bit if we don't allow an
    # already commissioned to be re-commissioned without decommissioning it first. Give to a friend
    # scenarios can always be addressed via the customer support after proper verification
    # Suggestion: Return 409 conflict if we try to commission an active lock

    if locks.load.count > 0
      # Cleanup old partial locks or active locks per use cases (see above)
      locks.each do |lock|
        if lock.active
          # TODO This is a little risky
          return if !do_decommission(lock, nil)
        elsif lock.commission_date == nil
          # Never activated record (failed commissioning), ditch it
          lock.destroy!
        else
          # We should never hit this I don't believe, but I want to know if for some reason we do
          logger.warn("Old lock cleanup: out of spec lock case, for lock id #{lock.id}")
        end
      end
    end

    # Setup the new lock
    # Per current API spec, lots of parameters allowed, TODO lock it down more
    permitted = params.permit(Lock.settable).except(:user_id)
                  .merge(uuid: request.uuid)
                  .reverse_merge(bluetooth_address: "unavailable") # merge only if it doesn't already exist)
    lock = Lock.new(permitted)
    lock.user = user

    if lock.save
      # Don't need OTA values here, done on immediately following sync.
      render :json => get_lock_hash(lock)
    else
      check_save_failure(lock)
    end
  end

  #  Decommission a lock.
  def destroy
    # Can't route without id, so this is redundant.
    return if params_missing([ :id ], params)
    #lock = Lock.where(:user_id => @current_account.user.id, :ua_token => params[:id])

    lock = Lock.find_by_id(params[:id])
    if !lock
      return render_error_modelname(404, :MISSING_RECORD, Lock)
    end
    # Allow decommissioning only from admin ui or by lock owner.
    revoker = @current_account.user
    if !current_account.admin && (lock.user != revoker)
      return render_error(401, :UNAUTHORIZED)
    end

    render_success("destroyed") if do_decommission(lock, revoker)
  end

  # Decommission and send notifications.
  # Returns false on error.
  def do_decommission(lock, revoker = nil)
    if !lock.do_decommission(revoker, request.uuid)
      check_save_failure(lock)
      return false
    end
    return true
  end

  def strip_dl_version(path)
    last_slash = path.rindex('/')
    return path if !last_slash # can't happen
    path.slice(0, last_slash+1)
  end

  def render_lock_reply(lock)
    lock_hash = get_lock_hash(lock)
    ext_firmware = lock.get_firmware(:required_external_version)
    int_firmware = lock.get_firmware(:required_internal_version)
    if ext_firmware || int_firmware
      # Try to be efficient, this is expensive (even if just for alpha!)
      resolver = Resolv::DNS.new
      if ext_firmware
        # restore after alpha when firmware no longer needs separate field lengths and can handle longer strings?
        #lock_hash["external_url"] = Firmware::HTTP_ROOT + ext_firmware.first.download_url
        lock_hash["external_host"] = Firmware::HTTP_HOST
        lock_hash["external_path"] = Firmware::HTTP_BUCKET + strip_dl_version(ext_firmware.first.download_url)
        # *_ip is temporary for alpha so the lock http code doesn't
        # have to resolve dns.
        addr = get_ip(resolver, Firmware::HTTP_HOST)
        return if ! addr
        lock_hash["external_ip"] = addr
      end
      if int_firmware
        lock_hash["internal_url"] = Firmware::FTP_ROOT + int_firmware.first.download_url
        lock_hash["internal_host"] = Firmware::FTP_HOST
        lock_hash["internal_path"] = '/' + strip_dl_version(int_firmware.first.download_url)
        lock_hash["internal_user"] = Firmware::FTP_USER
        lock_hash["internal_pass"] = Firmware::FTP_PASS
        addr = get_ip(resolver, Firmware::FTP_HOST)
        return if ! addr
        lock_hash["internal_ip"] = addr
      end
      resolver.close
    end
    #Validates that everything in lock_hash is less than 48 chars and readable by the firmware
    validate_and_render_payload(lock_hash, int_firmware)
  end

  def validate_and_render_payload(payload, int_firmware)
    payload.each do |key, val|
      if val.class == String
        if (key == "external_url" || key == "external_path" ||
          key == "internal_url" || key == "internal_path")
          return render_error(422, :OTA_STRING_TOO_LONG, key) if
            ((key == "internal_url") ? int_firmware.first.download_url :
             val).length > StringLength::STRLIM_OTA_URL.to_i
        elsif val.length > StringLength::STRLIM_GENERAL.to_i
          return render_error(422, :STRING_TOO_LONG, key)
        end
      end
    end
    render :json => payload
  end

  def get_ip(resolver, hostname)
    addr = resolver.getaddress(hostname)
    return addr.to_s if addr
    # XXX test!
    render_error(500, "DNS failure looking up hostname")
    return nil
  end

  def lock_and_key_payload(lock)
    keys = []
    admin_keys = []
    guest_keys =[]
    # Order for presentation at the UI, by owner/admin, then by issuance date.
    lock.active_keys.order('created_at DESC').each do |key|
      hash = get_key_unsigned_hash(key, false) # no server time
      if key.user == lock.user
        keys       << hash
      elsif lock.admins.include?(key.user)
        admin_keys << hash
      else
        guest_keys << hash
      end
    end
    keys = keys + admin_keys + guest_keys

    # Don't need OTA values here
    # Good thing, the temp alpha DNS lookups are expensive.
    hash = get_lock_hash(lock)
    hash[:keys] = keys
    # Return the latest access event to support status display in
    # A.5.
    last_access_event = lock.events.where(:event_type => [EventType::UNLOCK, EventType::LOCK]).order('event_time DESC').first
    unless last_access_event.nil?
      hash[:event_type]           = last_access_event.event_type
      hash[:event_string_value]   = last_access_event.string_value
      hash[:event_bolt_state]     = last_access_event.bolt_state
      hash[:event_user_full_name] = last_access_event.user.try(:display_name)
      hash[:event_user_id]        = last_access_event.user_id
      hash[:event_time]           = last_access_event.event_time
    end
    return hash
  end

  def get_lock_hash(lock)
    hash = get_payload_hash(lock)
    # XXX obsolete, remove
    hash[:last_access] = lock.last_access
    # Unused as yet, long string may break hash string parsing.
    # hash[:image_url] = lock.image.try(:expiring_url, GojiServer.config.s3_url_expire)
    hash[:status] = lock.bolt_state # DEPRECATED to be removed after apps update
    hash
  end

 private
  def params_lock_allowed
    params.permit(:internal_version,
                  :external_version,
                  :battery_level,
                  :battery_state,
                  :bolt_state)
  end

  def params_app_allowed
    params.permit(:name,
                  :internal_version,
                  :external_version,
                  :battery_level,
                  :battery_state,
                  :bolt_state,
                  :orientation,
                  :auto_unlock_owner,
                  :auto_unlock_others,
                  :required_internal_version,
                  :required_external_version,
                  :bluetooth_address, 
                  :time_zone)
  end

end
