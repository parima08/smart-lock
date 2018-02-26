require "resolv"
require "test_helper"

class LocksControllerTest < ActionController::TestCase

  describe LocksController do

    subject { LocksController}

    describe "index/GET" do

      before do
        DatabaseCleaner.start
        @routes = Rails.application.routes
        @user, @device, @user_device = make_user
        @lock = make_lock(@user)
        @key  = make_key(@lock, @user)
        @event = Event.create(lock_id: @lock.id,
                              key_id: 0,
                              event_time: Time.now,
                              event_type: EventType::LOCK,
                              string_value: CommandResult::SUCCESS,
                              bolt_state: BoltState::LOCKED,
                              )
        @event = Event.create(lock_id: @lock.id,
                              key_id: @user.keys.where(lock_id: @lock.id).first.id,
                              event_time: Time.now,
                              event_type: EventType::UNLOCK,
                              string_value: CommandResult::HARDWARE_FAILURE,
                              bolt_state: BoltState::FAILED,
                              )
        @lock.reload
        get_index(@user)
        @json = JSON.parse(response.body)
        @lock_data =  lock_base_data(@lock, @user)
        @device = make_confirmed_device(@user)
      end

      after do
        DatabaseCleaner.clean
      end

      def check_lock_payload(json, model, model_keys)
        keys = json['keys']
        # Took signature out
        #signature = Base64.decode64(keys['signature'])
        #assert_true verify_by_goji_master_pub_key(signature, keys["key_data"].to_json), "signature matches'
        check_reply(json: json, model: model)
        assert_equal keys.count, model_keys.count
        for i in 0..keys.count-1
          check_key_data(model_keys[i], nil, keys[i], nil, true, nil, false)
        end
        last_access_event = model.events.where(:event_type => [EventType::LOCK, EventType::UNLOCK]).order('event_time DESC').first
        assert_equal json['event_type'], last_access_event.event_type
        assert_equal json['event_bolt_state'], last_access_event.bolt_state
        assert_equal json['event_string_value'], last_access_event.string_value
        assert_equal json['event_user_full_name'], last_access_event.user.try(:display_name)
        assert_equal json['event_time'], last_access_event.event_time.iso8601(3)
      end

      it "must respond with json" do
        assert @routes
        check_response
      end

      it "should get unauthorized response from index without authtoken" do
        header_auth
        get(:index)
        check_response :unauthorized
      end

      it "should return valid json" do
        assert @json # valid object
        log_json(response, "Locks GET")
      end

      it "should return a valid lock payload with keys" do
        check_lock_payload(@json[0], @lock, @lock.keys)
      end

      it "should not return decommissioned or uncommissioned locks" do
        @dead_lock = make_lock(@user)
        @dead_lock.decommission_date = DateTime.now.utc.iso8601(3)
        @dead_lock.save
        @doa_lock = make_lock(@user)
        @doa_lock.commission_date = nil
        @doa_lock.save
        get_index(@user)
        @json = JSON.parse(response.body)
        check_lock_payload(@json[0], @lock, @lock.keys)
        assert_equal 1, @json.count, "Should only return one active lock"
      end

      it "should return keys in correct order" do
        #admin 1- creates a new admin user with a key
        user1, device1, user_device1 = make_user(email = 'person1@example.com', password = 'aba456')
        make_admin_user(@lock, user1)
        key1  = make_key(@lock, user1)

        #guest 1 - creates a new user with a key
        user2, device2, user_device2= make_user(email = 'person2@example.com', password = 'aba456')
        key2  = make_guest_key(@lock, user2.account.email, user1)

        #admin 2- creates a new admin user with a key
        user3, device3, user_device3 = make_user(email = 'person3@example.com', password = 'aba456')
        make_admin_user(@lock, user3)
        key3  = make_key(@lock, user3)

        #guest 2- creates a new user with a key
        user4, device4, user_device4 = make_user(email = 'person4@example.com', password = 'aba456')
        key4  = make_guest_key(@lock, user4.account.email, user1)

        get_index(@user)
        @json2 = JSON.parse(response.body)

        # order should be - owner, second admin,  first admin, second guest, first guest
        check_lock_payload(@json2[0], @lock, [@key, key3, key1, key4, key2])
      end

      it "should return get locks with correct information and order" do
        #FOR LOCK 1 (OWNER)
        #admin 1- creates a new admin user with a key
        user1, device1, user_device1 = make_user(email = 'person1@example.com', password = 'aba456')
        make_admin_user(@lock, user1)
        key1  = make_key(@lock, user1)

        #guest 1 - creates a new user with a key
        user2,device2, user_device2 = make_user(email = 'person2@example.com', password = 'aba456')
        key2  = make_guest_key(@lock, user2.account.email, user1)

        #admin 2- creates a new admin user with a key
        @user3, @device3, @user_device3 = make_user(email = 'person3@example.com', password = 'aba456')
        make_admin_user(@lock, @user3)
        key3  = make_key(@lock, @user3)

        #guest 2- creates a new user with a key
        user4, device4, user_device4 = make_user(email = 'person4@example.com', password = 'aba456')
        key4  = make_guest_key(@lock, user4.account.email, user1)

        #FOR LOCK 2 (ADMIN)
        @lock2 = make_lock(user2)
        make_admin_user(@lock2, @user)
        @event = Event.create(lock_id: @lock2.id,
                              key_id: @user.keys.where(lock_id: @lock2.id).first.id,
                              event_time: Time.now,
                              event_type: EventType::LOCK,
                              string_value: CommandResult::SUCCESS,
                              bolt_state: BoltState::LOCKED,
                              )
        @user.reload
        @lock2.reload

        #FOR LOCK 4 (ADMIN)
        @lock4 = make_lock(user4)
        make_admin_user(@lock4, @user)
        get_index(@user)
        reply_json = JSON.parse(response.body)

        assert_equal 3, reply_json.count

        check_lock_payload(reply_json[0], @lock, [@key, key3, key1, key4, key2])
        # This test fails erratically, I'm pretty sure order among owned
        # and among admined locks is not a requirement and may be
        # db-variant.  XXX swap per lock id and validate
        #check_lock_payload(reply_json[1], @lock2, [admin_key])
        #check_lock_payload(reply_json[2], @lock4, [])
      end

      it "should not return revoked keys in the payload" do
        user1, device1, user_device1 = make_user(email = 'person1@example.com', password = 'aba456')
        make_admin_user(@lock, user1)
        key1  = make_key(@lock, user1)

        #guest 1 - creates a new user with a key
        user2,device2, user_device2 = make_user(email = 'person2@example.com', password = 'aba456')
        key2  = make_guest_key(@lock, user2.account.email, user1)

        #admin 2- creates a new admin user with a key
        @user3, device3, user_device3 = make_user(email = 'person3@example.com', password = 'aba456')
        make_admin_user(@lock, @user3)
        key3  = make_key(@lock, @user3)

        #guest 2- creates a new user with a key
        user4, device4, user_device4 = make_user(email = 'person4@example.com', password = 'aba456')
        key4  = make_guest_key(@lock, user4.account.email, user1)
        get_index(@user)
        reply1 = JSON.parse(response.body)
        check_lock_payload(reply1[0], @lock, [@key, key3, key1, key4, key2])

        key4.revoke!(key4.lock.user)

        #after being revoked, it should not be included /locks
        get_index(@user)
        reply2 = JSON.parse(response.body)
        check_lock_payload(reply2[0], @lock, [@key, key3, key1, key2])
      end

      it "shouldn't fail when a LOCK event doesn't have a key associated with it" do
        get_index(@user)
        reply_json = JSON.parse(response.body)
        assert_equal 1, reply_json.count
        check_lock_payload(reply_json[0], @lock, [@key])
      end

      it "should update the lock status and reset reboot and debug_log" do
        @lock.reboot = true
        @lock.debug_log = true
        @lock.save
        response = put(:sync, @lock_data)
        json = JSON.parse(response.body)
        @lock.reload
        check_response
        check_lock_version_data(@lock, @lock_data)
        assert_equal @lock.reported_wifi_status, LockCommState::LOCK_COMM_UP
        assert_equal false, @lock.reboot
        assert_equal false, @lock.debug_log
        assert_equal true, json["reboot"]
        assert_equal true, json["debug_log"]
      end

      it "should update wifi status and create a new event" do
        @lock.reported_wifi_status = LockCommState::LOCK_COMM_DOWN
        @lock.save
        response = nil
        assert_difference('Event.count', 1) do
          response = put(:sync, @lock_data)
        end
        json = JSON.parse(response.body)
        @lock.reload
        check_response
        check_lock_data(@lock, @lock_data)
        assert_equal @lock.reported_wifi_status, LockCommState::LOCK_COMM_UP
      end

      it "should not update wifi status and create a new event on lock update with lock down" do
        @lock.reported_wifi_status = LockCommState::LOCK_COMM_DOWN
        @lock.reported_wifi_time = DateTime.now
        @lock.save
        response = nil
        assert_difference('Event.count', 0) do
          send_auth(@user_device)
          @lock_data[:id] = @lock.id
          response = put(:update, @lock_data)
          Lock.check_active
        end
        json = JSON.parse(response.body)
        @lock.reload
        check_response
        check_lock_data(@lock, @lock_data)
        assert_equal @lock.reported_wifi_status, LockCommState::LOCK_COMM_DOWN
      end

      it "should update wifi status and create a new down event with lock up" do
        @lock.reported_wifi_status = LockCommState::LOCK_COMM_UP
        @lock.reported_wifi_time = DateTime.now
        @lock.save
        assert_difference('Event.count', 1) do
          # XXX use new time shifter instead to speed things up and eliminate this test_mode hack.
          sleep 2
          Lock.test_mode = true
          Lock.check_active
        end
        @lock.reload
        assert_equal @lock.reported_wifi_status, LockCommState::LOCK_COMM_DOWN
      end

      it "should update wifi status and create a new down event with lock up" do
        @lock.reported_wifi_status = LockCommState::LOCK_COMM_UP
        @lock.reported_wifi_time = DateTime.now
        @lock.save
        assert_difference('Event.count', 0) do
          # XXX use new time shifter instead to speed things up and eliminate this test_mode hack.
          Lock.test_mode = true
          Lock.check_active
        end
        @lock.reload
        assert_equal @lock.reported_wifi_status, LockCommState::LOCK_COMM_UP
      end

      it "should return 401 when trying to get individual lock information without authtoken" do
        header_auth
        get(:show, id: @lock.id)
        check_response :unauthorized, :UNAUTHORIZED
      end

      it "should return 401 when trying to get individual lock information with bad authtoken in header" do
        header_auth("212130234", nil)
        get(:show, id: @lock.id)
        check_response 401
      end

      it "should return 403 when trying to get individual lock information with wrong authtoken" do
        user2, device2, user_device2 = make_user(email = 'person3@example.com', password = 'aba456')
        send_auth(user_device2)
        get(:show, id: @lock.id)
        check_response 403
      end

      it "should return 403 when trying to get individual lock information with wrong authtoken in header" do
        user2, device2, user_device2 = make_user(email = 'person3@example.com', password = 'aba456')
        header_auth(user_device2.authentication_token, user_device2.id)
        get(:show, id: @lock.id)
        check_response 403
      end

      it "should return 404 for the requested lock with wrong lock_id" do
        send_auth(@user_device)
        get(:show, id: @lock.id + 1)
        check_response 404
      end

      it "should return 404 for the requested lock with wrong lock_id, auth in header" do
        send_auth(@user_device)
        get(:show, id: (@lock.id + 1))
        check_response 404
      end

      it "should get the lock payload for the requested lock" do
        send_auth(@user_device)
        get(:show, id: @lock.id)
        check_response
        reply_json = JSON.parse(response.body)
        check_payload(reply_json, @lock)
      end

      it "should get the lock payload for the requested lock, auth in header" do
        send_auth(@user_device)
        get(:show, id: @lock.id)
        check_response
        reply_json = JSON.parse(response.body)
        check_payload(reply_json, @lock)
      end
    end

    describe "create/POST" do
      subject { LocksController}

      before do
        DatabaseCleaner.start
        @routes = Rails.application.routes
        @user, @device, @user_device = make_user
        @lock = make_lock(@user)
        @key  = make_key(@lock, @user)
        get_index(@user)
        @json = JSON.parse(response.body).first
        @lock_commissioning_data = {
          user_id: @user.id,
          bluetooth_address: "BLUETOOTH-NAME1",
          lock_serial: Digest::MD5.hexdigest(@user.id.to_s + rand(100000).to_s),
          commission_date: DateTime.now.utc.iso8601(3),
          name: "my_lock",
          bolt_state: "unlocked",
          orientation: "left",
          internal_version: '0.5.5',
          external_version: '0.5.5abc',
          required_internal_version: ActiveSupport::TestCase.INTERNAL_VERSION,
          required_external_version: ActiveSupport::TestCase.EXTERNAL_VERSION,
        }
        @lock_data =  lock_base_data(@lock, @user)
      end

      after do
        DatabaseCleaner.clean
      end


      def check_commissioning(response)
        json = JSON.parse(response.body)
        lock = Lock.find(json["id"])
        check_payload(json, lock)
        #check_new_lock_payload json
        check_lock_db_by_id(json["id"], @lock_commissioning_data)
        # Check the key that gives the lock owner 24/7 access.
        # Moving away from using auto_generated.
        # key = check_key_by_id(json["id"], json["user_id"], json["user_id"])
        # assert_false key.auto_generated, "key should not have auto_generated set"
      end

      it "should return 404 because user_id is invalid" do
        @lock_commissioning_data[:user_id] = 666
        post(:create, @lock_commissioning_data)
        check_response 404, :MISSING_RECORD, __LINE__
      end

      it 'should register new lock and return lock id and time' do
        assert_difference 'Lock.count', 1 do
          @lock_commissioning_data[:commission_date] = nil
          post(:create, @lock_commissioning_data)
          # Incomplete commissioning record silently discarded
          post(:create, @lock_commissioning_data)
          check_response
        end
        log_json(response, "Locks POST")
        check_commissioning(response)
      end

      it 'should not allow re-use of active lock by same user' do
        #post(:create, @lock_commissioning_data)
        # Commissioning is not done until this step happens
        #put(:update, @lock_commissioning_data)

        # Default owner key not created until PUT
        #key  = make_key(lock, @user)

        @lock_commissioning_data[:user_id] = @lock.user_id
        @lock_commissioning_data[:lock_serial] = @lock.lock_serial

        assert_difference 'Lock.count', 1 do
          post(:create, @lock_commissioning_data)
          check_response
        end

        json = JSON.parse(response.body)
        assert_not_equal @lock.id, json["id"]
      end

      it 'should update the required_external_version and required_internal_version' do
        @external_firmware = Firmware.new(
          "version"=>"newer_internal",
          "description"=>"testOTA",
          "for_external"=>false,
          "download_url"=>"external/v2/0.0.9T",
          "data_file_name"=>"0.0_1_.9T",
          "data_content_type"=>"application/octet-stream",
          "data_file_size"=>125315,
          "data_updated_at"=>"2014-09-23T23:59:39.799Z")

        @internal_firmware = Firmware.new(
          "version"=>"newer_external",
          "description"=>"testOTA",
          "for_external"=>true,
          "download_url"=>"external/v2/0.0.9T",
          "data_file_name"=>"0.0_1_.9T",
          "data_content_type"=>"application/octet-stream",
          "data_file_size"=>125315,
          "data_updated_at"=>"2014-09-23T23:59:39.799Z")

        @external_firmware.save
        @internal_firmware.save
        @fv = FirmwareVersions.create(:default_required_internal_version => "newer_internal",
                               :default_required_external_version => "newer_external")
        @fv.save
        post(:create, @lock_commissioning_data)
        lock = Lock.last
        assert_equal lock.required_external_version, "newer_external"
        assert_equal lock.required_internal_version, "newer_internal"
        json = JSON.parse(response.body)
        check_payload(json, lock)
      end

      # Could add test of recommissioning decomissioned lock by other user.
      # But these rules may get revised anyway.

      # XXX Test bolt_state, orientation, bluetooth_address invalid values
      # TODO Stuff like this should only happen on the PUT, not POST

      it 'should allow recommissioning of active lock by different user, really now!' do
        post(:create, @lock_commissioning_data)
        l = Lock.last.update!(commission_date: Time.now)
        @user2, @device2, @user_device2 = make_user('glenn2@example.com')

        @lock_commissioning_data[:user_id] = @user2.id
        @lock_commissioning_data[:name] = "newname"
        @lock_commissioning_data[:bolt_state] = "failed"
        @lock_commissioning_data[:orientation] = "right"

        assert_difference 'Lock.count', 1 do
          post(:create, @lock_commissioning_data)
          check_response
        end
        @lock_commissioning_data[:commission_date] = nil
        @lock_commissioning_data[:id] = JSON.parse(@response.body)["id"]
        send_auth(@user_device2)
        put(:update, @lock_commissioning_data)
        check_response

        # TODO check_commissioning fails on the seq no
        #check_commissioning(response)
      end

      it 'should validate string length before saving and throw a 422 error' do
        @lock_commissioning_data[:internal_version] = '0.5.50.5.50.5.50.5.50.5.50.5.50.5.50.5.50.5.50.5.50.5.50.5.5'
        post(:create, @lock_commissioning_data)
        check_response 422
      end

    end


    describe "update/PUT" do
      subject { LocksController}

      before do
        DatabaseCleaner.start
        @routes = Rails.application.routes
        @user, @device, @user_device = make_user
        @lock = make_lock(@user)
        @key  = make_key(@lock, @user)
        @lock_data =  lock_base_data(@lock, @user)
      end

      after do
        DatabaseCleaner.clean
      end

      it "should update the lock status, not generate battery event" do
        # Because we create precommissioned locks, no key is created here.
        assert_difference "ActionMailer::Base.deliveries.size", 0 do
          assert_difference "Notification.count", 0 do
            assert_difference "Event.count", 0 do
              put(:sync, @lock_data)
            end
          end
        end
        @lock.reload
        check_response
        check_lock_version_data(@lock, @lock_data)
      end

      it "should allow for updating the lock details" do
        data = {
          id: @lock.id,
          name: "My Updated Lock",
          time_zone: "PDT"
        }
        assert @lock.commissioned?, "lock should have already been commissioned"

        send_auth(@user_device)
        put(:update, data)
        check_response

        @lock.reload
        assert_equal data[:name], @lock.name
        assert_equal data[:time_zone], @lock.time_zone

        # TODO what else can the user update about a lock?
      end

      it "should generate battery ok/low events" do
        # No email on battery events.
        assert_difference "ActionMailer::Base.deliveries.size", 0 do
          assert_difference "Notification.count", 1 do
            assert_difference "Event.count", 1 do
              @lock_data[:battery_state] = BatteryState::LOW
              put(:sync, @lock_data)
            end
          end
        end
        @lock.reload
        check_response
        check_lock_version_data(@lock, @lock_data)
        check_battery_event(@lock, BatteryState::LOW)

        assert_difference "ActionMailer::Base.deliveries.size", 0 do
          assert_difference "Notification.count", 1 do
            assert_difference "Event.count", 1 do
              @lock_data[:battery_state] = BatteryState::OK
              put(:sync, @lock_data)
            end
          end
        end
        @lock.reload
        check_response
        check_lock_version_data(@lock, @lock_data)
        check_battery_event(@lock, BatteryState::OK)

        assert_difference "ActionMailer::Base.deliveries.size", 0 do
          assert_difference "Notification.count", 0 do
            assert_difference "Event.count", 0 do
              put(:sync, @lock_data)
            end
          end
        end

        # Invalid case: no string value supplied
        assert_difference "ActionMailer::Base.deliveries.size", 0 do
          assert_difference "Notification.count", 0 do
            assert_difference "Event.count", 0 do
              @lock_data[:battery_state] = nil
              put(:sync, @lock_data)
            end
          end
        end

        assert_difference "ActionMailer::Base.deliveries.size", 0 do
          assert_difference "Notification.count", 0 do
            assert_difference "Event.count", 0 do
              @lock_data[:battery_state] = BatteryState::OK
              put(:sync, @lock_data)
            end
          end
        end
      end

      it "should throw 422 error because string length is too long" do
        @lock_data[:external_version] = "v0.0.5thisisten_thisisten_thisisten_thisisten_thisisten"
        put(:sync, @lock_data)
        check_response 422
      end

      # This is not in the flow, commission_date is initialized in the
      # controller on PUT if not already.
      # And commission_date is no longer validated on PUT.
