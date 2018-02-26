# load before all else
if ENV["RAILS_ENV"] == ""
   ENV["RAILS_ENV"] = "test"
end

require File.expand_path('../../config/environment', __FILE__)

require 'timeliness/definitions'

require "rails/test_help"

class ActiveSupport::TestCase

  ##### Test configuration

  # log all replies for API spec
  @@do_log_json = ENV['LOG_JSON'] == 'true'
  # log notification strings
  @@do_log_notifications = ENV['LOG_NOTIFICATIONS'] == 'true'
  # log all tested fields, check that we've in fact checked them all.
  @@trace = ENV['TRACE_FIELD_VALIDATION'] == 'true'
  # Disable Arxan key generation for testing without Arxan libs.
  @@no_keypairs = ENV['NO_KEYPAIRS'] == 'true'

  ##### End Test configuration

  # Allow testing real emails with sendgrid, enable in .env
  @@guest_email = 'glennguest@example.com'
  @@real_email = ENV['SEND_TEST_EMAIL'] ? 'glennwidener@gmail.com' : @@guest_email
  #@@real_email = 'glenn.widener@room5.com'
  # Can't actually send and also validate deliveries
  @@mail_count = ENV['SEND_TEST_EMAIL'] ? 0 : 1
  @@device_start_count = 0
  @@user_device_start_count = 0

  @@Timeliness_init = false

  @@INTERNAL_VERSION = "0.0.9V"
  @@EXTERNAL_VERSION = "0.0.9T"
  def self.INTERNAL_VERSION
    return @@INTERNAL_VERSION
  end
  def self.EXTERNAL_VERSION
    return @@EXTERNAL_VERSION
  end
  # model and integration tests don't inherit from ActiveSupport::TestCase
  def self.mail_count
    return @@mail_count
  end
  cattr_accessor :device_start_count
  cattr_accessor :user_device_start_count
  def self.ev_first
    return @@ev_first
  end
  def self.ev_second
    return @@ev_second
  end

  def make_dummy_firmware_versions()
    # Hack around required fields.
    # One of these days I'll figure out why create can't accept boolean values...
    if (Firmware.all.count >= 2)
      return
    end
    Firmware.create!(version: @@INTERNAL_VERSION, for_external: false,
                     download_url: FirmwaresController.gen_download_url(@@INTERNAL_VERSION, "false"), data_file_name: "foo")
    Firmware.create!(version: @@EXTERNAL_VERSION, for_external: true,
                     download_url: FirmwaresController.gen_download_url(@@EXTERNAL_VERSION, "true"), data_file_name: "foo")
  end

  def make_auth_string(user, pass)
    "Basic " + Base64.strict_encode64(user + ":" + pass)
  end

  def make_auth_token_string(token)
    "Token token=" + token
  end
  def make_auth_token_hash(token)
    {
      'Authorization' => make_auth_token_string(token)
    }
  end

  def send_auth(user_device)
    # Could actually GET /authtoken, but would be slower.
    user_device.login if !user_device.authentication_token
    header_auth(user_device.authentication_token, user_device.id)
  end

  def header_auth(token=nil, ud_id=nil)
    value = nil
    if !token.nil?
      value = make_auth_token_string(token)
    end
    name = 'Authorization'
    add_to_header(name, value)

    name = 'user_device_id'
    value = nil
    if !ud_id.nil?
      value = ud_id.to_s
    end
    add_to_header(name, value)
  end

  def add_to_header(name, value)
    if name=='Authorization'
      request.headers[name] = value
    else
      request.headers[ApplicationController::make_header_name(name)] = value
    end
  end

  # Add methods to be used by unit tests here
  def make_account(email: 'jdoe@emmoco.com', password: 'aba456',
                   admin: false, first: 'John', last: 'Doe')  # system admin, not lock admin
    # account is a devise model, must set properties at instance level and not in constructor
    Account.create!(:first_name            => first,
                    :last_name             => last,
                    :email                 => email,
                    :password              => password,
                    :password_confirmation => password,
                    :admin                 => admin,
                    :confirmed_at          => DateTime.now.utc.iso8601(9),
                    :confirmation_sent_at  => DateTime.now.utc.iso8601(9)
                    )
  end
  def make_unconfirmed_account(email = 'unconfirmeduser@example.com', password = 'aba456',
                               admin = false)  # system admin, not lock admin
    # account is a devise model, must set properties at instance level and not in constructor
    Account.create!(:first_name            => 'John',
                    :last_name             => 'Doe',
                    :email                 => email,
                    :password              => password,
                    :password_confirmation => password,
                    :admin                 => admin,
                    )
  end
  def make_user(email = 'jdoe@emmoco.com', password = 'aba456',
                admin = false, first = 'John', last = 'Doe')
    make_user_core(email, password, admin, nil, first, last)
  end
  def make_user_from_account(account)
    make_user_core('jdoe@emmoco.com', 'aba456', false, account)
  end
  def make_user_core(email, password, admin, account, first = "John", last = "Doe")
    # Allow being called again.
    ua_token = '45afe3cbfb716c0eb61adc2d6da1f2781e8b74d39b49c1e521108db9109b1bfa'

    if !account
      account = Account.where("email = ?", email).first
      if (account)
        device = Device.find_by_ua_token(ua_token)
        user_device = UserDevice.where(user_id:account.user.id, device_id: device.id).first
        return account.user, device, user_device
      end
    end
    if !account
      account = make_account(email: email, password: password, admin: admin, first: first, last: last)
    end
    user = User.new(:account_id => account.id)
    user.time_zone       = 'Central Time (US & Canada)'
    user.save!
    account.user = user
    # Confirmed accounts must have device to be confirmed.
    device, user_device =make_device(user, ua_token) if account.confirmed_at
    return [user, device, user_device]
  end

  def make_lock(user, commissioned = true)
    make_dummy_firmware_versions()
    lock = Lock.create!(:user_id => user.id,
                       :name => "Front Door",
                       :orientation => "left",
                       :bolt_state => "unlocked",
                       :commission_date => commissioned ? DateTime.now.utc.iso8601(9) : nil,
                       :bluetooth_address => "ALEX-1234",
                       :lock_serial => Digest::MD5.hexdigest(user.id.to_s + rand(100000).to_s),
                       :internal_version => @@INTERNAL_VERSION,
                       :external_version => @@EXTERNAL_VERSION,
                       :required_internal_version => @@INTERNAL_VERSION,
                       :required_external_version => @@EXTERNAL_VERSION,
                      )
  end

  # XXX replace with this everywhere!
  # This isn't quite our reply format, but it parses, can be
  # compared to db, and tests enough resolution.
  def comparable_payload_date_now
    DateTime.now.utc.iso8601(3)
  end

  # user must be owner/admin
  def make_guest_key(lock, guest_email, user)
    key = Key.create_new_key(lock.id, guest_email, user)

    # permission error
    return key if (key.class == Hash)
    start = 60*60
    tc = TimeConstraint.create!(:key_id      => key.id,
                                :start_offset=> start.to_s,
                                :end_offset  => (start*2).to_s,
                                :monday      => true,
                                :tuesday     => true,
                                :wednesday   => true,
                                :thursday    => true,
                                :friday      => false,
                                :saturday    => true)
    # update seq_no
    key.reload
    return key
  end

  def make_auto_key(lock, key_owner_email, sharing_user)
    Key.create_new_key(lock.id, key_owner_email, sharing_user, { auto_generated: true })
  end

  def make_primitive_auto_key(lock, key_owner, sharing_user)
    Key.create_key(lock.id, key_owner, sharing_user, { auto_generated: true })
  end

  # Make a key for owner/admin
  def make_key(lock, user)
    # sharer_user_id faked
    key = make_guest_key(lock, user.account.email, user)
    return key
  end

  def make_primitive_device(ua_token)
    dev = Device.find_by_ua_token(ua_token)
    return dev if dev
    @@device_start_count += 1
    Device.create!(ua_token:    ua_token,
                   device_type: "iosdevelopment", # Use the sandbox for extra safety
                   )
  end

  def make_device(user, ua_token = '64ce3cbfb716c0eb61adc2d6da1f2781e8b74d39b49c1e521108db9109b1be35')
    # In normal flow unconfirmed accounts don't have a device or user_device yet.
    dev = make_primitive_device(ua_token)
    user_device = make_confirmed_user_device(user, dev, ua_token)
    return [dev, user_device]
  end

  @@confirmed_device_token = '64ce3cbfb716c0eb61adc2d6da1f2781e8b74d39b49c1e521108db9109b1be35'
  cattr_accessor :confirmed_device_token

  def make_confirmed_device(user, ua_token = @@confirmed_device_token)
    return make_confirmed_device_ud(user, ua_token)
  end

  def make_confirmed_device_ud(user, ua_token = '64ce3cbfb716c0eb61adc2d6da1f2781e8b74d39b49c1e521108db9109b1be35')
    dev = make_primitive_device(ua_token)
    user_device = make_confirmed_user_device(user, dev)
    return [dev, user_device]
  end

  # XXX remove ua_token here
  def make_user_device(user, device,
                       ua_token = '64ce3cbfb716c0eb61adc2d6da1f2781e8b74d39b49c1e521108db9109b1be35')
    @@user_device_start_count += 1
    UserDevice.create!(user_id:      user.id,
                       device_id:     device.id,
                       name:          "Test Device",
                       )
  end

  def make_confirmed_user_device(user, device, ua_token = '64ce3cbfb716c0eb61adc2d6da1f2781e8b74d39b49c1e521108db9109b1be35')
    @@user_device_start_count += 1
    params = {
      :user_id      => user.id,
      :device_id    => device.id,
      :name         => "Test Device",
      # really?
      :authenticated_at => DateTime.now,
      :confirmed_at => DateTime.now,
      :private_key => OpenSSL::PKey::RSA.new(GojiCryptoParam::RSA_KEY_SIZE.to_i).to_pem
    }
    params[:keys_sent_at] = DateTime.now if @@no_keypairs
    user_device = UserDevice.create!(params)
    # There are now never confirmed accounts without devices+user_devices.
    # Hack to avoid massive test changes; user.account.authentication_token
    # is now unused (except sysadmin (see account.rb)?)
    # This workaround can fail with multiple devices/user, we should
    # continue to migrate the tests.  authtoken is now generated at
    # login, tests assume they can make requests without hitting the
    # get auth endpoint.
    user_device.login
    user_device
  end

  def make_admin_user(lock, user)
    # Don't generate invalid events.
    # Must have a key to deliver an emaail on an ADMIN_SHARED event.
    # Why restrict to first key for lock???
    if (lock.active_keys.count == 0)
      make_primitive_auto_key(lock, user, lock.user)
    end
    #@sharer      = make_user('glenn.widenersharer@gmail.com')
    @sharer = lock.user
    LocksUser.create!(:lock_id  => lock.id,
                      :sharer_user_id => @sharer.id,
                      :user_id  => user.id,
                      :admin    => true)
    @make_admin_user_event_data = {
      :lock_id => @lock.id,
      :user_id => @sharer.id,
      :admin_user_id => user.id,
      :event_type => 'admin_shared',
      :event_time => DateTime.now.utc.iso8601(3),
    }
  end

  # Extra was thought to be required on any event that sends email.
  # Found another way - this time...
  def add_extra_data(data)
