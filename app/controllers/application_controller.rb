class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  #protect_from_forgery with: :exception

  force_ssl if: lambda{ token_present? && GojiServer.config.use_ssl_if_possible }
  before_action :brute_force_detection

   # global filters
  helper :all

  def brute_force_detection
    return if !request.path.eql?("/accounts/sign_in") || request.params[:account].nil?
    ##Monitoring unauthorized errors, generate customized log for tracking brute force attacks
    #log every alert message for all invalid emails and passwords; Setup PaperTrail frequencies
    #for these log.
    current_timestamp = Time.now
    email = request.params[:account][:email]
    password = request.params[:account][:password]
    account = Account.first_by_email(email)
    if !account || !account.valid_password?(password)
      log_security_brute_force_alert_message(email, !account)
    end
  end

  def log_security_brute_force_alert_message(email, account)
    message = "Security: BruteForce Alert: Failed attempt with invalid "
    message += "password, " if !account
    message += "Email=#{email}, Path=#{request.path}, RemoteIP=#{request.remote_ip}"
    logger.warn(message)
  end

  # Map X-Goji headers to params.
  def headers_to_params
    # Generically capture any param supplied as X-Goji-paramname in header
    # Request.header names are mapped to uppercase as the Rails 4
    # comments say, but this may change (raging debate).
    # Could be defensive and map both ways...
    # So paramname must NOT contain uppercase characters or "-"!
    header_prefix = env_name("X-Goji-")
    #header_prefix = "X-Goji-"
    # XXX performance: this is expensive (~45 vars to check).  Could
    # enumerate the var names of interest, esp. just user_device_id
    # for json_authenticate.
    logger.debug("headers: ") if Util.is_dev
    request.headers.each do |name, value|
      logger.debug(name + "=" + value.to_s) if Util.is_dev
      if name.start_with? header_prefix
        #params[name[header_prefix.length..-1]] = value
        params[name[header_prefix.length..-1].downcase] = value
      end
    end
    # If we like this pattern, make a logger subclass with logger.dev method.
    # Though it may incur a bit of production overhead.
    logger.debug(" With header: " + params.to_s) if Util.is_dev
  end

  # Ugh, because the header name mapping to uppercase is in
  # ActionDispatch, apparently it isn't exercised in controller tests,
  # or even integration tests.  So we must fake it here.
  def self.make_header_name(name)
    #'X-Goji-' + name.to_s
    'HTTP_X_GOJI_' + name.to_s.upcase
  end

  # This map-to-env-style change in Rails 4 was a stupid idea IMHO.
  # Copied this method from headers.rb because they stupidly hid it!
  def env_name(key)
    key = key.to_s
    if key =~ ActionDispatch::Http::Headers::HTTP_HEADER
      key = key.upcase.tr('-', '_')
      key = "HTTP_" + key unless ActionDispatch::Http::Headers::CGI_VARIABLES.include?(key)
    end
    key
  end

  # nil is false in received payloads.
  def self.string_to_boolean(string_bool)
    string_bool == 'true'
  end

  def self.is_empty(string)
    string == nil || string == ""
  end

  # TBD: Authenticate a lock
  def json_lock_auth
    # Temporary, to insure auth from non-lock access.
    # Long-term, don't tie auth type to id/serial.
    # Right now this does nothing, as authentication spec
    # for the lock is still in progress
  end

  def token_present?
    # XXX remove params check.
    params[:authtoken].present? || request.headers['Authorization']
  end

  def has_lock_serial?
    params[:lock_serial].present?
  end

  # Map alternate lock id's to lock_id param, may get lock record.
  # Note: accepts un/decomissioned locks.
  def get_lock_id(params)
    @lock = nil
    if params[:id]
      params[:lock_id] = params[:id]
      return true
    end
    if params[:lock_serial]
      @lock = Lock.get_locks(params).first
      if !@lock
        render_error_modelname(404, :MISSING_RECORD, Lock)
        return false
      end
      params[:lock_id] = @lock.id
    end
    return true
  end

  # Before filter method used for authentication for json api controllers
  # On success, sets:
  #   @current_account  
  #   @current_user_device
  #   @current_device
  def json_authenticate
    # Pass required X-Goji-user_device_id in header for LP16570894.
    headers_to_params
    if params_missing([:user_device_id], params, false, false) || params[:user_device_id].nil?
      log_security_unauthorized_alert_message("UserDevice", "user_device_id")
      return render_error(401, :UNAUTHORIZED)
    end
    missing = params_missing([:authtoken], params, false, false)
    if missing
      if authenticate_with_http_token do |token, options|
          params[:authtoken] = token
        end
      else
        log_security_unauthorized_alert_message("UserDevice", "authtoken")
        return render_error(401, :UNAUTHORIZED)
      end
    end

    user_device = UserDevice.find_by_id(params[:user_device_id])
    if user_device && Devise.secure_compare(user_device.authentication_token, params[:authtoken])
      @current_account  = User.find(user_device.user_id).account
      # XXX performance: could defer these lookups until needed.
      @current_device = Device.find(user_device.device_id)
      @current_user_device = user_device
    else
      if user_device.nil?
        name = "invalid user_device_id=#{params[:user_device_id]}"
        log_security_unauthorized_alert_message("UserDevice", name, nil)
      else
        log_security_unauthorized_alert_message("UserDevice", "authtoken", "mismatched")
      end
      return render_error(401, :UNAUTHORIZED)
    end
  end

  def log_security_unauthorized_alert_message(model, name, err_type="missing")
     message = "Security: Unauthorized to #{model} Alert: #{err_type} #{name}, Path=#{request.path}, Action=#{params[:action]}, RemoteIP=#{request.remote_ip}"
     logger.warn(message)
  end

  def render_error_modelname(code, msg, model) # model is e.g. Lock
    render_error(code, msg, model.model_name.human)
  end

  def render_validation_error(model)
    render_error(422, ModelUtil::format_validation_error(model))
  end

  # Call this when .save() returns false.
  def check_save_failure(model)
    if model.valid?
      # We believe that this is unreachable code, that .save()
      # only returns false on a validator error, exceptions on all
      # other errors.
      render_error_modelname(500, :DATABASE_RECORD, model.class)
    else
      render_validation_error(model)
    end
    return
  end

  # Since there is no I18N requirement here, OK to leave strings
  # in the calling code if they are only used once.
  @@MESSAGES = {
    DATABASE_RECORD: "database error saving %s record",
    UNAUTHORIZED: "unauthorized",
    UNCONFIRMED: "user_device has not confirmed",
    DECOMMISSIONED: "User-Device registration has been decommissioned",
    LOCK_DECOMMISSIONED: "Lock record has been decommissioned and can not be changed",
    SUCCESS: "Success",
    ADMIN_ACCESS: "You do not have admin access to this lock and are not it's owner",
    MISSING_PARAM: "missing parameter: ",
    MISSING_ALL_PARAMS: "one of these parameters is required: ",
    INVALID_CURRENT_PASSWORD: "Invalid Current Password",
    MISSING_RECORD: "%s record not found",
    WRONG_ACCOUNT_PARAM: "%s parameter doesn't match authenticated user and device",
    WRONG_DEVICE: "%s parameter must not match authenticated device",
    WRONG_PARAM: "%s parameter is invalid",
    BAD_PARAM: "%{value} is not a valid %{attribute}",
    INVALID_PARAM: "Invalid ", # test code only, for validator messages
    BAD_ROUTE: "No route matches ", # test code only
    # XXX Need to more fully validate validation messages: field name, # & type of error messages.
    NOT_KEY_ADMIN: "Forbidden: Not an owner or admin of key's lock",
    ADMIN_NOT_OWNER: "Forbidden: admins cannot promote to admin/modify permissions of other admins",
    STRING_TOO_LONG: "%s is too long (maximum is #{StringLength::STRLIM_GENERAL} characters)",
    OTA_STRING_TOO_LONG: "%s is too long (maximum is #{StringLength::STRLIM_OTA_URL} characters)",
    DB_STRING_TO_LONG: "%s is too long (maximum in #{StringLength::STRLIM_DB} characters)",
    NOT_BELONGING: "The %s does not belong to the user"
  }

  # For test convenience.
  def self.MESSAGES
    @@MESSAGES
  end

  # No picture should take more than 1 minute after the event to upload, we hope.
  # So picture may be applied to events occuring up to 1 minute later.
  # Could this really be less, maybe 20 seconds?  Occasionally too
  # short is OK for setting picture_pending, as app can recover on
  # event reload.  Allow Heroku env override.
  @@MAX_PICTURE_ASYNC = 60
  def self.MAX_PICTURE_ASYNC
    (ENV["MAX_PICTURE_ASYNC"] || @@MAX_PICTURE_ASYNC).to_i
  end
  def self.MAX_PICTURE_ASYNC_TIME
    self.MAX_PICTURE_ASYNC.seconds
  end
  # Lock can set event.event_time slightly before picture.taken_at.
  @@MAX_PICTURE_SKEW = 5
  def self.MAX_PICTURE_SKEW
    @@MAX_PICTURE_SKEW
  end
  # Configure lock's credential expiration that prevents replay.
  # Goes in credential expire field (in seconds).
  # Currently the same for both direct and proxied transfer, may need
  # tuning and possibly splitting.
  @@CREDENTIAL_MAX_TRANSIT_TIME = 60
  def self.CREDENTIAL_MAX_TRANSIT_TIME
    (ENV["CREDENTIAL_MAX_TRANSIT_TIME"] || @@CREDENTIAL_MAX_TRANSIT_TIME).to_i
  end

  def render_error(code, msg, *args)
    render_error_format(code, msg, false, *args)
  end
  def render_error_list(code, msg, *args)
    render_error_format(code, msg, true, *args)
  end
  def render_error_format(code, msg, do_join, *args)
    if msg.class == Symbol
      msg = @@MESSAGES[msg]
    end
    if do_join
      msg += args.join(', ')
    elsif args.count > 0
      msg = sprintf(msg, *args)
    end
    logger.warn("Error returned to client: " + code.to_s + ": " + msg)
    render json: {
      error:  msg,
      status: code
    }, status: code
  end

  def params_missing(required, params,
                     one_of = false, report = true) # need only one of required, else all
    # I wonder how expensive this is...if converting to symbols would be faster.
    # Empty is the same as missing, so clean up for easier testing.
    # Perhaps should do this even when not calling this method.
    params.inject(params) { |p,(k,v)| p.delete(k) if (v == ""); p }
    missing = (required.map &:to_s) - params.keys.to_a
    if one_of ? (missing.count == required.count) : (missing.count > 0)
      render_params_missing(missing, one_of) if report
      return missing
    end
    return false
  end

  private def render_params_missing(missing, one_of = false)
    render_error_list(422, one_of ? :MISSING_ALL_PARAMS : :MISSING_PARAM, missing)
  end

  def render_success(message = nil)
    render json: {
      message: message ? message : @@MESSAGES[:SUCCESS],
      status: 200
    }, status: 200
  end

  # logs out any users if they aren't admins
  def ensure_admin_account
    if current_account && !current_account.admin?
      sign_out(current_account)
      redirect_to '/accounts/sign_in', :alert => "Sorry, You must be an admin to access this page. Please log in with an admin account." 
    end
  end

  # Capture the total effective time_constraint state for comparison:
  # time_constraints, start_offset, end_offset.
  def get_time_constraints_hash_for_comparison(key)
    tc_list = []

    key.time_constraints.each do |tc|
      tc_list << {
        bitmask: TimeConstraint.get_days_bitmask(tc),
        start_offset: tc.start_offset,
        end_offset:   tc.end_offset,
      }
    end

    return {
      tc: tc_list,
      start_date: key.start_date,
      end_date: key.end_date,
    }
  end

  private