=begin
      it "should throw 422 on update if not commissioned" do
        put(:update, lock_serial: @lock.lock_serial,
            commission_date: nil, decommission_date: Time.now)
        check_response 422, Util.VALIDATOR_MSGS[:BLANK]
      end
=end

      it "should update the lock status by lock_serial without authtoken" do
        header_auth
        @lock_data[:authtoken] = nil
        put(:sync, @lock_data)
        check_response
        @lock.reload
        check_lock_data(@lock, @lock_data)
      end

      it "should not update the lock status by lock id without authtoken" do
        header_auth
        @lock_data[:lock_serial] = nil
        @lock_data[:id] = @lock.id
        put(:update, @lock_data)
        check_response 401
      end

      it "should require valid data when updating lock status" do
        bolt_state_before = @lock.bolt_state
        @lock_data[:bolt_state] = "nosuchstate"
        header_auth
        put(:sync, @lock_data)
        @lock.reload
        assert_equal bolt_state_before, @lock.bolt_state
        check_response :unprocessable_entity
      end

      def url_len(max_url = 0, max_v = 0)
        version = "1.1.0Tthis is too long a version string for the firmware"[0..(StringLength::STRLIM_GENERAL.to_i + max_v)-1]
        @firmware = Firmware.new(
          "version"=>    version,
          "description"=>"testOTA",
          "for_external"=>false,
          "download_url"=>"external/v2/0.0.9T/thisisten_thisisten_thisisten_thisisten_thisisten_thisistenthisisten_thisistenthisisten_thisistenthisisten_thisistenthisisten_thisistenthisisten_thisistenthisisten_thisistenthisisten_thisisten_u"[0..(StringLength::STRLIM_OTA_URL.to_i + max_url)-1],
          "data_file_name"=>"0.0_1_.9T",
          "data_content_type"=>"application/octet-stream",
          "data_file_size"=>125315,
          "data_updated_at"=>"2014-09-23T23:59:39.799Z")

        #print @firmware["version"] + ": " + @firmware["version"].length.to_s + "\n"
        #print @firmware["download_url"] + ": " + @firmware["download_url"].length.to_s + "\n"
        @firmware.save
        @lock.required_internal_version = version
        @lock.save
        @lock_data = {
          :lock_serial => @lock.lock_serial, 
          :external_version => "v1.12.53a",
          :internal_version => version,
          :battery_level => "25",
          :battery_state => BatteryState::OK
        }
        put(:sync, @lock_data)
      end

      it "should not throw 422 error because firmware download_url string length STRLIM_OTA_URL is not too long" do
        url_len
        check_response
      end

      it "should throw 422 error because firmware download_url string length of STRLIM_OTA_URL+1 is too long" do
        url_len(1)
        check_response 422
      end

      it "should throw 422 error because firmware version string length of STRLIM_GENERAL+1 is too long" do
        url_len(0, 1)
        check_response 422
      end

      it "should return required internal and external versions and associated OTA fields" do
        @lock.required_internal_version = ActiveSupport::TestCase.INTERNAL_VERSION
        @lock.required_external_version = ActiveSupport::TestCase.EXTERNAL_VERSION
        put(:sync, :lock_serial => @lock.lock_serial,
            :required_internal_version => @lock.required_internal_version,
            :required_external_version => @lock.required_external_version)
        check_response
        # get updated seq_no
        @lock.reload
        json = JSON.parse(response.body)
        json.delete("seq_no")
        check_payload(json, @lock, [:seq_no, :last_sync])
        #check_reply(json: json, model: @lock, exclude: ["seq_no"])
        check_versions(json)
      end

      # XXX This is temporary until we work out authentication from the lock.
      it "should return required internal and external versions without authtoken" do
        # prefers active lock for update
        @dead_lock = make_lock(@user)
        @dead_lock.decommission_date = DateTime.now.utc.iso8601(3)
        @dead_lock.lock_serial = @lock.lock_serial
        @dead_lock.save
        put(:sync, :lock_serial => @lock.lock_serial)
        check_response
        # get updated seq_no
        @lock.reload
        json = JSON.parse(response.body)
        json.delete("seq_no")
        check_payload(json, @lock, [:seq_no, :last_sync])
        check_versions(json)
      end

      it "should update uncommissioned lock" do
        @lock.commission_date = nil
        # else will fail trying to create second key:
        @lock.keys.first.destroy
        @lock.save
        # prefers uncomissioned lock over decommissioned for update
        @dead_lock = make_lock(@user)
        @dead_lock.decommission_date = DateTime.now.utc.iso8601(3)
        @dead_lock.lock_serial = @lock.lock_serial
        @dead_lock.save
        put(:sync, :lock_serial => @lock.lock_serial)
        check_response
        # get updated seq_no
        @lock.reload
        json = JSON.parse(response.body)
        json.delete("seq_no")
        check_payload(json, @lock, [:seq_no, :last_sync])
      end

      # XXX need to prove that foreign keys work, but somehow they
      # aren't firing until the end of the test!