=begin
    data[:extra] = {
      password: 'mypass',
      host: 'myhost',
      port: 'myport',
    }
=end
    return data
  end

  def check_admin_event(ev, lock, affected_user, from_user, type, line = nil)
    check_data(ev, {
                 lock_id: lock.id,
                 user_id: from_user.id,
                 admin_user_id: affected_user.id,
                 event_type: type,
                 event_time: DateTime.now.utc.iso8601(3),
               },
               nil, true, [
                 :key_id, :picture_id, :string_value, :int_value
               ], line)
  end

  def check_key_shared_event(ev, key, from_user = nil, line = nil)
    check_key_event(ev, key, 'key_shared', from_user, line)
  end

  def check_access_event(ev, key, from_user = nil, line = nil)
    check_key_event(ev, key, 'access_changed', from_user, line)
  end

  def check_key_event(ev, key, type, from_user = nil, line = nil)
    from_user ||= @user  # matches create_basic_key() default
    check_data(ev, {
                 lock_id: key.lock_id,
                 key_id: key.id,
                 user_id: from_user.id,        # user causing the event
                 event_type: type,
                 event_time: DateTime.now.utc.iso8601(3),
               },
               nil, true, [
                 :picture_id, :string_value, :int_value
               ], line)
  end

    # Event submission order not specified.

  def put_event_last(last_type)
    evs = Event.all.order('created_at ASC')
    @@ev_first = evs[evs.length-2]
    @@ev_second= evs[evs.length-1]
    if (@@ev_first.event_type == last_type)
      ev = @@ev_first
      @@ev_first = @@ev_second
      @@ev_second = ev
      return true
    end
  end

  def check_locks_user(lock, user_id, admin, exists = true)
    lu = LocksUser.where(:lock_id => lock.id,
                         :user_id => user_id)
    assert_equal exists ? 1 : 0, lu.count, exists ? "locks_user exists" : "locks_user does not exist"
    if exists
      assert_equal admin, lu[0].admin, "locks_user admin flag"
    end
  end

  def check_key_by_id(lock_id, user_id, sharer_id)
    keys = Key.where(:lock_id => lock_id,
                     :user_id => user_id)
    assert_equal 1, keys.count, "check_key_by_id: got one key"
    keys.first
  end

  def check_auto_key(lock, user, sharer_id)
    check_auto_key_by_id(lock.id, user.id, sharer_id)
  end

  def check_auto_key_by_id(lock_id, user_id, sharer_id)
    keys = Key.where(:lock_id => lock_id,
                     :user_id => user_id,
                     :auto_generated => true)
    assert_equal 1, keys.count, "check_auto_key: wrong key count"
    assert_equal sharer_id, keys[0].sharer_user_id, "check_auto_key: sharer_user_id"
    assert_nil keys[0].start_date, "check_auto_key: start_date"
    assert_nil keys[0].end_date, "check_auto_key: end_date"
    assert_equal 0, TimeConstraint.where(:key_id => keys[0].id).count, "check_auto_key: got no TimeConstraints"
  end

  def verify_by_goji_master_pub_key(signature, data)
    goji_priv_key = GojiMasterKeysGen.get_goji_master_private_key
    rsa = CryptoRSA.new(goji_priv_key)
    return rsa.rsa_verify_sha1(signature, data)
  end

  def decrypt_with_goji_master_pub_key(data)
    goji_priv_key = GojiMasterKeysGen.get_goji_master_private_key
    rsa = CryptoRSA.new(goji_priv_key)
    encrypted = rsa.rsa_pub_decrypt(data)
  end

  def check_user_device_arxan_keypair(code = :success)
    assert_response code, "expected " + code.to_s + ", server response: " + response.body.to_s
    if (code.class == Symbol)
      # Not sure why this list isn't the right one: (has :ok instead).  Should fix once...
      Rack::Utils::SYMBOL_TO_STATUS_CODE[:success] = 200
      Rack::Utils::SYMBOL_TO_STATUS_CODE[:redirect] = 302
      code = Rack::Utils::SYMBOL_TO_STATUS_CODE[code]
    end

    return if (code == 302) # redirect, html body
    body = JSON.parse(response.body)
    assert_not_nil body["signature"], "no key_pair signature in reply"
    signature = Base64.strict_decode64(body["signature"])
    keys= body["user_device_keypair"].to_json
    assert_true verify_by_goji_master_pub_key(signature, keys), "user_device keys signature verified"
    key_pair=JSON.parse(keys)
    assert key_pair["id"] != nil, "got key_pair user_device_id [id]"
    assert key_pair["ude"] != nil, "got user_device Arxan private key [ude]"
    assert key_pair["udd"] != nil, "got user_device Arxan public key [udd]"
  end

  def get_keys_from_signed_response_body(body)
    return nil if !body["key_data"] && !body["signature"] && !body["key_info"]
    signature = Base64.strict_decode64(body["signature"])
    verified = verify_by_goji_master_pub_key(signature, body["key_data"].to_json)
    assert verified==true
    return body["key_data"], body["key_info"]
  end

  @@key_data_fields = [ :id, :lock_id, :user_id, :start_date, :end_date ]

  # GET /keys response
  def check_keys_response(key, code = :success, expected_msg = nil)
    assert_response code, "expected " + code.to_s + ", server response: " + response.body.to_s
    if (code.class == Symbol)
      # Not sure why this list isn't the right one: (has :ok instead).  Should fix once...
      Rack::Utils::SYMBOL_TO_STATUS_CODE[:success] = 200
      Rack::Utils::SYMBOL_TO_STATUS_CODE[:redirect] = 302
      code = Rack::Utils::SYMBOL_TO_STATUS_CODE[code]
    end
    return if (code == 302) # redirect, html body

    JSON.parse(response.body).each do |body|
      key_data, key_info = get_keys_from_signed_response_body(body)
      check_key_data(key, nil, body, nil, nil, true, nil)
    end
  end


  # XXX add expected_msg to all check_response(errorcode) calls!
  # Once that's done, expected_msg default can be :SUCCESS.
  def check_response(code = :success, expected_msg = nil, line = nil)
    line = line ? " [*_test:" + line.to_s + "]" : ""
    assert_response code, "expected " + code.to_s + ", server response: " + response.body.to_s + line
    if (code.class == Symbol)
      # Not sure why this list isn't the right one: (has :ok instead).  Should fix once...
      Rack::Utils::SYMBOL_TO_STATUS_CODE[:success] = 200
      Rack::Utils::SYMBOL_TO_STATUS_CODE[:redirect] = 302
      code = Rack::Utils::SYMBOL_TO_STATUS_CODE[code]
    end
    return if (code == 302) # redirect, html body

    body = JSON.parse(response.body)
    #Success payloads should contain one of these.
    assert (body[0] && body[0]["server_time"]) ||
           body["status"] == code ||
           body["status"] == "destroyed" ||
           body["server_time"] ||
           body["device_id"]  ||
           body["key_data"]  ||
           body["authtoken"], "success payload not one of the usual patterns" + line
    return if ! expected_msg

    if expected_msg.class == Symbol
      expected_msg = ApplicationController.MESSAGES[expected_msg]
      assert expected_msg != nil, "oops, your check_response passed a non-existant expected message symbol!" + line
    end

    if (code == 200)
      return assert body["message"] = expected_msg, "wrong message" + line
    end

    # Simple generic check against message template to see that we got
    # the right one - there will be at least 12 chars without a
    # substitution at either start or end in all our MESSAGES strings.
    # Or a whole string without formatting anywhere (when array of validation errors is stringified).
    len = 12
    ret_msg = body["error"]
    # Handle short expected strings (INVALID_PARAM)
    assert ret_msg.start_with?(expected_msg.first(len)) ||
           ret_msg.end_with?(expected_msg.last(len)) ||
           ret_msg.include?(expected_msg),
           "reply error message doesn't match:\"" + ret_msg + "\"!=\""+ expected_msg + "\"" + line
  end

  def check_success()
    check_response(:success, :SUCCESS)
  end

  def check_no_auto_key(lock, user_id)
    keys = Key.where(:lock_id => lock.id,
                     :user_id => user_id,
                     :auto_generated => true)
    assert_equal 0, keys.count, "check_no_auto_key: got no keys"
  end

  def check_no_lock_keys(lock, user_id)
    keys = Key.where(:lock_id => lock.id,
                     :user_id => user_id)
    assert_equal 0, keys.count, "check_no_lock_keys: got no keys"
  end

  def check_no_lock_events(lock, user_id)
    events = Event.where(:lock_id => lock.id,
                         :user_id => user_id)
    assert_equal 0, events.count, "check_no_lock_events: got no events"
  end

  def check_no_lock_notifications(lock, user_id)
    notifications = Notification.where(:lock_id => lock.id,
                                       :user_id => user_id)
    assert_equal 0, notifications.count, "check_no_lock_notifications: got no notifications"
  end

  def check_no_lock_data(lock, user_id)
    check_no_auto_key(lock, user_id)
    check_locks_user(lock, user_id, nil, false)
    check_no_lock_keys(lock, user_id)
    check_no_lock_events(lock, user_id)
    check_no_lock_notifications(lock, user_id)
  end

  # Checks that correct # devices are sent notifications, and
  # correct device endpoints via notification.push_result if present
  # (i.e. called from model test, not controller)
  def check_notification_devices(notification, user, num_devices, from_model = false)
    # Assume we don't have tests with endpoint_disabled_at or missing endpoint_arn, confirm that expected count is correct.
    destinations = user.active_devices.count
    assert_equal num_devices, destinations, "expected " + num_devices.to_s + " devices to be notified, only " +  destinations.to_s + " active devices exist"
    assert_equal num_devices, notification.devices_tried, "expected " + num_devices.to_s + " devices to be notified, only " + notification.devices_tried.to_s + " were attempted (AWS endpoint_disabled/arn missing)"
    assert_equal num_devices, notification.devices_sent, "expected " + num_devices.to_s + " devices to be notified, only " + notification.devices_sent.to_s + " were notified"
    attempts = notification.push_result
    if !attempts
      assert !from_model, "model notification test did not find push_result"
      return
    end
    assert_equal num_devices, attempts.length, "expected " + num_devices.to_s + " devices to be notified, only " + attempts.length.to_s + " were reported"
    # Since we're re-creating the device often, it's being enabled each time
    # If that changes, this is an alternative assert
    # assert_equal "EndpointDisabled", attempts.first.flatten[1] # Failure, but not our fault and shows we tried
    attempts.each do |notice|
      # Show that we got some sort of response back for AWS
      assert notice.keys.first.start_with?("arn:aws:sns"), "not a valid ARN detected"
      # XXX what else to check?  Get device list from user, and check:
      # assert_equal notice.keys.first, (some) device.endpoint_arn
      # Then remove extra check in notification_test.rb
    end
  end

  # Check that lock_data is now in the db
  def check_lock_db_by_id(lock_id, lock_data)
    lock = Lock.where(:id => lock_id)
    assert_equal 1, lock.count, "check_lock_db_by_id: wrong lock count"
    check_data(lock.first, lock_data)
  end

  # Compare DB results against the POST/PUT request data.
  # If PUT, caller has not refreshed model since putting.
  # (Some wasted overhead in POST case)
  #pre_record is set to nil, in case no previous record existed (:create)
  #and to not break other tests outside of lock calling check_data
  # Dates are iso8601(3) until we monkey patch datetime.to_json.
  # TBD: make this report all errors like check_reply
  # TBD: pass test description
  def check_data(model,          # not-yet-reloaded db model
                 ref,            # symbol-value hash of reference data
                 ignore = nil,  # array of symbol field names to ignore (even if in ref param)
                 approx_time = false, # fuzzy .now time compare
                 disallow = nil,  # array of symbol field names that must not be present (must be nil in model/db)  Arbitrarily overrides ref fields.
                 line = nil)
    pre_record = model.dup
    model.reload
    untouched_fields = model.class.accessible_attributes.to_a - ref.stringify_keys.keys
    line = line ? " [*_test:" + line.to_s + "]" : ""

    check_valid_field = lambda do |ref|
      field = ref[0]

      # wierd - db fields can be accessed as model[field],
      # attr_accessor fields can't. So must distinguish.
      # But note this only works when checking the model used to create,
      # since attr_accessor fields are not persisted.
      # There might be a less hacky way...
      dbfield = model.instance_variables.include?(("@" + field.to_s).to_sym) ?
      model.send(field) : model[field]

      if (disallow && disallow.include?(field))
        if (@@trace)
          print "check_data checking field is nil: " + model.class.to_s + "." + field.to_s + ": " + dbfield.to_s + line + "\n"
        end
        return dbfield == nil ?
          nil :
          { expected: nil, actual: dbfield }
      end

      if (!ignore || !ignore.include?(field))

        ref_val = ref[1]
        if (@@trace)
          print "check_data checking: " + model.class.to_s + "." + field.to_s + ": " + dbfield.to_s + "="  + ref_val.to_s + line + "\n"
        end
        return ((dbfield.class == ActiveSupport::TimeWithZone) ?
        # Not checking format here, just value.
          (approx_time ?
           # XXX Tighten this back to 1, by passing request time into check_key_event
           fuzzy_compare_datetime(DateTime.parse(ref_val), dbfield, 6) :
           equal_normalize_iso8601(ref_val, dbfield.utc.iso8601(3))) :
          (ref_val.to_s == dbfield.to_s)) ?
            nil :
            { expected: ref_val, actual: dbfield }
      end
      nil
    end

    assert_each_log_results(ref, true, "have wrong values in database" + line, &check_valid_field)

    #makes sure that other database fields are untouched
    if pre_record
      untouched_fields.each do |field|
