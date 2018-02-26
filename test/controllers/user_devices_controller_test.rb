require "test_helper"

class UserDevicesControllerTest < ActionController::TestCase

  describe UserDevicesController do

    # New Device Confirmation
    # PUT /users_device/id: 
    describe "update/PUT" do
      subject { UserDevicesController }

      before do
        DatabaseCleaner.start
        @@user_device_start_count = 0
        @user, @device_u, @user_device = make_user(email = 'person2@example.com', password = 'aba456')
        @user2, @device2, @user2_device  = make_user
        @ua_token = '64ce3cbfb716c0eb61adc2d6da1f2781e8b74d39b49c1e521108db9109b1be35'
        @device = make_primitive_device(@ua_token)
        @test_user_device = make_user_device(@user, @device)
      end

      after do
        DatabaseCleaner.clean
        @@user_device_start_count = 0
      end

      it "should not confirm without authtoken and user_device_id in request header" do
        header_auth
        put(:update, :id => @test_user_device.id,
                     :device_confirmation_token => @test_user_device.confirmation_token)
        check_response :unauthorized, :UNAUTHORIZED
      end

      it "should not confirm mismatched authtoken and user_device_id in request header" do
        header_auth(@user_device.authentication_token, @test_user_device.id)
        put(:update, :id => @test_user_device.id,
                     :device_confirmation_token => @test_user_device.confirmation_token)
        check_response :unauthorized, :UNAUTHORIZED
      end

      it "should not confirm missing authtoken, but user_device_id is present in request header" do
        header_auth(nil, @test_user_device.id)
        put(:update, :id => @test_user_device.id,
                     :device_confirmation_token => @test_user_device.confirmation_token)
        check_response :unauthorized, :UNAUTHORIZED
      end

      it "should not confirm missing user_device_id, but authtoken is present in request header" do
        header_auth(@user_device.authentication_token, nil)
        put(:update, :id => @user_device.id,
                     :device_confirmation_token => @user_device.confirmation_token)
        check_response :unauthorized, :UNAUTHORIZED
      end

      it "should not confirm invalid user_device_id, but authtoken is present in request header" do
        header_auth(@user_device.authentication_token, 9999)
        put(:update, :id => @user_device.id,
                     :device_confirmation_token => @user_device.confirmation_token)
        check_response :unauthorized, :UNAUTHORIZED
      end

      it "should confirm user_device" do
        send_auth(@user_device)
        check_data(@test_user_device, { confirmed_at: nil })
        put(:update, :id => @test_user_device.id,
                     :device_confirmation_token => @test_user_device.confirmation_token)
        log_json(response, "UserDevices PUT")
        check_response
        check_data(@test_user_device, { confirmed_at: DateTime.now.to_s }, nil, true)
      end

      it "should reject user_device confirm without token" do
        send_auth(@user_device)
        put(:update, :id => @test_user_device.id)
        check_response 422, :MISSING_PARAM, __LINE__
      end

      it "should reject user_device confirm with invalid id" do
        send_auth(@user_device)
        put(:update, :id => 123,
                     :device_confirmation_token => @test_user_device.confirmation_token)
        check_response 404, :MISSING_RECORD, __LINE__
      end

      it "should reject user_device confirm by non-owner" do
        send_auth(@user2_device)
        put(:update, :id => @test_user_device.id,
                     :device_confirmation_token => @test_user_device.confirmation_token)
        check_response 422, :WRONG_ACCOUNT_PARAM, __LINE__
      end

      it "should reject user_device confirm from same device" do
        send_auth(@test_user_device)
        put(:update, :id => @test_user_device.id,
                     :device_confirmation_token => @test_user_device.confirmation_token)
        check_response 422, :WRONG_DEVICE, __LINE__
      end

      it "should reject user_device confirm with wrong confirmation_token" do
        send_auth(@user_device)
        put(:update, :id => @test_user_device.id,
                     :device_confirmation_token => @user_device.confirmation_token)
        check_response 422, :WRONG_PARAM, __LINE__
      end
      it "should reject user_device confirm on decommissioned user_device" do
        send_auth(@user_device)
        @test_user_device.decommissioned_at = DateTime.now
        @test_user_device.save!
        put(:update, :id => @test_user_device.id,
                     :device_confirmation_token => @test_user_device.confirmation_token)
        check_response 409
      end


    end

    describe "destroy action" do
      subject { UserDevicesController }

      before do
        DatabaseCleaner.start
        @@user_device_start_count = 0
        @user, @device, @user_device = make_user
        @ua_token = '64ce3cbfb716c0eb61adc2d6da1f2781e8b74d39b49c1e521108db9109b1be35'
      end

      after do
        DatabaseCleaner.clean
        @@user_device_start_count = 0
      end

      it "should return not found on a destroy where user_device doesn't exist" do
        send_auth(@user_device)
        delete(:destroy, id: '99999')
        @json = JSON.parse(response.body)
        check_response 422, :WRONG_ACCOUNT_PARAM
        assert_equal @@user_device_start_count, UserDevice.all.count, "no user_device deleted"
      end
      it "should return bad request on a destroy with empty user_device id" do
        send_auth(@user_device)
        delete(:destroy, :id => "")
        @json = JSON.parse(response.body)
        check_response 422, :MISSING_PARAM
        assert_equal @@user_device_start_count, UserDevice.all.count, "no user_device deleted"
      end

      it "should return auth error on a destroy with no auth" do
        device, user_device = make_confirmed_device_ud(@user, @ua_token)
        header_auth
        delete(:destroy, id: user_device.id)
        @json = JSON.parse(response.body)
        check_response 401
        assert_equal @@user_device_start_count, UserDevice.all.count, "back to base user_device count"
      end

      it "should decommission a user_device that exists" do
        device, user_device = make_confirmed_device_ud(@user, @ua_token)
        send_auth(user_device)
        delete(:destroy, id: user_device.id)
        check_response 200
        @json = JSON.parse(response.body)
        log_json(response, "UserDevices DESTROY")
        assert_equal @@user_device_start_count, UserDevice.all.count, "retained user-device"
        user_device.reload
        assert_not_nil user_device.decommissioned_at, "did not get decommissioned!"
        check_now_date(user_device.decommissioned_at)
      end
    end
  end
end
