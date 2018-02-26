require "test_helper"

class AuthtokenControllerTest < ActionController::TestCase

  describe AuthtokenController do

    subject { AuthtokenController }

    # XXX passing user/pass in params is deprectated for security, will be
    # removed once apps catch up.  Then these tests must be converted
    # to basic auth (using make_auth()).

    before do
      DatabaseCleaner.start
      @user, @device, @user_device = make_user
      confirm_user_device()
      get(:show, email: @user.account.email, password: 'aba456',
          device_id: @device.id)
      @json = JSON.parse(response.body)
      @non_device_fields = [ :email, :password, :uuid]
      @newtok = '54ce3cbfb716c0eb61adc2d6da1f2781e8b74d39b49c1e521108db9109b1be35'
    end

    after do 
      DatabaseCleaner.clean
    end

    it "should get a response from the show page" do
      check_response
      assert @json
    end

    it "should get missing parameter response without correct params" do
      get(:show)
      check_response(422, :MISSING_PARAM)
    end

    it "should get missing parameter response without password param" do
      get(:show, email: @user.account.email)
      check_response(422, :MISSING_PARAM)
    end

    def confirm_user_device()
      @user_device.confirmed_at = DateTime.now.utc.iso8601(9)
      @user_device.save
    end

    def unconfirm_user_device
      @user_device.confirmed_at = nil
      @user_device.save
    end

    def make_auth(user, pass)
      # Oddly, this worked when "Basic " was missing!  Is it a default in spec/Rails code?
      request.headers['Authorization'] = make_auth_string(user, pass)
    end

    def make_header(name, value)
      request.headers[ApplicationController::make_header_name(name)] = value
    end

    def is_logged_out(user_device = @user_device)
      assert_nil user_device.authenticated_at, "authenticated_at not cleared"   
      assert_nil user_device.authentication_token, "authentication_token not cleared"
    end

    def logout(user_device = @user_device)
      user_device.logout
      is_logged_out(user_device)
    end

    def check_auth_payload(has_keypair = false, user = @user, user_device = @user_device)
      user_device.reload
      # Also check db while we are at it.
      check_now_date(user_device.authenticated_at, "authenticated_at")

      @json = JSON.parse(response.body)
      expected = {
        "authtoken" => user_device.authentication_token,
        "user_id"   => user.id,
        "user_device_id"   => user_device.id,
        "device_id"   => @device.id,
      }
      if has_keypair
        # Slight hole: allows extraneous non-keypair fields to be present.
        diff = expected.to_a - @json.to_a
        assert diff.empty?, "incorrect core auth reply payload: " + diff.to_s
        check_user_device_arxan_keypair
      else
        assert_equal(expected, @json)
      end
    end

    # Basic auth returns 401 on user/pass empty
    it "should get return 401 error with only user in header" do
      make_auth(@user.account.email, "")
      get(:show, nil)
      check_response :unauthorized, :UNAUTHORIZED
    end

    it "should get missing parameter response with ua_token and no device_id/type" do
      get(:show, email: @user.account.email, password: 'aba456', ua_token: "foo")
      check_response(422, :MISSING_PARAM)
    end

    it "should get a valid json object back with authtoken, id's, and Arxan keypair" do
      # sending keys first time on keys_sent_at may go away.
      return if @@no_keypairs
    end

    it "should get a valid json object back with authtoken and existing device id's from ua_token and user/pass params" do
      logout
      get(:show, email: @user.account.email, password: 'aba456',
          device_type: "iosdevelopment",
          device_id: @device.id,
          ua_token: @device.ua_token)
      check_auth_payload
      log_json(response, "Authtoken GET, no keypair")
    end

    it "should get a valid json object back with authtoken and existing device id's from ua_token in query, user/pass in header" do
      logout
      make_auth(@user.account.email, "aba456")
      get(:show,
          device_type: "iosdevelopment",
          device_id: @device.id,
          ua_token: @device.ua_token)
      check_auth_payload
    end

    it "should get a valid json object back with authtoken and existing device id's from ua_token and user/pass in header" do
      logout
      make_auth(@user.account.email, "aba456")
      make_header(:device_type, "iosdevelopment")
      make_header(:ua_token, @device.ua_token)
      make_header(:device_id, @device.id)
      get(:show)
      check_auth_payload
    end

    it "should get a valid json object back with authtoken and existing device id's from device_id and user/pass in header" do
      logout
      make_auth(@user.account.email, "aba456")
      make_header(:device_id, @device.id)
      get(:show)
      check_auth_payload
    end

    it "should logout existing user from device when logging in" do
      #device2 == @device!
      user2, device2, user_device2 = make_user('glenn2@example.com')
      logout(user_device2)
      make_auth(user2.account.email, "aba456")
      make_header(:device_id, @device.id)
      get(:show)
      check_auth_payload(ENV["NO_KEYPAIRS"] != "true", user2, user_device2)
      @user_device.reload
      is_logged_out(@user_device)
    end

    it "should report unconfirmed new device with device_id and user/pass in header" do
      logout
      unconfirm_user_device
      make_auth(@user.account.email, "aba456")
      make_header(:device_id, @device.id)
      get(:show)
      check_response 409
    end

    it "should restart confirmation if unconfirmed, with no device_id/ua_token and user/pass in header" do
      logout
      unconfirm_user_device
      make_auth(@user.account.email, "aba456")
      assert_difference [ 'ActionMailer::Base.deliveries.size'], @@mail_count do
        assert_difference [ "Device.count", "UserDevice.count" ], 1 do
          get(:show)
        end
      end
      check_device_response()
    end

    it "should restart confirmation if unconfirmed, with no device_id and ua_token and user/pass in header {app uninstall/user data cleared}" do
      unconfirm_user_device
      make_auth(@user.account.email, "aba456")
      make_header(:device_type, "iosdevelopment")
      make_header(:ua_token, @device.ua_token)
      assert_difference [ 'ActionMailer::Base.deliveries.size'], @@mail_count do
        assert_difference [ "Device.count", "UserDevice.count" ], 0 do
          get(:show)
        end
      end
      check_device_response()
    end

    it "should not restart confirmation if confirmed, with no device_id and ua_token and user/pass in header {app uninstall/user data cleared}" do
      logout
      make_auth(@user.account.email, "aba456")
      make_header(:device_type, "iosdevelopment")
      make_header(:ua_token, @device.ua_token)
      assert_difference [ 'ActionMailer::Base.deliveries.size', 
                          "Device.count", "UserDevice.count" ], 0 do
        get(:show)
      end
      check_auth_payload
    end

    it "should start new device confirmation with authtoken and new device id's from ua_token and user/pass in header, with wrong device_type" do
      make_auth(@user.account.email, "aba456")
      make_header(:device_type, "android")
      make_header(:ua_token, @device.ua_token)
      assert_difference [ 'ActionMailer::Base.deliveries.size'], @@mail_count do
        assert_difference [ "Device.count", "UserDevice.count" ], 1 do
          get(:show)
        end
      end
      check_device_response()
    end

    it "should update ua_token" do
      logout
      get(:show, email: @user.account.email, password: 'aba456', 
          device_id: @device.id,
          device_type: "iosdevelopment",
          ua_token: @newtok)
      check_auth_payload
      @device.reload
      assert_equal @newtok, @device.ua_token, "token updated"
    end

    it "should update device_type" do
      logout
      get(:show, email: @user.account.email, password: 'aba456', 
          device_id: @device.id,
          device_type: "iOS",
          ua_token: @device.ua_token)
      check_auth_payload
      @device.reload
      assert_equal "iOS", @device.device_type, "device_type updated"
    end

    # Note: with neither ua_token nor device_type, it defaults to iOS,
    # because of the DB default, but we don't care.
    # Apps always supply device_type anyway.
    it "should fail to create device if ua_token but no device_type" do
      logout
      assert_difference [ "Device.count", "UserDevice.count" ], 0 do
        get(:show, email: @user.account.email, password: 'aba456',
            ua_token: @device.ua_token)
      end
      @json = JSON.parse(response.body)
      check_response 422
    end

    it "should error with ua_token and invalid device_type" do
      logout
      get(:show, email: @user.account.email, password: 'aba456', 
          device_id: @device.id,
          device_type: "ios",
          ua_token: @device.ua_token)
      check_response 422, :INVALID_PARAM
    end

    it "should not create a device with with invalid device type" do
      logout
      get(:show, email: @user.account.email, password: 'aba456', 
          :device_type => "blah")
      @json2 = JSON.parse(response.body)
      check_response 422, :INVALID_PARAM
    end

    it "should throw a 422 error if ua_token exceeds 255 chars, on update" do
      logout
      ua_token2 = '64ce3cbfb716c0eb61adc2d6da1f2781e8b74d39b49c1e521108db9109b1be3564ce3cbfb716c0eb61adc2d6da1f2781e8b74d39b49c1e521108db9109b1be3564ce3cbfb716c0eb61adc2d6da1f2781e8b74d39b49c1e521108db9109b1be3564ce3cbfb716c0eb61adc2d6da1f2781e8b74d39b49c1e521108db9109b1be3564ce3cbfb716c0eb61adc2d6da1f2781e8b74d39b49c1e521108db9109b1be3564ce3cbfb716c0eb61adc2d6da1f2781e8b74d39b49c1e521108db9109b1be35'
      get(:show, email: @user.account.email, password: 'aba456',
          device_id: @device.id,
          device_type: "iosdevelopment",
          ua_token: ua_token2)
      check_response 422
    end

    it "should allow device creation without ua_token" do
      logout
      assert_difference ["Device.count"], 1 do
        user2, device2, user_device2  = make_user('glenn2@example.com')
        get(:show, email: user2.account.email, password: 'aba456',  device_type: "android")
        check_response
        device = Device.all.order('created_at ASC').last
        assert_equal device.device_type, "android"
      end
    end

    # Same ua_token and different device_type is theoretically possible:
    # id collision between android and ios.  Handle it.
    it "should create new device with same ua_token and different device_type" do
      auth_no_device("new", "new", __LINE__, ua_token: @device.ua_token)
    end

    def auth_no_device(new_device, new_user_device, line, addl_params = {})
      get_data = {
        email: @user.account.email, password: 'aba456', 
        # Changing device_type not supported.
        device_type: "iOS",
        # Test value updates
        device_model: "newdm" + new_user_device.to_s,
        os_version: "newov"   + new_user_device.to_s,
        app_version: "newav"  + new_user_device.to_s,
        # I wish there was a way to inject request.uuid in ActionController::TestRequest
        uuid: "90bc960e-0888-4a6a-88c2-913335cb3418",
      }.merge(addl_params)
      assert_difference [ 'ActionMailer::Base.deliveries.size'], @@mail_count do
        assert_difference [ "Notification.count" ], 1 do
          assert_difference [ "Device.count" ], new_device ? 1 : 0 do
            assert_difference [ "UserDevice.count" ], new_user_device ? 1 : 0 do
              get(:show, get_data)
            end
          end
        end
      end
      device = check_device_response()
      # device_id in request, id in db
      if get_data[:device_id]
        get_data[:id] = get_data[:device_id]
        get_data[:device_id] = nil
      end
      check_data(device, get_data, @non_device_fields, false, nil, line)
    end

    def check_device_response()
      check_response
      device = Device.all.order('created_at ASC').last
      @json = JSON.parse(response.body)
      assert_equal({
                     "device_id"   => device.id,
                   }, @json)
      return device
    end

    def check_device_confirmation(user = @user, num_devices = 1)
      nf = Notification.all.order('created_at ASC').last
      assert_equal EventType::USER_DEVICE_CONFIRMED, nf.event.event_type, "event type"
      assert_match "A new device has tried to access your Goji account.", nf.message, "notification message"
      check_notification_devices(nf, user, num_devices)

      mail = ActionMailer::Base.deliveries.last
      # XXX Check address and subject line for other emails same as below!
      if mail
        assert_match /http:\/\/localhost:3000\/store\/device_confirmation\//, mail.body.to_s, "mail body"
        assert_match user.account.email, mail.to[0], "mail email"
        assert_match Mailer.subjects(:user_device_confirmed), mail.subject, "mail subject"
        assert_match /You have requested addition of a new mobile device to your Goji Smart lock account/, mail.body.to_s, "mail body"
      end
    end

    it "should respond with device_id only and start/restart device confirmation, if no device of this type and no ua_token" do
      auth_no_device("new", "new", __LINE__)
      log_json(response, "Authtoken GET, new device")
      check_device_confirmation()
      # confirmation resend request:
      # Should still not auth, and restart confirmation sequence when 
      # no device is supplied but device+user_device exists.
      auth_no_device(false, false, __LINE__)
      log_json(response, "Authtoken GET, resend device confirmation")
      check_device_confirmation()
     end

    it "should respond with device_id only and start device confirmation, if no device of this type and ua_token" do
      auth_no_device("new", "new", __LINE__, ua_token: @newtok)
      check_device_confirmation()
      auth_no_device(false, false, __LINE__, ua_token: @newtok)
      check_device_confirmation()
    end

    it "should start/restart device confirmation, if user already has two registered devices and new device already identified, e.g. registered to another user" do
      # Two users, confirmed on other device
      user2, device, user_device = make_user(email = 'person3@example.com', password = 'aba456')
      second_device = make_confirmed_device(user2, '54ce3cbfb716c0eb61adc2d6da1f2781e8b74d39b49c1e521108db9109b1ba22')
      new_device = make_primitive_device(@newtok)
      params = { device_id: new_device.id,
                 email: user2.account.email,
                 ua_token: @newtok }
      auth_no_device(false, "new", __LINE__, params)
      check_device_confirmation(user2, 2)
      params[:device_id] = nil
      auth_no_device(false, false, __LINE__, params)
      check_device_confirmation(user2, 2)
    end

    it "should start/restart device confirmation, if user already has a registered device and device lacking ua_token already identified" do
      # Two users, confirmed on other device
      user2, device, user_device = make_user(email = 'person3@example.com', password = 'aba456')
      new_device = make_primitive_device(nil)
      params = { device_id: new_device.id,
                 email: user2.account.email }
      auth_no_device(false, "new", __LINE__, params)
      check_device_confirmation(user2)
      params[:device_id] = nil
      auth_no_device(false, false, __LINE__, params)
      check_device_confirmation(user2)
    end

    it "should not send user_device Arxan keypair for unconfirmed user_device" do
      unconfirm_user_device
      get(:show, email: @user.account.email, password: 'aba456',
          device_type: "iosdevelopment",
          ua_token: @device.ua_token,
          need_keypair: "true",
          )
      body = JSON.parse(response.body)
      assert_nil body["signature"], "should not get signature"
      assert_nil body["user_device_keypair"], "should not get keypair"
    end

    it "should be different authtokens when the same confirmed user_device signin two times" do
      user_device = @user_device
      user_device.confirmed_at = DateTime.now.utc.iso8601(9)
      user_device.keys_sent_at = DateTime.now.utc.iso8601(9)
      authtoken = "xyz"
      user_device.authentication_token = authtoken
      user_device.save
      assert_difference "UserDevice.count", 0 do
        get(:show, email: @user.account.email, password: 'aba456', device_type: "iosdevelopment", device_id: @device.id)
        json1 = JSON.parse(response.body)
        get(:show, email: @user.account.email, password: 'aba456', device_type: "iosdevelopment", device_id: @device.id)
        json2 = JSON.parse(response.body)
        assert_not_equal json1["authtoken"], json2["authtoken"], authtoken
        assert_equal json1["user_id"], json2["user_id"]
        assert_equal json1["user_device_id"], json2["user_device_id"]
        assert_equal json1["device_id"], json2["device_id"]
      end
    end

    it "should resend user_device keypair if flag need_keypair is true for confirmed user_device" do
      logout
      return if @@no_keypairs
      user2, device, user_device = make_user
      lock2 = make_lock(user2)
      key  = make_key(lock2, @user)
      lock2.new_credentials = false
      @user_device.keys_sent_at = DateTime.now.utc.iso8601(9)
      @user_device.save
      get(:show, email: @user.account.email, password: 'aba456', device_type: "iosdevelopment",
            device_id: @device.id, need_keypair: "true")
      log_json(response, "Authtoken GET need_keypair")
      check_auth_payload("has_keypair")
      # Make sure keypair will also get sent to all locks for this user's keys.
      lock2.reload
      assert_true lock2.new_credentials, "lock.credentials_changed has been set"
    end

    it "should return 401 error if password isn't valid" do
      get(:show, email: @user.account.email, password: 'aba46', device_id: @device.id)
      check_response :unauthorized, :UNAUTHORIZED
    end

    it "should return 401 error if password isn't valid via header" do
      make_auth(@user.account.email, "foo")
      get(:show, device_id: @device.id)
      check_response :unauthorized, :UNAUTHORIZED
    end

    it "should return 401 error if an email doesn't exist" do
      make_auth("abc@example.com", "foo")
      get(:show, device_id: @device.id)
      check_response :unauthorized, :UNAUTHORIZED
    end

    it "should not be case sensistive on email addresses" do
      get(:show, email: @user.account.email.upcase, password: 'aba456', device_id: @device.id)
      check_response
    end

  end
end