=begin
        # Turn this on to see what fields might never be checked for being touchable across all tests.
        # Need a way to filter out dont-care/obsolete fields.
        if (@@trace)
          print "check_data checking field was untouched: " + model.class.to_s + "." + field + "\n"
        end
=end
        assert_equal pre_record.read_attribute(field), model.read_attribute(field), ("*** " + field + line + ":")
      end
    end
  end

  # Check both db and json reply
  # Note that GET /keys payload has extra dummy fields.
  # ref_data nil when checking GET /keys.
  def check_key_data(record, ref_data, resp_data,
                     exclude = nil,  # exclude from db check.
                     allow = nil, augment = true, # extra GET /keys items
                     disallow = nil, line = nil)
    # XXX validate internally-generated db fields.
    must_exclude = [:time_constraints, :admin]
    exclude = exclude ? exclude + must_exclude : must_exclude
    # Allow skipping check_data.
    if (record && ref_data)
      check_data(record, ref_data, exclude, nil, disallow, line)
    end
    # Allow skipping reply check.
    if !resp_data
      return
    end

    non_db = [ "bluetooth_address",
               "first_name", "last_name", "email",
               "user_display_name", "time_constraints", "lock_time_zone" ]
    server_time = augment ? [:server_time] : []
    # reply splits into two sub-hashes.
    key_data = resp_data["key_data"]
    key_info = resp_data["key_info"]
    assert_not_nil key_data, "key_data present"
    assert_not_nil key_info, "key_info present"
    check_reply(json: key_data, model: record,
                elsewhere: non_db, allow: @@key_data_fields,
                exclude: ["seq_no"], augment: nil)
    # id present due to global rule in key_info, but not required
    check_reply(json: key_info, model: record,
                elsewhere: non_db, exclude: @@key_data_fields,
                augment: server_time)
    assert_equal record.lock.bluetooth_address,  key_info["bluetooth_address"], "bluetooth_address"
    assert_equal record.lock.name,               key_info["name"], "name"
    assert date_match(record.last_access, key_info["last_access"]), "last_access"
    assert_equal record.user.account.first_name, key_info["first_name"], "first_name"
    assert_equal record.user.account.last_name,  key_info["last_name"], "last_name"
    assert_equal record.user.account.email,      key_info["email"], "email"
    assert_equal record.user.display_name,       key_info["user_display_name"], "user_display_name"
    assert_equal record.lock.time_zone,          key_info["lock_time_zone"], "time_zone"
    # XXX admin

    check_key_time_constraints(record, key_data, key_info)

    #/locks doesn't include the same fields as /keys, so ignore these checks for GET /locks
    if (!ref_data && augment)
      # get /keys has extra fields
      admin          = key_info['admin']
      auto_generated = key_info['auto_generated']
      lock_owner_key = key_info['lock_owner_key']
      assert_boolean_equal admin || lock_owner_key, auto_generated, "auto_generated equals admin || lock_owner_key"
      assert_boolean_equal record.lock.user_id == record.user_id, lock_owner_key, "lock_owner_key equals record.lock.user_id == record.user_id"
      lu = LocksUser.where(:lock_id => record.lock.id,
                           :user_id => record.user_id)
      assert_boolean_equal (lu.count > 0) && lu.first.admin, admin, "admin matches LocksUser"
      # XXX lock_owner_display_name, sharer_display_name
    end
  end

  def check_event_data(record, ref_data)
    check_reply(json: ref_data, model: record)

    record.reload

    assert_equal record.picture.try(:data).try(:expiring_url, GojiServer.config.s3_url_expire), ref_data["picture_url"]
    assert_equal record.lock.name, ref_data['lock_name']
    if record.user
      assert_equal record.user.display_name, ref_data['user_display_name']
    end
    if record.key
      assert_equal record.key.user.display_name, ref_data['key_user_display_name']
    end
    if record.admin
      assert_equal record.admin.display_name, ref_data['admin_display_name']
    end
  end