=begin
      it "should fail a foreign key check" do
        err = assert_raises Exception do
          @lock.keys.first.delete
          @lock.save
        end
      end
=end

      def check_versions(json)
        # *_url fields are generated per board requirements, not in db
=begin
        assert_equal(Firmware::HTTP_ROOT + 'external/v2/' +
                     ActiveSupport::TestCase.EXTERNAL_VERSION,
                     json["external_url"],
                     "external_url must be correctly constructed")
=end
        assert_equal(Firmware::FTP_ROOT + 'internal/v2/' +
                     ActiveSupport::TestCase.INTERNAL_VERSION,
                     json["internal_url"],
                     "internal_url must be correctly constructed")
        assert_equal(Firmware::HTTP_BUCKET + 'external/v2/',
                     json["external_path"],
                     "external_path must be correctly constructed")
        assert_equal('/internal/v2/',
                     json["internal_path"],
                     "internal_path must be correctly constructed")
        # *_ip is temporary for alpha so the lock http code doesn't
        # have to resolve dns.
        resolver = Resolv::DNS.new
        external_ip = resolver.getaddress(Firmware::HTTP_HOST).to_s
        internal_ip = resolver.getaddress(Firmware::FTP_HOST).to_s
        resolver.close
        assert_equal(external_ip, json["external_ip"],
                     "external_ip must be correctly constructed")
        assert_equal(internal_ip, json["internal_ip"],
                     "internal_ip must be correctly constructed")
        assert_equal(Firmware::HTTP_HOST, json["external_host"],
                     "external_host must be correctly constructed")
        assert_equal(Firmware::FTP_HOST, json["internal_host"],
                     "internal_host must be correctly constructed")
        assert_equal(Firmware::FTP_USER, json["internal_user"],
                     "internal_user must be correctly constructed")
        assert_equal(Firmware::FTP_PASS, json["internal_pass"],
                     "internal_pass must be correctly constructed")
      end

      it "should return 404 because lock serial was not found" do
        put(:sync, :lock_serial => "foo")
        check_response(404, :MISSING_RECORD)
      end

      it "should return 404 because lock serial was not found" do
        put(:sync, :lock_serial => "foo")
        check_response(404, :MISSING_RECORD)
      end

      it "should return 404 because lock serial was empty" do
        put(:sync, lock_serial: "")
        check_response(422, :MISSING_ALL_PARAMS)
      end

      # One test of PUT /locks/id is enough.
      it "should update the lock with commission values" do
        #pre_lock = @lock.dup
        File.open("#{Rails.root}/test/data/test.jpeg", 'r') do |f|
          @raw_file = f.read
          @encoded_file = Base64.encode64(@raw_file)
        end
        lock_data = {
          :id => @lock.id,
          :orientation => "left",
          :auto_unlock_owner => false,
          :auto_unlock_others => true
        }
        send_auth(@user_device)
        # No key event on commissioning (key.rb owner_key)
        assert_difference "ActionMailer::Base.deliveries.size", 0 do
          assert_difference "Notification.count", 0 do
            assert_difference "Event.count", 0 do
              put(:update, lock_data)
            end
          end
        end
        check_response
        log_json(response, "Locks PUT")
        @lock.reload
