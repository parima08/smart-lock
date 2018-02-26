require "test_helper"

class LogsControllerTest < ActionController::TestCase

  describe LogsController do

    describe "show/GET" do
      subject { LogsController }

      before do
        DatabaseCleaner.start
        @routes = Rails.application.routes
        @user, @device_u, @user_device_u = make_user
        @lock = make_lock(@user)
        @ua_token = '64ce3cbfb716c0eb61adc2d6da1f2781e8b74d39b49c1e521108db9109b1be35'
        @device, @user_device= make_device(@user, @ua_token)
      end

      after do
        DatabaseCleaner.clean
      end

      it "must respond" do
        assert @routes
      end

      it "should get unauthorized response from show with bad authtoken" do
        header_auth("junk", @user_device.id)
        get(:show, id: @lock.id, authtoken: "junk")
        check_response :unauthorized, :UNAUTHORIZED
      end

      #XXX test special lock_serial and device routes.
=begin
      # TODO determine if this is needed LP21007612
      it "should get unauthorized response from show without authtoken" do
        header_auth(nil, @user_device.id)
        get(:show, id: @lock.id,  authtoken: nil)
        check_response :unauthorized
      end
=end

      # Doesn't even route to show without an id, so can't test?
=begin
      it "should report missing parameters one of id, lock_serial, device_id, ua_token" do
        get(:show, i: @lock.id,
            authtoken: @user.account.authentication_token)
        check_response 423, :MISSING_PARAM
      end