# Returns true if date string is valid payload string and
# is "close" to now ("close" is ultimately a security check, within
# lock/server time accuracy)
# unused
  def check_new_date(date, field_name)
    dt = parse_datetime_string(date)
    if dt == nil
      return false
    end
    check_now_date(dt, field_name)
  end

  # Ditto, from date object
  def check_now_date(dt, field_name = "date", now = DateTime.now)
    now = now.utc
    assert fuzzy_compare_datetime(dt, now, 1),  # 1 for testing, not real-world.
                                  field_name + " and now are not equal: " + normalize_date(dt) + ", " + normalize_date(now)
  end

  def assert_equal_fuzzy_datetime(dt1, dt2, allowed_delta)
    assert fuzzy_compare_datetime(dt1, dt2, allowed_delta), "dt1 and dt2 are not equal: " + normalize_date(dt1) + ", " + normalize_date(dt2)
  end
  def fuzzy_compare_datetime(dt1, dt2, allowed_delta)
    fuzzy_compare_int(dt1.to_i, dt2.to_i, allowed_delta)
  end
  def fuzzy_compare_int(i1, i2, allowed_delta)
    (i1 - i2).abs <= allowed_delta
  end

  # unused
  def assert_datetime(date)
    assert_not_nil parse_datetime_string(date)
  end
  def parse_datetime_string(date)
    init_timeliness
    Timeliness.parse(date, zone: :utc)
  end

  def init_timeliness
    if (!@@Timeliness_init)
      # Delete all other formats so only the desired UTC one parses.
      Timeliness.remove_formats(:date, *Timeliness::Definitions.date_formats)
      Timeliness.remove_formats(:time, *Timeliness::Definitions.time_formats)
      Timeliness.remove_formats(:datetime, *Timeliness::Definitions.datetime_formats)
      # definitions.rb needs to be fixed:
      # number of fraction digits is unlimited in spec, we need 9, not 6
      Timeliness::Definitions.format_tokens['u'] = [ '\d{1,9}', :usec ]
      # Simply missing:
      Timeliness.add_formats(:datetime, "yyyy-mm-ddThh:nn:ss.uZ")
      @@Timeliness_init = true
    end
  end

  def assert_equal_iso8601(dt1, dt2)
    # code is inconsistent about Z v.s. +00:00, both are legal
    assert equal_normalize_iso8601(dt1, dt2)
  end
  def equal_normalize_iso8601(dt1, dt2)
    normalize_iso8601(dt1) == normalize_iso8601(dt2)
  end
  def normalize_iso8601(dt)
    # Not sure how we got UTC from dbfield.utc.iso8601(3) on Jenkins.
    [" UTC +00:00", "+00:00", "+0000", "+00"].each do |zero|
      if dt.end_with?(zero)
        return dt.slice(0, dt.length - zero.length) + "Z"
      end
    end
    return dt
  end
  def normalize_date(dt)
    dt ? normalize_iso8601(dt.iso8601) : ""
  end

  def log_json(response, type)
    # Optionally capture the payloads in logs for the API spec
    if (@@do_log_json)
      puts
      puts "request type:" + type
      puts JSON.pretty_generate(JSON.parse(response.body))
    end
  end

  def log_notification(nt)
    if (@@do_log_notifications && nt != nil)
      puts "\n"
      event = nt.event
      key = nt.key
      target_user       = event.admin_user_id ? User.find_by_id(event.admin_user_id) : key.try(:user)
      target_user_name =  target_user ?  target_user.display_name : ""
      # EventType,Lock,LockOwner,SubjectUser,message
      puts event.event_type +
        "," + event.lock.name +
        "," + event.lock.user.name +
        "," + target_user_name +
        "," + (nt.admin ? " (to admin)" : "") +
        "," + nt.message
    end
  end

  # valid_days_mask needs to be checked, extra @key.id, key_id,
  # created_at, update_at fields filtered out.
  def check_key_time_constraints(key, key_data, key_info)
    if (@@trace)
      print "checking time_constraint\n"
    end
    ref = key.time_constraints.first
    return if (!ref)
    kinfo_time = key_info["time_constraints"].first
    kdata_time = key_data["time_constraints"].first

    assert_equal ref.id, kinfo_time["id"], "time_constraints [id]"
    assert_equal ref.monday, kinfo_time["monday"], "*** monday:"
    assert_equal ref.tuesday, kinfo_time["tuesday"], "*** tuesday"
    assert_equal ref.wednesday, kinfo_time["wednesday"], "*** wednesday"
    assert_equal ref.thursday, kinfo_time["thursday"], "*** thursday"
    assert_equal ref.friday, kinfo_time["friday"], "*** friday"
    assert_equal ref.saturday, kinfo_time["saturday"], "*** saturday:"
    assert_equal ref.sunday, kinfo_time["sunday"], "*** sunday:"
    assert_equal ref.start_offset, kdata_time["start_offset"], "** start_offset"
    assert_equal ref.end_offset, kdata_time["end_offset"], "** end_offset"

    assert_equal key.start_date, key_data["start_date"], "*** start_date"
    assert_equal key.end_date, key_data["end_date"], "*** end_date"
    days_mask = TimeConstraint.get_days_bitmask(ref)
    assert_equal days_mask, kdata_time["valid_days_mask"], "*** valid_data_mask"
  end

  # validate time_constraints reply against db
  def check_time_constraints_payload(record, resp_data)
    # We never return time_constraints = null
    assert_equal record.time_constraints.count, resp_data["time_constraints"].count
    for i in 0..record.time_constraints.count-1 do
      #puts record.time_constraints[i].to_json
      #puts resp_data["time_constraints"][i]
      check_payload(resp_data["time_constraints"][i],
                    record.time_constraints[i],
                    [:key_id, :start_time, :end_time, :start_offset, :end_offset], nil, nil)
    end
  end

  def check_time(time_field)
    init_timeliness
    Timeliness.parse(time_field) != nil
  end

  # Check the reply payload against the database.
  # Note that by default this only checks payload fields that come
  # from accessable model atrribute fields, plus server_time.
  # All override arguments are arrays with symbol indices.
  # json is string indices.
  # Old signature, replace with named args check_reply().
  # TBD: pass test description
  def check_payload(json, model,
                    exclude = nil, # fields that should not be present
                    allow = nil,   # fields to check, overriding model accessible_attributes.  Note: silently ignored if not an accessabie field - use augment!
                    augment = [:server_time])  # non-DB fields to check for existence and format
    return check_reply(json: json, model: model, exclude: exclude,
                       allow: allow, augment: augment)
  end

  def check_reply(json: nil, model: nil,
                  exclude: nil, # fields that should not be present
                  allow: nil,   # fields to check, overriding model accessible_attributes.  Note: silently ignored if not an accessabie field - use augment!
                  augment: [:server_time],  # non-DB fields to check for existence and format
                  elsewhere: nil) # fields present but checked elsewhere
    @always = [ "id", "seq_no" ]  # see get_payload_hash
    @never = [ :created_at, :updated_at,
               :pin_code, #deprecated, will remove
               :image_file_name, # not ever in attr_accessible, so drop?
               :image_content_type,
               :notify_locked,   #notification groups TBD
               :notify_unlocked,
               :notify_denied,
               :image_file_size,
               :image_updated_at ]
    if allow
      allow = allow.map &:to_s
    else
      # Note: this is string indices, hence convert above
      allow = model.class.accessible_attributes.to_a
    end
    allow += @always
    disallow = exclude
    exclude = exclude ? exclude + @never : @never
    exclude.each do |name|
      allow.delete(name.to_s)
    end

    # Field is symbol.
    check_absent_field = lambda do |field|
      field = field.to_s
      if (@@trace)
        print field + " is absent?" + "\n"
      end
      json[field] == nil
    end

    # Validate model/db data.
    # Returns array with expected+actual values to print on invalid, nil if valid.
    # Use a lambda calling this method with assert_each_log_results.
    # Field is string.
    check_valid_field = lambda do |field|
      if model.has_attribute?(field)
        ref_val = json[field]
        dbfield = model.read_attribute(field)
        if (@@trace)
          print "check_reply checking: " + field.to_s + ": " + dbfield.to_s + "="  + ref_val.to_s + "\n"
        end
        # Default datetime.to_json truncates to milliseconds, if we
        # want more, we need to monkey patch datetime.to_json.
        return (model.class.columns_hash[field].type == :datetime ?
               date_match(dbfield, ref_val) : (dbfield == ref_val)) ?
        nil :
          { expected: ref_val, actual: dbfield }
      else
        # non-DB fields, not put in payload by get_payload_hash
        if (@@trace)
          print "check_reply skipping non-db field: " + field.to_s + "\n"
        end
        nil
      end
    end

    # Field is symbol.
    check_nondb_field = lambda do |field|
      # Just check non-DB fields for existence
      json[field.to_s] != nil
    end

    # Field is string
    check_time_format = lambda do |field|
      if model.has_attribute?(field) &&
         model.class.columns_hash[field].type == :datetime &&
         json[field] != nil
        check_time(json[field])
      else
        true
      end
    end

    # Field is symbol
    check_augment_time_format = lambda do |field|
      field = field.to_s
      field.end_with?("_time") ? check_time(json[field]) : true
    end

    # Note that we only see one of these two classes of checks should both have failures.
    # XXX Why is assert_each processing each item twice???
    assert_each(allow, "are not proper UTC time format in reply payload", &check_time_format)
    assert_each_log_results(allow, false, "have wrong values in reply payload", &check_valid_field)
    assert_each(disallow, "should not be in reply payload", &check_absent_field)
    assert_each(augment, "have nil values in reply payload", &check_nondb_field)
    assert_each(augment, "are not proper UTC time format in reply payload", &check_augment_time_format)

    # Make sure all returned fields were checked.
    if @@trace
      if augment
        allow += augment.map &:to_s
      end
      json.each do |key, value|
        if !allow.include?(key) && (!elsewhere || !elsewhere.include?(key))
          print "check_reply: " + key + ": was not checked!" + "\n"
        end
      end
    end

  end

  def date_match(dbfield, val)
    (!dbfield && !val) || (dbfield.utc.iso8601(3) == val)
  end

