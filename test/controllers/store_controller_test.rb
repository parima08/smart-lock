require "test_helper"

class StoreControllerTest < ActionController::TestCase

  describe StoreController do

    subject { StoreController }

    before do
    end

    after do
    end

    it "should show instructions if non-mobile browser" do
      get(:index)
      assert_response :success
      assert response.body.index("Please view this email")
    end

    it "should redirect to AppBlade if Android" do
      @request.user_agent = 'Mozilla/5.0 (Linux; U; Android 4.3; en-us; SCH-I535 Build/JSS15J) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30'
      get(:index)
      assert_response :redirect
      assert_equal response["Location"], StoreController::APP_BLADE
    end

    it "should redirect to AppBlade if IOS" do
      @request.user_agent = 'Mozilla/5.0 (iPhone; U; CPU iPhone OS 4_0 like Mac OS X; en-us) AppleWebKit/532.9 (KHTML, like Gecko) Version/4.0.5 Mobile/8A293 Safari/6531.22.7'
      get(:index)
      assert_response :redirect
      assert_equal response["Location"], StoreController::APP_BLADE
    end

    it "should redirect to AppBlade if iPod" do
      @request.user_agent = "UA:Mozilla/5.0 (iPod touch; CPU iPhone OS 7_1_2 like Mac OS X) AppleWebKit/537.51.2 (KHTML, like Gecko) Mobile/11D257"
      get(:index)
      assert_response :redirect
      assert_equal response["Location"], StoreController::APP_BLADE
    end


    # Not the cleanest way to check for messages - should we store
    # the strings in constants?
    it "should prompt user to view on iOS/Android when on Desktop" do
      @request.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/31.0.1650.63 Safari/537.36"
      get(:go)
      msg =  @controller.instance_variable_get("@msg")
      assert_equal msg, "Please view this email on an iOS/Android device."
    end

    it "should state os and version number when on unsupported device {Android}" do
      @request.user_agent = "Mozilla/5.0 (Linux; U; Android 4.0.2; en-us; Galaxy Nexus Build/ICL53F) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30"
      get(:go)
      msg = @controller.instance_variable_get("@msg")
      assert_equal msg, "We only support Android 4.4 and higher."
    end

    it "should state os and version number when on unsupported device {iPod}" do
      @request.user_agent = "UA:Mozilla/5.0 (iPod touch; CPU iPhone OS 6 like Mac OS X) AppleWebKit/537.51.2 (KHTML, like Gecko) Mobile/11D257"
      get(:go)
      msg = @controller.instance_variable_get("@msg")
      assert_equal msg, "We only support iOS 7.0 and higher."
    end

    it "should state os and version number when on unsupported device {iPhone}" do
      @request.user_agent = "Mozilla/5.0 (iPhone; CPU iPhone OS 6_0 like Mac OS X) AppleWebKit/536.26 (KHTML, like Gecko) Version/6.0 Mobile/10A5376e Safari/8536.25"
      get(:go)
      msg =  @controller.instance_variable_get("@msg")
      assert_equal msg, "We only support iOS 7.0 and higher."
    end

    it "should state that it is redirecting to Goji if user is on supported device {Android}" do
      @request.user_agent = "Mozilla/5.0 (Linux; U; Android 5.0; en-us; Galaxy Nexus Build/ICL53F) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30"
      get(:go)
      msg =  @controller.instance_variable_get("@msg")
      assert_equal msg, "Redirecting to Goji app... if the application doesn't open automatically, click the button below:"
    end

    it "should state that it is redirecting to Goji if user is on supported device {iPhone}" do
      @request.user_agent = "Mozilla/5.0 (iPhone; CPU iPhone OS 8_0 like Mac OS X) AppleWebKit/600.1.3 (KHTML, like Gecko) Version/8.0 Mobile/12A4345d Safari/600.1.4"
      get(:go)
      msg =  @controller.instance_variable_get("@msg")
      assert_equal msg, "Redirecting to Goji app... if the application doesn't open automatically, click the button below:"
    end

    #
    # Device Confirmation
    #
    it "should confirm a device" do
      @user, @device, user_device = make_user()
      @ud = make_user_device(@user, @device, "nosuchtoken")
      assert @ud.confirmation_token.present?, "should have a confirmation token"
      get(:device_confirmation, id: @ud.id, device_confirmation_token: @ud.confirmation_token)
      @ud.reload
      assert @ud.confirmed_at.present?,  "should have a confirmed_at time"
      assert_equal nil, @ud.confirmation_token
      assert_response :success
    end

    it "should not confirm a device with an invalid token" do
      @user, @device, user_device = make_user()
      @ud = make_user_device(@user,  @device, "nosuchtoken")
      get(:device_confirmation, id: @ud.id, device_confirmation_token: "incorrecttoken")
      assert_response :not_found
    end

  end

end