=begin
  # Not currently used by anyone...checks if time is equal to midnight
  def normalize_time(t)
    # Don't understand why time has a date, and gets converted to this on
    # db fetch.
    if (t == Time.parse("2000-01-01 00:00Z"))
      return nil
    end
    return t
  end
=end

  def create_new_key(lock_id, email, from_user, params = nil)
    Key.create_new_key(lock_id, email, from_user, params)
  end
  def create_key(lock_id, to_user, from_user, params = nil)
    Key.create_key(lock_id, to_user, from_user, params)
  end

  def create_user_key(lock_id, to_user, from_user, params = nil)
    Key.create_user_key(lock_id, to_user, from_user, params)
  end

  # abstraction method used by the lock and key controllers
  # to return the key json structure
  # Should be self. class method
  def get_key_data_hash(key)
    key_arr = {}
    time_constraints = []
    key.time_constraints.each do |tc|
      time_constraints << {
        :valid_days_mask => TimeConstraint.get_days_bitmask(tc),
        :start_offset    => tc.start_offset,
        :end_offset      => tc.end_offset,
      }
    end
    key_arr[:id] = key.id
    key_arr[:lock_id] = key.lock_id
    key_arr[:user_id] = key.user_id
    key_arr[:start_date] = key.start_date
    key_arr[:end_date] = key.end_date
    key_arr[:time_constraints] = time_constraints
    return key_arr
  end

  def get_key_info_hash(key, time = true)
    time_constraints = []
    key.time_constraints.each do |tc|
      time_constraints << {
        :monday          => tc.monday,
        :tuesday         => tc.tuesday,
        :wednesday       => tc.wednesday,
        :thursday        => tc.thursday,
        :friday          => tc.friday,
        :saturday        => tc.saturday,
        :sunday          => tc.sunday,
        :id              => tc.id
      }
    end
    key_arr = get_payload_hash(key, [:id, :lock_id, :user_id,
                                     :start_date, :end_date], nil, time)
    key_arr[:bluetooth_address]= key.lock.bluetooth_address
    key_arr[:name]             = key.lock.name
    key_arr[:new_credentials]  = key.lock.new_credentials
    key_arr[:last_access]      = key.last_access
    key_arr[:first_name]       = key.user.account.first_name
    key_arr[:last_name]        = key.user.account.last_name
    key_arr[:email]            = key.user.account.email
    key_arr[:user_display_name]= key.user.display_name
    # Legacy for GET /keys only
    lu = key.get_locks_users()
    if lu
      key_arr[:lock_user]  = get_payload_hash(lu, [:lock_id, :user_id], #nil,
                                              nil, false,
                                              { note: "Legacy for GET /keys only, deprecated, use admin flag" })
      if lu.admin
        # Backward compatiblity, to be removed once apps switch to admin + lock_owner_key (done, can go away now):
        key_arr[:auto_generated] = true
      end
    end
    # Is the key owner an admin for this key's lock?
    key_arr[:admin]            = lu ? lu.admin : false
    key_arr[:time_constraints] = time_constraints

    return key_arr
  end

  def get_key_hash(key_data, key_info, signed = false)
    hash = {
         key_data: key_data,
    }
    hash[:signature] = GojiMasterKeysGen.sign(render_to_string :json => key_data) if signed
    hash[:key_info] = key_info
    return hash
  end

  def get_key_unsigned_hash(key, time = true) # server time?
    get_key_hash(get_key_data_hash(key), get_key_info_hash(key, time))
  end

  # Map an API payload to/from a model.
  # Excludes fields that never occur in a payload, plus the supplied exclude array of field names.
  # Also excludes anything not in model.attr_accessible.
  @@never = [ :created_at, :updated_at,
              :pin_code, #deprecated, will remove
              :uuid, # For sysadmin only
              :image_file_name, # not ever in attr_accessible, so drop?
              :image_content_type,
              :notify_locked,   #notification groups TBD
              :notify_unlocked,
              :notify_denied,
              :image_file_size,
              :image_updated_at ]
  # Should be self.
  def get_payload_hash(model, exclude=nil, # additional fields to exclude
                       allow=nil,   # override accessible_attributes
                       time=true,   # include server_time field
                       extra=nil)   # Extra fields to insert (comments!)
    # Note - this doesn't work with attr_protected, we don't use it.
    if allow
      accessible = allow
    else
      # model.*_attribute() take either string or symbol for name, but
      # exclude delete requires symbols.
      accessible = model.class.accessible_attributes.to_a.map &:to_sym
    end
    # (Almost) always return the id, any seq_no.  Could generalize to a whitelist arg.
    accessible << :id
    accessible << :seq_no
    model_exclude = @@never
    model_exclude += model.response_exclude if (model.respond_to?(:response_exclude))
    exclude = exclude ? exclude + model_exclude : model_exclude
    exclude.each do |name|
      accessible.delete(name)
    end
    # Always send the server time for security.
    payload = time ? {
      :server_time => Time.now.utc.iso8601(9)
    } : { }
    accessible.each do |name|
      if model.has_attribute?(name)
        payload[name] = model.read_attribute(name)
      end
    end
    if (extra)
      extra.each do |name, val|
        payload[name] = val
      end
    end
    payload
  end

  # Should be self.
  def get_payload_hash_arr(relation, exclude)
    arr = []
    relation.each do |item|
      arr << get_payload_hash(item, nil)
    end
    arr
  end

  rescue_from Exception do |e|
    case e.class.to_s
      when 'ActiveRecord::RecordInvalid', 'PG::StringDataRightTruncation'
        # This is a fallback for missed validator errors that
        # are better reported by render/format_validation_error().
        # (It reports the failing model classname.)
        render_error 422, e.to_s
      else
        # NewRelic appears to properly de-duplicate the exception, so raising again
        # doesn't cause two errors in the metrics
        ErrorRecorder.notice_exception("Uncaught Exception", e)
        raise e
      #TBD: needs to be fleshed out with more exceptions - LP17626916
    end
  end


  # Create new device if not supplied, and user_device association if
  # it doesn't exist.
  # Else update existing device info/ua_token.
  def create_user_device(params, device, user,
                         confirm)  # boolean: preconfirm device
    user_device = nil
    permitted = params.permit(Device.settable).merge(uuid: request.uuid)
    if device
      # XXX what about decommissioned user_device???
      user_device = UserDevice.where(device_id: device.id,
                                     user_id: user.id).first
      device.assign_attributes(permitted)
    else
      device = Device.new(permitted)
    end
    # Invalid device_type reports here.
    return check_save_failure(device) if !device.save

    # Is there a scenario with confirm=true (account create)
    # where user_device already exists unconfirmed?
    # Nope, won't do account create if user+account exists.
    user_device_exists = !!user_device
    if !user_device_exists
      # Should not fail
      user_device = UserDevice.new(user_id:   user.id,
                                   confirmed_at: confirm ? DateTime.now : nil,
                                   device_id: device.id,
                                   uuid: request.uuid,
                                   )
      return check_save_failure(user_device) if !user_device.save
    end
    return [ device, user_device, user_device_exists ]
  end

  def after_sign_in_path_for(resource)
    entropy_settings = RailsAdmin.config.registry["app_globals"][:password][:entropy]
    if (resource.password_entropy_percent == nil) ||
       (resource.password_entropy_percent < (entropy_settings[:good].to_f*100)/entropy_settings[:max])
      flash[:notice] = "You must change your password so that it is more secure."
      RailsAdmin::Engine.routes.url_helpers.edit_path(model_name: 'sysadmin_users', id: resource.id)   
    else
      rails_admin_path
    end
  end
end
