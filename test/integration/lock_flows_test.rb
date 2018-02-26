require "test_helper"

class LockFlowsTest < ActionDispatch::IntegrationTest

  before do
    @owner, @device, @user_device = make_user('owner@example.com')
    @lock = make_lock(@owner)
    @key  = make_key(@lock, @owner)
  end

  test "updates to lock name should be reflected by keys" do
    # Regression test for LP BUG 19248223

    put("/locks/#{@lock.id}", {name: "My New Lock Name"},
         {  'Authorization' => make_auth_token_string(@user_device.authentication_token),
             ApplicationController::make_header_name("user_device_id") => @user_device.id.to_s
         })
    assert_response :success

    # See that it was updated in the DB
    assert_equal "My New Lock Name", @lock.reload.name

    # See that it was updated in the lock listing
    get('/locks', {},
        {  'Authorization' => make_auth_token_string(@user_device.authentication_token),
            ApplicationController::make_header_name("user_device_id") => @user_device.id.to_s
        })

    # See that the lock name is correct in key listing
    get('/keys', {},
       {  'Authorization' => make_auth_token_string(@user_device.authentication_token),
            ApplicationController::make_header_name("user_device_id") => @user_device.id.to_s
        })

    body = JSON.parse(@response.body).first
    result, key_info = get_keys_from_signed_response_body(body)
    assert_equal "My New Lock Name", key_info["name"]
  end

end
