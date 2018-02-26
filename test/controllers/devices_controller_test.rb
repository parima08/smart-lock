require "test_helper"

class DevicesControllerTest < ActionController::TestCase

  describe DevicesController do

    describe "create/update POST/PUT action" do
      subject { DevicesController }

      before do
        DatabaseCleaner.start
        @@device_start_count = 0
        @routes = Rails.application.routes
        @user, @device, @user_device = make_user
        @ua_token = '64ce3cbfb716c0eb61adc2d6da1f2781e8b74d39b49c1e521108db9109b1be32'
        send_auth(@user_device)
        @post_data = {
                      :ua_token => @ua_token,
                      :device_type => "iOS"}
        post(:create, @post_data)
        @json = JSON.parse(response.body)
        @test_device = Device.find(@json["id"])
        @test_user_device = UserDevice.find(@json["user_device"]["id"])

        @put_data = {
          :id => @test_device["id"],
          :ua_token => @ua_token,
          # Changing device_type is allowed but not a required feature.
          #device_type: "iOS",
          device_model: "newdm",
          os_version: "newov",
          app_version: "newav",
        }
      end

      after do
        DatabaseCleaner.clean
        @@device_start_count = 0
      end

      it "should update device info" do
        send_auth(@test_user_device)
        put(:update, @put_data)
        log_json(response, "Devices PUT")
        check_response
        check_data(@test_device, @put_data)
      end

      it "should reject update from wrong device" do
        send_auth(@user_device)
        put(:update, @put_data)
        check_response 422, :WRONG_ACCOUNT_PARAM
      end

      it "should reject update to decommissioned user_device" do
        @test_user_device.decommissioned_at = DateTime.now
        send_auth(@test_user_device)
        put(:update, @put_data)
        check_response 409, :DECOMMISSIONED
      end

      it "should create a device and a user but needs to confirm" do
        check_response 200
        # XXX flip all expected/actual
        assert_equal @@device_start_count+1, Device.all.count
        log_json(response, "Devices POST")
        @device = Device.last
        @user_device = UserDevice.last
        check_data(@device, @post_data)
        check_payload(@json["user_device"], @user_device,
                       [
                        :confirmation_token,
                        :confirmed_at,
                        :decommissioned_at,
                        :private_key,
                        :keys_sent_at,
                        :name],  #exclude
                        nil, #allow
                        []
                    )
      end
      # Not registering anymore LP16187219
      #it "should fail to register a device with a bad token" do
      #  @ua_token = 'bad_token'
      #  post(:create, :ua_token => @ua_token,
      #       :authtoken => @user.account.authentication_token, :device_type => "android")
      #  check_response 500
      #end
    end

    describe "destroy action" do
      subject { DevicesController }

      before do
        DatabaseCleaner.start
        @routes = Rails.application.routes
        @user, @device, @user_device = make_user
        @ua_token = '64ce3cbfb716c0eb61adc2d6da1f2781e8b74d39b49c1e521108db9109b1be35'
      end

      after do
        DatabaseCleaner.clean
        @@device_start_count = 0
      end

      it "should return not found on a destroy where device doesn't exist" do
        send_auth(@user_device)
        delete(:destroy, id: '99999')
        @json = JSON.parse(response.body)
        check_response 422, :WRONG_ACCOUNT_PARAM
        assert_equal @@device_start_count, Device.all.count, "no device deleted"
      end
      it "should return bad request on a destroy with empty device id" do
        send_auth(@user_device)
        delete(:destroy, :id => "")
        @json = JSON.parse(response.body)
        check_response 422, :MISSING_PARAM
        assert_equal @@device_start_count, Device.all.count, "no device deleted"
      end

      it "should return auth error on a destroy with no auth" do
        device, user_device = make_confirmed_device_ud(@user, @ua_token)
        delete(:destroy, id: device.id)
        @json = JSON.parse(response.body)
        check_response 401
        assert_equal @@device_start_count, Device.all.count, "back to base device count"
      end

      it "should logout from a device that exists" do
        device = user_device = nil
        assert_difference [ 'Device.count', 'UserDevice.count' ], +1 do
          device, user_device = make_confirmed_device_ud(@user, @ua_token)
        end
        check_now_date user_device.authenticated_at
        send_auth(user_device)
        delete(:destroy, id: device.id)
        @json = JSON.parse(response.body)
        check_response 200
        log_json(response, "Devices DESTROY")
        assert_equal @@device_start_count, Device.all.count, "retained device"
        user_device.reload
        assert_nil user_device.authenticated_at
        assert_nil user_device.authentication_token
      end

      it "should create a new user_device when a different user registers the same device" do
        assert_difference 'Device.count', +1 do
          @device = make_device(@user, @ua_token)
        end
        @user2, @dev, @user_dev = make_user("anothertester@example.com")
        @user2.user_devices.first.destroy
        assert_difference 'UserDevice.count', +1 do
          @device2, @user_device2 = make_device(@user2, @ua_token)
        end
        # Make sure it's assigned to the right user
        assert_equal @user2.user_devices.first.device_id, @device2.id, "user_device.device_id matches device.id"
      end

    end

    # XXX update tests above need to merged to here.
    describe "update action" do
      subject { DevicesController }

      before do
        DatabaseCleaner.start
        @routes = Rails.application.routes
        @user, @device, @user_device= make_user
        @ua_token = 'update_test_token'
        @put_data = {:ua_token => @ua_token,
                     :id => @device.id,
                     :app_version => "iOS",
                     :os_version => "7",
                     :device_model => "iPod Touch",
                     :device_confirmation_token => @user_device.confirmation_token}
      end

      after do
        DatabaseCleaner.clean
      end

      it "should confirm user_device and update device" do
        send_auth(@user_device)
        put(:update, @put_data)
        check_response 200
        check_data(@device, @put_data, [:device_confirmation_token])
      end

      it "should update the push token status" do
        # There's probably better ways to figure out if the action as run, but for now
        # checking that endpoint_disabled_at has been cleared should show us something
        @device.endpoint_disabled_at = 1.day.ago
        @device.save
        @put_data[:ua_token] = '64ce3cbfb716c0eb61adc2d6da1f2781e8b74d39b49c1e521108db9109b1be32'

        send_auth(@user_device)
        put(:update, @put_data)
        check_response 200
        @device.reload
        assert_equal nil, @device.endpoint_disabled_at
      end

    end

  end
end