=begin
# Picture doesn't happen during a PUT by the app
# Actually how it happens TBD
        s3_file_url   = @lock.image.expiring_url
        byebug
        s3_file       = HTTParty.get(s3_file_url).body
        @raw_file.bytes.each_with_index do |char, i|
          if s3_file.bytes[i] != char
            print "wrong char at " + i.to_s + ": #{char}  #{s3_file.bytes[i]}\n"
            print "s3_file=" + s3_file
          end
          assert_equal s3_file.bytes[i], char
        end
           # test the tester...
           lock_data = {
            :id => @lock.id,
            :orientation => "right",
            :auto_unlock_owner => true,
            :auto_unlock_others => false,
            :authtoken => @user.account.authentication_token,
          }
=end
        check_lock_data(@lock, lock_data)
        json = JSON.parse(response.body)
        json.delete("seq_no")
        check_payload(json, @lock, [:seq_no])
=begin
           # test the tester...
           @lock[:name] = "bar"
           @lock[:status] = "2014-08-13T14:50:27.000Z"
           json = JSON.parse(response.body)
           json["commission_date"] = "2014.08-13T14:50:27+00:00"  # bad format
           json["commission_date"] = "2014-08-13T14:50:27+00:00"  # Disallows because other formats were removed
           check_payload(json, @lock)