=end

      it "should report missing all parameters source, fault_time" do
        send_auth(@user_device)
        get(:show, id: @lock.id)
        check_response 422, :MISSING_PARAM
      end

      it "should report no log" do
        send_auth(@user_device)
        get(:show, id: @lock.id,
            source: "lock",
            fault_time: DateTime.now.utc.iso8601(0))
        check_response 404, :MISSING_RECORD
        check_response 404, "Log"
      end

      it "should report no log even if lock not active" do
        @lock.decommission_date = DateTime.now.utc.iso8601(3)
        @lock.save
        send_auth(@user_device)
        get(:show, lock_serial: @lock.lock_serial,
            source: "lock",
            fault_time: DateTime.now.utc.iso8601(0))
        check_response 404, :MISSING_RECORD
        check_response 404, "Log"
      end

      it "should report log from lock without authtoken" do
        post_data = {
          lock_id: @lock.id,
          lock_serial: @lock.lock_serial,
          source: "lock",
          fault_time: DateTime.now.utc.iso8601(0),
          fault_type: "some error code",
          device_id: @device.id,
          ua_token: @device.ua_token,
          data_type: "binary",
          data: Base64.encode64("stuff"),
          authtoken: nil
        }
        post(:create, post_data)
        check_response(:success, nil, __LINE__)

        ref_data = {
          lock_id: @lock.id,
          lock_serial: @lock.lock_serial,
          source: "lock",
          fault_time: DateTime.now.utc.iso8601(0),
          device_id: @device.id,
          ua_token: @device.ua_token,
          authtoken: nil
        }
        get(:show, ref_data)
        check_response
      end

      it "should update lock wifi status from lock on show without authtoken" do
         fault_time = DateTime.now.utc.iso8601(3)
         source = "lock"
         ref_data = {
           lock_id: @lock.id,
           source: source,
           fault_time: fault_time,
           fault_type: "some error code",
           device_id: @device.id,
           data_type: "binary",
           data: Base64.encode64("stuff"),
           authtoken: nil
         }
         post(:create, ref_data)
         assert_difference('Event.count', 1) do
           @lock.reported_wifi_status = LockCommState::LOCK_COMM_DOWN
           @lock.update_with_wifi(LockCommState::LOCK_COMM_UP, nil)
           get(:show, lock_serial: @lock.lock_serial,
             source: source,
             fault_time: fault_time,
             authtoken: nil)
         end
         @lock.reload
         assert_equal @lock.reported_wifi_status, LockCommState::LOCK_COMM_UP
         fuzzy_compare_datetime(Time.now, @lock.updated_at, 2)
       end

    end


    describe "create/POST" do
      subject { LogsController }

      before do
        DatabaseCleaner.start
        @routes = Rails.application.routes
        @user, @device, @user_device_u = make_user
        @lock = make_lock(@user)
        @ua_token = '64ce3cbfb716c0eb61adc2d6da1f2781e8b74d39b49c1e521108db9109b1be35'
        @device, @user_device = make_device(@user, @ua_token)
      end

      after do
        DatabaseCleaner.clean
      end

      it "must respond" do
        assert @routes
      end

      it "should get unauthorized response from post with bad authtoken" do
        header_auth("junk", @user_device.id)
        post(:create)
        check_response :unauthorized, :UNAUTHORIZED
      end

      #XXX test lock authentication json_lock_auth, once implemented.
      it "should create a log from Lock without authtoken" do
        ref_data = {
          lock_id: @lock.id,
          lock_serial: @lock.lock_serial,
          source: "lock",
          fault_time: DateTime.now.utc.iso8601(0),
          fault_type: "some error code",
          device_id: @device.id,
          ua_token: @device.ua_token,
          data_type: "binary",
          data: Base64.encode64("stuff"),
          authtoken: nil
        }
        post(:create, ref_data)
        check_response
      end

      # TODO Determine case for when lock auth implemented LP21007612
      it "should get unauthorized response from create without authtoken if not lock" do
        header_auth(nil, @user_device.id)
        ref_data = {
          lock_id: @lock.id,
          source: "ios",
          fault_time: DateTime.now.utc.iso8601(0),
          fault_type: "some error code",
          device_id: @device.id,
          ua_token: @device.ua_token,
          data_type: "binary",
          data: Base64.encode64("stuff"),
        }

        post(:create, ref_data)
        check_response :unauthorized
      end

      it "should report missing parameters one of lock_id, lock_serial, device_id, ua_token" do
        send_auth(@user_device)
        post(:create)
        check_response 422, :MISSING_ALL_PARAMS
        check_no_data
      end

      it "should report missing all parameters source, data, fault_time" do
        send_auth(@user_device)
        post(:create, lock_id: @lock.id)
        check_response 422, :MISSING_PARAM
        check_no_data
      end

      it "should report missing parameter source" do
        send_auth(@user_device)
        post(:create, lock_id: @lock.id,
             # Only seconds required, not checked.
             fault_time: DateTime.now.utc.iso8601(0),
             data_type: "text",
             data: "stuff")
        check_response 422, :MISSING_PARAM
        check_no_data
      end

      it "should report missing parameter data" do
        send_auth(@user_device)
        post(:create, lock_id: @lock.id,
             source: "lock",
             fault_time: DateTime.now.utc.iso8601(0),
             data_type: "text")
        check_response 422, :MISSING_PARAM
        check_no_data
      end

      it "should report missing {empty} source parameter" do
        send_auth(@user_device)
        post(:create, lock_id: @lock.id,
             source: "",
             fault_time: DateTime.now.utc.iso8601(0),
             data_type: "binary",
             data: "stuff")
        check_response 422, :MISSING_PARAM
        check_no_data
      end

       it "should throw 422 if string is too long" do
         send_auth(@user_device)
         post(:create, lock_id: @lock.id,
             source: "",
             fault_time: DateTime.now.utc.iso8601(0),
             fault_type: "thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_",
             data_type: "binary",
             data: "stuff")
        check_response 422
      end

      it "should report bad data_type parameter" do
        send_auth(@user_device)
        post(:create, lock_id: @lock.id,
             source: "lock",
             fault_time: DateTime.now.utc.iso8601(3),
             data_type: "bad",
             data: "stuff")
        check_response 422, :INVALID_PARAM
        check_no_data
      end

      it "should report bad source parameter" do
        send_auth(@user_device)
        post(:create, lock_id: @lock.id,
             source: "bad",
             fault_time: DateTime.now.utc.iso8601(0),
             data_type: "binary",
             data: "stuff")
        check_response 422, :INVALID_PARAM
        check_no_data
      end

      it "should report bad fault_time parameter" do
        send_auth(@user_device)
        post(:create, lock_serial: @lock.lock_serial,
             source: "lock",
             fault_time: "jjunk", # "junk" shouldn't parse, but does ("Jun")!
             data_type: "binary",
             data: "stuff")
        check_response 422, :INVALID_PARAM
        check_no_data
      end

      it "should save and report log present with lock_id/serial, without device_id/ua_token, not find with bad source" do
        fault_time = DateTime.now.utc.iso8601(3)
        source = "lock"
        ref_data = {
          lock_id: @lock.id,
          source: source,
          fault_time: fault_time,
          fault_type: "some error code",
          #device_id: @device.id,
          data_type: "binary",
          data: Base64.encode64("stuff")
        }
        send_auth(@user_device)
        post(:create, ref_data)
        ref_data[:data] = Base64.decode64(ref_data[:data])
        log_json(response, "Logs POST")
        check_success
        check_log_data(ref_data, [:device_id], nil)
        send_auth(@user_device)
        get(:show, lock_serial: @lock.lock_serial,
            source: source,
            fault_time: fault_time)
        log_json(response, "Logs GET /logs/id")
        check_success

        send_auth(@user_device)
        get(:show, lock_serial: @lock.lock_serial,
            source: "device",
            fault_time: fault_time)
        check_response 404, :MISSING_RECORD
        check_response 404, "Log"
      end

      it "should save and report log present with lock_serial/id, with default data_type, not find with wrong fault_time" do
        fault_time = DateTime.now.utc.iso8601(3)
        source = "lock"
        ref_data = {
          lock_serial: @lock.lock_serial,
          source: source,
          fault_time: fault_time,
          fault_type: "some error code",
          data: Base64.encode64("binary stuff\n\r\xff\x01"),
          # XXX test lock auth post-alpha
        }
        send_auth(@user_device)
        post(:create, ref_data)
        check_success
        ref_data[:lock_id] = @lock.id
        ref_data[:data] = Base64.decode64(ref_data[:data])
        check_log_data(ref_data, nil, [:data_type])
        send_auth(@user_device)
        get(:show, id: @lock.id,
            source: source,
            fault_time: fault_time)
        check_success
        send_auth(@user_device)
        get(:show, id: @lock.id,
            source: source,
            fault_time: "June")
        check_response 404, :MISSING_RECORD
        check_response 404, "Log"
      end

      it "should save with device_id, find with ua_token, not find record with a bad fault_time" do
        fault_time = DateTime.now.utc.iso8601(3)
        source = "lock"
        ref_data = {
          source: source,
          fault_time: fault_time,
          fault_type: "some error code",
          device_id: @device.id,
          data_type: "text",
          data: Base64.encode64("text stuff")
        }
        send_auth(@user_device)
        post(:create, ref_data)
        ref_data[:data] = Base64.decode64(ref_data[:data])
        check_success
        check_log_data(ref_data, [:lock_id], nil)

        send_auth(@user_device)
        get(:show,
            #lock_id: @lock.id,
            ua_token: @device.ua_token,
            source: source,
            fault_time: fault_time)
        check_success
        send_auth(@user_device)
        get(:show,
            #lock_id: @lock.id,
            ua_token: @device.ua_token,
            source: source,
            fault_time: "June")
        check_response 404, :MISSING_RECORD
        check_response 404, "Log"
      end

      it "should save with ua_token, find with device_id, not find record with a bad fault_time" do
        fault_time = DateTime.now.utc.iso8601(3)
        source = "lock"
        ref_data = {
          source: source,
          fault_time: fault_time,
          fault_type: "some error code",
          ua_token: @device.ua_token,
          data_type: "text",
          data: Base64.encode64("text stuff")
        }
        send_auth(@user_device)
        post(:create, ref_data)
        check_success
        ref_data[:device_id] = @device.id
        ref_data[:data] = Base64.decode64(ref_data[:data])
        check_log_data(ref_data, [:lock_id], nil)

        send_auth(@user_device)
        get(:show,
            #lock_id: @lock.id,
            device_id: @device.id,
            source: source,
            fault_time: fault_time)
        check_success

        send_auth(@user_device)
        get(:show,
            #lock_id: @lock.id,
            device_id: @device.id,
            source: source,
            fault_time: "June")
        check_response 404, :MISSING_RECORD
      end
    end
  end

  def check_no_data
    assert_equal 0, Log.all.count, "Log record improperly created"
    assert_equal 0, LogData.all.count, "LogData record improperly created"
  end
  def check_log_data(ref, disallow_log, disallow_data)
    log = ref[:lock_id] ?
      Log.find_by_lock_id(ref[:lock_id]) :
      Log.find_by_device_id(ref[:device_id])
    assert_not_nil log, "Did not find log db record!"
    check_data(log, ref, [ :data_type, :data, :authtoken, :lock_serial, :ua_token ],
               false, disallow_log)

    log_data = LogData.find(log.log_data_id)
    assert_not_nil log_data, "Did not find log db record!"
    check_data(log_data, ref, [:lock_id, :lock_serial, :ua_token,
                               :device_id, :source,
                               :fault_time, :fault_type, :authtoken],
               false, disallow_data)
  end

end
