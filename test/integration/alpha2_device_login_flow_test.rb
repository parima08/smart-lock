require "test_helper"

class Alpha2DeviceLoginFlowTest < ActionDispatch::IntegrationTest

  before do
    @owner, @device, @user_device = make_user('myalpha2user@example.com', 'aba456')
  end

  test "should be able to see that the user exists" do
    get '/users/' + @owner.account.email
    assert_response :unauthorized # Expected response if a user exists
  end

  test "should be able to register a new device w/no device id and login" do
    #
    # APP: Does login attempt
    #
    assert_difference ["Device.count", "UserDevice.count", "ActionMailer::Base.deliveries.count"], +1 do
      get('/authtoken', {
            # non-header credentials will get obsoleted.
            #email: @owner.account.email,
            #password: 'aba456',
          }, {
            'Authorization' => make_auth_string(@owner.account.email, 'aba456'),
            ApplicationController::make_header_name("device_type") => 'iosdevelopment',
          })
    end
    assert_response :success

    @result = JSON.parse(@response.body)
    assert @result["device_id"].present?, "should have a device_id" # We should have a device ID

    #
    # USER tries to confirm via link in email
    # TODO For fun, let's try and grab the confirmation token from the email (regex)
    # This would help prove the email has the right contents (which is what we want for an integration test)
    #
    email = ActionMailer::Base.deliveries.last
    url = store_device_confirmation_url(id: UserDevice.last.id, device_confirmation_token: UserDevice.last.confirmation_token, only_path: true)

    assert email.body.raw_source.include?(url), "does not contain confirmation URL"

    # Since the URL was found in the email, let's use it
    get url
    assert_response :success

    #
    # APP tries to login again
    #
    assert_no_difference ["Device.count", "UserDevice.count", "ActionMailer::Base.deliveries.count"] do
      get('/authtoken', {
            #email: @owner.account.email,
            #password: 'aba456',
            #device_id: @result["device_id"]
          }, {
            'Authorization' => make_auth_string(@owner.account.email, 'aba456'),
            ApplicationController::make_header_name("device_id") => @result["device_id"],
            ApplicationController::make_header_name("device_type") => 'iosdevelopment',
          })
    end
    assert_response :success
    @result2 = JSON.parse(@response.body)
    assert @result2["authtoken"].present?, "should have returned an auth token"
    #
    # App makes a normal API call
    #
    get("/users/#{@owner.account.email}", 
        {}, {  'Authorization' => make_auth_token_string(@result2["authtoken"]),
               ApplicationController::make_header_name("user_device_id") => @result2["user_device_id"].to_s
             })
    assert_response :success
    @result3 = JSON.parse(@response.body)
    assert_equal @owner.account.full_name, @result3["account"]["full_name"] # Shows we fetched the right record

  end

  test "should be able to login with an already active device" do

  end

end