=end
      end

      it "should return 422 because lock orientation is invalid" do
        lock_data = {
          :id => @lock.id,
          :orientation => "blar",
          :auto_unlock_owner => false,
          :auto_unlock_others => true
        }
        send_auth(@user_device)
        post(:update, lock_data)
        check_response(422)
      end

      it "should return 422 because lock_serial is missing" do
        lock_data = {
          :user_id => @user.id,
          :name => "my_lock"
        }
        assert_no_difference 'Lock.count' do
          post(:create, lock_data)
        end
        check_response(422)
      end

      it 'app should commission a new lock after lock sync' do
        #update with status sync (from lock)
        serial = Digest::MD5.hexdigest(@user.id.to_s + rand(100000).to_s)
        lock_data = {
          :user_id => @user.id,
          :lock_serial => serial,
          :name => "my_lock"
          #It should be an error that bluetooth_address is missing here, isn't because of temporary hack in code for commissioning.
        }

        #create a new lock (from lock)
        assert_difference 'Lock.count', 1 do
          post(:create, lock_data)
          check_response
        end

        json = JSON.parse(response.body)
        @c_lock = Lock.find(json["id"])
        check_response
        check_payload(json, @c_lock)
        check_lock_db_by_id(json["id"], lock_data)

        pre_lock = @c_lock.dup
        lock_status_data = {
          :lock_serial => serial,
          :internal_version => '0.5.5',
          :external_version => '0.5.5abc',
          :bolt_state => "unlocked",
        }

        # No auto-generated battery event.
        # Owner's key not created until commissioning is completed
        assert_difference "ActionMailer::Base.deliveries.size", 0 do
          assert_difference "Notification.count", 0 do
            assert_difference "Event.count", 0 do
              assert_difference "Key.count", 0 do
                 send_auth(@user_device)
                put(:sync, lock_status_data)
              end
            end
          end
        end
        check_response
        @c_lock.reload
        json = JSON.parse(response.body)
        json.delete("seq_no")
        check_payload(json, @c_lock, [:seq_no, :last_sync])
        check_lock_data(@c_lock, lock_status_data)

        send_auth(@user_device)
        lock_app_data = {
          :id => json["id"],
          :bluetooth_address => "BLUETOOTH-NAME1",
          :name => "my_lock",
          :orientation => "right",
          :auto_unlock_owner => false,
          :auto_unlock_others => true,
          :battery_state => BatteryState::LOW
        }
        # XXX other checks should be in this order, so event errors reported first.
        # Change from unknown to low battery_state fires event.
        # Testing change from unknown to ok not firing event above.
        # Check for creation of owner's 24x7 auto_generated key.
        assert_difference "Lock.active.count", +1 do
          assert_difference "ActionMailer::Base.deliveries.size", 0 do
            assert_difference "Notification.count", 0 do # key_shared event for owner key
              assert_difference "Event.count", 1 do
                assert_difference "Key.count", 1 do
                  send_auth(@user_device)
                  put(:update, lock_app_data)
                end
              end
            end
          end
        end

        check_response
        @c_lock.reload
        json = JSON.parse(response.body)

        #check that key was generated
        key = check_key_by_id(json["id"], json["user_id"], json["user_id"])
        assert_false key.auto_generated, "key should not have auto_generated set"
        json.delete("seq_no")
        check_payload(json, @c_lock, [:seq_no])
        check_lock_data(@c_lock, lock_app_data)
        assert_true @c_lock.commissioned?, "should be commissioned"

        Event.all.each do |event|
          if event.event_type==EventType::BATTERY
            assert_equal @c_lock.id,             event.lock_id
            assert_equal @c_lock.battery_state,  event.string_value
          end
        end
      end

     it "should require the same user to finish commissioning as who started it" do
       serial = Digest::MD5.hexdigest(@user.id.to_s + rand(100000).to_s)
       lock_data = {
         user_id: @user.id,
         lock_serial: serial,
       }
       post(:create, lock_data)
       assert_response :success
       json = JSON.parse(response.body)

       @user2, @device2, @user_device2 = make_user("unexpected_user@example.com")

       finish_data = {
         name: "my new lock",
         id: json["id"],
         bluetooth_address: "my-new-lock",
         user_id: @user2.id,
       }

       assert_no_difference "Lock.active.count" do
         send_auth(@user_device2)
         put(:update, finish_data)
         check_response :forbidden
       end

     end

     it "app should commission a new lock before lock sync" do
        serial = Digest::MD5.hexdigest(@user.id.to_s + rand(100000).to_s)
        lock_data = {
          :user_id => @user.id,
          :lock_serial => serial,
          :name => "my_lock"
        }
        #create a new lock (from lock)
        assert_difference 'Lock.count', 1 do
          post(:create, lock_data)
          check_response
        end

        json = JSON.parse(response.body)
        @b_lock = Lock.find(json["id"])
        check_response
        check_payload(json, @b_lock)
        check_lock_db_by_id(json["id"], lock_data)

        #update lock with commission values (from app)
        lock_app_data = {
          :id => json["id"],
          :bluetooth_address => "BLUETOOTH-NAME1",
          :name => "my_lock",
          :orientation => "right",
          :auto_unlock_owner => false,
          :auto_unlock_others => true,
        }
        # XXX other checks should be in this order, so event errors reported first.
        # Change from unknown to low battery_state fires event.
        # Testing change from unknown to ok not firing event above.
        # Check for creation of owner's 24x7 auto_generated key.
        assert_difference "Lock.active.count", +1 do
          assert_difference "ActionMailer::Base.deliveries.size", 0 do
            assert_difference "Notification.count", 0 do
              assert_difference "Event.count", 1 do
                assert_difference "Key.count", 1 do
                  send_auth(@user_device)
                  put(:update, lock_app_data)
                end
              end
            end
          end
        end

        check_response
        @b_lock.reload
        json = JSON.parse(response.body)

        #check that key was generated
        key = check_key_by_id(json["id"], json["user_id"], json["user_id"])
        assert_false key.auto_generated, "key should not have auto_generated set"
        assert_true @b_lock.commissioned?, "should be commissioned"
        json.delete("seq_no")
        check_payload(json, @b_lock, [:seq_no])
        check_lock_data(@b_lock, lock_app_data)

        lock_status_data = {
          :lock_serial => serial,
          :internal_version => '0.5.5',
          :external_version => '0.5.5abc',
          :bolt_state => "unlocked",
          :battery_state => BatteryState::LOW,
        }

        # No auto-generated battery event.
        # Owner's key not created until commissioning is completed
        assert_difference "ActionMailer::Base.deliveries.size", 0 do
          assert_difference "Notification.count",1 do
            assert_difference "Event.count", 1 do
              assert_difference "Key.count", 0 do
                put(:sync, lock_status_data)
              end
            end
          end
        end
        check_response
        @b_lock.reload
        json = JSON.parse(response.body)
        json.delete("seq_no")
        check_payload(json, @b_lock, [:seq_no, :last_sync])
        check_lock_data(@b_lock, lock_status_data)

        Event.all.each do |event|
          if event.event_type==EventType::BATTERY
            assert_equal @b_lock.id,             event.lock_id
            assert_equal @b_lock.battery_state,  event.string_value
          end
        end
     end

    end

    def check_battery_event(lock, value)
      event = Event.all.order('created_at ASC').last
      assert_equal lock.id,            event.lock_id
      assert_equal EventType::BATTERY, event.event_type
      assert_equal value,              event.string_value
    end

    describe "destroy/DELETE" do
      subject { LocksController}

      before do
        DatabaseCleaner.start
        @user, @device, @user_device  = make_user
        @lock  = make_lock(@user)
        @key   = make_key(@lock, @user)
        @user2, @device2, @user_device2 = make_user('glenn2@example.com')
        @key2  = make_guest_key(@lock, @user2.account.email, @user)
      end

      after do
        DatabaseCleaner.clean
      end


      it "can't route lock decommissioning without id" do
        begin
          delete(:destroy)
        rescue => e
          assert e.message.include?(ApplicationController.MESSAGES[:BAD_ROUTE]), "wrong bad route error"
        end
      end

      it "should reject lock decommissioning without authorization" do
        header_auth
        delete(:destroy, id: @lock.id)
        check_response :unauthorized, :UNAUTHORIZED
      end

      it "should reject lock decommissioning if not sysadmin or owner" do
        send_auth(@user_device2)
        delete(:destroy, id: @lock.id)
        check_response :unauthorized, :UNAUTHORIZED
        make_admin_user(@lock, @user2)
        send_auth(@user_device2)
        delete(:destroy, id: @lock.id)
        check_response :unauthorized, :UNAUTHORIZED
      end

      it "can't decommission lock with bad id" do
        send_auth(@user_device)
        delete(:destroy, id: 6666)
        check_response(404, :MISSING_RECORD)
      end

      it "owner can decommission a lock" do
        @admin, device, user_device = make_user("adminuser@example.com")
        make_admin_user(@lock, @admin)
        # Not sure why make_admin_user avoids making key if lock has one.
        make_primitive_auto_key(@lock, @admin, @lock.user)

        # Spec change: no notification to triggering owner.
        # Does not notify triggering owner.
        notice_count = 2
        # Notifies admin, and guest.
        assert_difference "Event.count", 1 do
          assert_difference "Notification.count", notice_count do
            assert_difference "ActionMailer::Base.deliveries.size", @@mail_count * notice_count do
            send_auth(@user_device)
            delete(:destroy, id: @lock.id)
            check_response
            end
          end
        end
        check_decommission(@admin, notice_count)

      end

      # sysadmin console case: does notify owner.
      it "sysadmin can decommission a lock" do
        @admin, device, user_device = make_user("adminuser@example.com")
        make_admin_user(@lock, @admin)
        make_primitive_auto_key(@lock, @admin, @lock.user)

        # Spec change: no notification to triggering owner.
        @sysadmin, sys_device, sys_user_device = make_user('sysadmin@example.com')
        acct = @sysadmin.account
        acct.admin = true
        acct.save!
        notice_count = 3
        assert_difference "Event.count", 1 do
          assert_difference "Notification.count", notice_count do
            assert_difference "ActionMailer::Base.deliveries.size", @@mail_count * notice_count do
            send_auth(sys_user_device)
            delete(:destroy, id: @lock.id)
            check_response
            end
          end
        end
        check_decommission(@admin, notice_count)
      end

      def check_decommission(admin, notice_count)
        lock_data = {
          :id => @lock.id,
          decommission_date: DateTime.now.utc.iso8601(3)
        }
        check_lock_data(@lock, lock_data, nil, true)
        # We are assuming no loss of keys and events...
        # Diverge from spec: admin gets DECOMMISSION notification.
        ActionMailer::Base.deliveries.each_with_index do |mail, idx|
          next if idx < ActionMailer::Base.deliveries.count - notice_count
          # If the email is right, the notification must be too.
          case(mail.to[0])
          when admin.account.email
          when @user.account.email
            assert_match @lock.name + "\" has been taken out of service.", mail.body.to_s
            assert_match Mailer::subjects(EventType::LOCK_DECOMMISSIONED), mail.subject
          else # guest
            assert_match @lock.name + "\" has been canceled.", mail.body.to_s
            assert_match Mailer::subjects(EventType::KEY_REVOKED), mail.subject
          end
        end
      end
    end


    describe "credentials/GET" do
      subject { LocksController}

      before do
        DatabaseCleaner.start
        @user, @device, @user_device  = make_user
        @device1_user, @device1_user_device  = make_device(@user)
        @device2_user, @device2_user_device  = make_device(@user, "a122e2")
        @lock  = make_lock(@user)
        @key   = make_key(@lock, @user)
        @user2, @device2, @user_device2  = make_user('glenn2@example.com')
        @device_user2, @device_user2_device  = make_device(@user2, "ad1234ef")
        @key2  = make_guest_key(@lock, @user2.account.email, @user)
        @lock_data =  lock_base_data(@lock, @user)
      end

      after do
        DatabaseCleaner.clean
      end

      it "should return credential package from lock id" do
        get_credentials
        check_credentials
        log_json(response, "/locks/credentials GET")
      end

      it "should update new_credentials on new key" do
        check_new_credentials(true, "before")
        get_credentials
        check_new_credentials(false, "after get")
        user3, device3, user_device3 = make_user('glenn3@example.com')
        make_guest_key(@lock, user3.account.email, @user)

        check_new_credentials(true, "after new key")
      end

      it "should update new_credentials on deleted key" do
        get_credentials
        check_new_credentials(false, "after get")
        @key2.destroy
        check_new_credentials(true, "after deleted key")
      end

      it "should update new_credentials on new user_device" do
        check_new_credentials(true, "before")
        get_credentials
        check_new_credentials(false, "after get")
        @device2_user2, user_device2= make_device(@user2, "fead1234ef")
        check_new_credentials(true, "after new user_device")
        get_credentials
        check_credentials(6)
      end

      it "should update new_credentials on deleted user_device" do
        get_credentials
        check_new_credentials(false, "after get")
        ud = UserDevice.where(user_id: @user2.id)
        ud.first.destroy
        check_new_credentials(true, "after deleted key")
        get_credentials
        check_credentials(4)
      end

