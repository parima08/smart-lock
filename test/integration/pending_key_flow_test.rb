require "test_helper"

class PendingKeyFlowTest < ActionDispatch::IntegrationTest
  before do
    @owner, @own_device, @own_user_device = make_user('owner@example.com')
    @lock = make_lock(@owner)
    @user, @device, @user_device = make_user('user@example.com')
  end

  test "share key and verify pending status changes" do

    # Share the key
    assert_difference ["Event.count", "ActionMailer::Base.deliveries.size"], 1 do
      post("/keys",
        {
          lock_id: @lock.id,
          email: @user.account.email,
          admin: true
        },
        {  'Authorization' => make_auth_token_string(@own_user_device.authentication_token),
            ApplicationController::make_header_name("user_device_id") => @own_user_device.id.to_s
        })
      check_response
    end

    # Check if we got the right email
    mail = ActionMailer::Base.deliveries.last
    assert_match /has invited you to access/, mail.body.to_s

    # Check if we got the right notification message
    assert_match /has invited you to access/, Notification.last.message

    # See that the owner sees it as pending
    get("/locks", {},
        {  'Authorization' => make_auth_token_string(@own_user_device.authentication_token),
            ApplicationController::make_header_name("user_device_id") => @own_user_device.id.to_s
        })
    locks_result = JSON.parse(@response.body)
    assert_equal true, locks_result.first["keys"].first['key_info']['pending']

    # User fetches the key.
    get('/keys', {},
        {  'Authorization' => make_auth_token_string(@user_device.authentication_token),
            ApplicationController::make_header_name("user_device_id") => @user_device.id.to_s
        })
    body = JSON.parse(@response.body).first
    keys_result, key_info = get_keys_from_signed_response_body(body)
    assert_equal @lock.id, keys_result['lock_id']

    # See that the owner no longer sees it as pending
    get('/locks', {},
       {  'Authorization' => make_auth_token_string(@own_user_device.authentication_token),
           ApplicationController::make_header_name("user_device_id") => @own_user_device.id.to_s
        })
    locks_result = JSON.parse(@response.body)
    assert_equal false, locks_result.first['keys'].first['key_info']['pending']
  end
end