end # class ActiveSupport::TestCase

module MiniTest::Assertions

  #Asserts that each element passes the test
  # Inputs:
  #   enumerable - The object to iterate over (ex an array)
  #   msg - Custom message to include in assertion failure
  #   test - A block that each element will be tested against
  def assert_each(enumerable, msg = nil, &test)
    if !enumerable
      return
    end
    failed_elements = Array.new
    enumerable.each do |e|
      failed_elements << e unless test.call(e)
    end

    msg = " #{failed_elements} #{msg}"
    raise( MiniTest::Assertion, msg ) unless failed_elements.empty?
  end

  # Check fields like above, but log actual and expected values.
  # Use with check_valid_db_field as the test lambda.
  def assert_each_log_results(enumerable, e_is_hash, msg = nil, &test)
    if !enumerable
      return nil
    end
    failed_elements = Array.new
    failed_expected = Array.new
    failed_actual = Array.new
    enumerable.each do |e|
      results = test.call(e)
      if (results != nil)
        failed_elements << (e_is_hash ? e[0] : e)
        failed_expected << results[:expected]
        failed_actual   << results[:actual]
      end
    end

    msg = "invalid:  #{failed_elements} #{msg}:\nexpected: #{failed_expected}\n  actual: #{failed_actual}"
    raise( MiniTest::Assertion, msg ) unless failed_elements.empty?
  end

  # Two booleans are effectively equal if one is false and one is nil
  def assert_boolean_equal(a, b, msg = nil)
    assert_equal !a, !b, msg
  end

  def assert_false(bool, msg)
    assert_equal false, bool, msg
  end

  def assert_true(bool, msg)
    assert_equal true, bool, msg
  end

end # module MiniTest::Assertions

module LastN
  def last(n)
    self[-n,n]
  end
  def first(n)
    self[0,n]
  end
end

class String
  include LastN
end

class Float
  def ceil_frac(digits = 0)
   multiplier = 10 ** digits
   ((self * multiplier).ceil).to_f/multiplier.to_f
  end
  def floor_frac(digits = 0)
   multiplier = 10 ** digits
   ((self * multiplier).floor).to_f/multiplier.to_f
  end
end