=begin
      it "XXX should update new_credentials on decommissioned device" do
      end

      it "should update new_credentials on changed key" do
        get_credentials
        check_new_credentials(false, "after get")
        # TBD: test actual time change action from endpoint, which causes
        # key replacement.
        @key2.replaced = true
        @key2.save!
        check_new_credentials(true, "after changed key")
      end
=end

      def get_credentials
#        send_auth(@user_device)
        get(:get_credentials, id: @lock.id)
      end

      def validate_new_credentials(state, context)
        check_response
        json = JSON.parse(response.body)
        assert_equal state, json["new_credentials"], "new_credentials " + context
      end

      # This doesn't actually load and validate the new creds, just the
      # new_credentials state.
      def check_new_credentials(state, context)
        put(:sync, @lock_data)
        validate_new_credentials(state, context)
        send_auth(@user_device)
        get(:show, id: @lock.id)
        validate_new_credentials(state, context)
      end

      def check_credentials(ud_count = 5)
        assert_response 200
        json = JSON.parse(response.body)
        assert json
        credentials = json["credentials"]
        users_devices = credentials["users_devices"]
        keys          = credentials["keys"]
        server_time   = credentials["server_time"]
        expire        = credentials["expire"]
        lock          = credentials["lock"]

        assert_not_nil keys, "keys missing"
        assert_equal 2, keys.count, "expect two keys"
        assert_equal keys[0], @key.id, "key id match"
        assert_not_nil users_devices, "users_devices missing"
        assert_not_nil json["signature"], "signature missing"
        assert_equal ud_count, users_devices.count, "expect " + ud_count.to_s + " users_devices"
        device1_users_device = UserDevice.find_by_device_id(@device1_user.id)

        key1 = users_devices[device1_users_device.id.to_s]
        assert_not_nil key1, "users_devices key1 missing"
        public_key = key1["public_key"]
        user_id = key1["user_id"]
        assert_not_nil public_key, "users_devices key1 public_key missing"
        assert_not_nil user_id,    "users_devices key1 user_id missing"
        assert_equal user_id, @user.id, "key1 user_id mismatch"
        assert_equal CryptoRSA.new(device1_users_device.private_key).get_public_key_pem, public_key, "users_devices public_key incorrect"

        assert_not_nil server_time, "server_time missing"
        check_new_date(server_time, "server_time")

        assert_not_nil expire, "expire missing"
        assert_equal ApplicationController.CREDENTIAL_MAX_TRANSIT_TIME, expire, "expire seconds mismatch"

        assert_not_nil lock, "lock missing"
        assert_equal @lock.id, lock, "lock id mismatch"
      end
    end


    def lock_base_data(lock, user)
      {
        :lock_serial => lock.lock_serial, :internal_version => "v1.12.53a",
        :external_version => "v0.0.5b", :battery_level => 50, :battery_state => BatteryState::OK,
      }
    end

    def check_lock_data(lock, lock_data,
                        ignore = nil,
                        approx_time = false,
                        disallow = nil)
      # Not real db fields.
      ig = [ :image, :authtoken]
      ig += ignore if ignore
      check_data(lock, lock_data, ig, approx_time, disallow)
    end

    def check_lock_version_data(lock, lock_data)
      assert_equal lock_data[:internal_version], lock.internal_version
      assert_equal lock_data[:external_version], lock.external_version
      assert_equal lock_data[:battery_level], lock.battery_level
      assert_equal lock_data[:battery_state], lock.battery_state
    end

    def get_index(user)
        user.reload
        user_device = user.user_devices.first
        send_auth(user_device)
        get(:index)
    end
  end
end
