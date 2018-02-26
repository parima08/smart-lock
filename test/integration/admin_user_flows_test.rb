require "test_helper"

class AdminUserFlowsTest < ActionDispatch::IntegrationTest

  before do
    @owner, @own_device, @own_user_device = make_user('owner@example.com')
    @admin,  @adm_device, @adm_user_device= make_user('admin@example.com')
    @lock = make_lock(@owner)
  end

  test "share admin access with an existing user" do
    # Owner shares with us
    assert_difference [ "Event.count", 'ActionMailer::Base.deliveries.size'], @@mail_count * 1 do
      post("/keys",
         {
           lock_id: @lock.id,
           email: @admin.account.email,
           admin: true
         },
         {  'Authorization' => make_auth_token_string(@own_user_device.authentication_token),
             ApplicationController::make_header_name("user_device_id") => @own_user_device.id.to_s
         })
      check_response
    end

    key = Key.last
    evs = Event.all.order('created_at ASC')
    check_key_shared_event(evs.last, key, @owner)

    # Verify we now have a lock and a key for the lock
    get('/keys', {},
        {  'Authorization' => make_auth_token_string(@adm_user_device.authentication_token),
             ApplicationController::make_header_name("user_device_id") => @adm_user_device.id.to_s
         })
    body = JSON.parse(@response.body).first
    keys_result, key_info = get_keys_from_signed_response_body(body)
    assert_equal @lock.id, keys_result["lock_id"]

    get('/locks', {},
         {  'Authorization' => make_auth_token_string(@adm_user_device.authentication_token),
             ApplicationController::make_header_name("user_device_id") => @adm_user_device.id.to_s
         })
    locks_result = JSON.parse(@response.body)
    assert_equal 1, locks_result.length
    assert_equal @lock.id, locks_result.first["id"]

    # Verify the owner sees the admin shared event
    get('/events', {},
         {  'Authorization' => make_auth_token_string(@own_user_device.authentication_token),
             ApplicationController::make_header_name("user_device_id") => @own_user_device.id.to_s
         })
    events_result = JSON.parse(@response.body)
    assert_equal @owner.id, events_result.first["user_id"] # Owner triggered event
    assert_equal 'key_shared', events_result.first["event_type"]
  end

  test "upgrade user with existing access to admin" do
    # Share a normal key
    assert_difference [ "Event.count", 'ActionMailer::Base.deliveries.size'], @@mail_count * 1 do
      post("/keys",
          {
            lock_id: @lock.id,
            email: @admin.account.email
          },
          {  'Authorization' => make_auth_token_string(@own_user_device.authentication_token),
             ApplicationController::make_header_name("user_device_id") => @own_user_device.id.to_s
         })
      check_response
    end

    puts 'Existing Key Done'

    # Grab the key ID
    key_result = JSON.parse(@response.body)
    assert_not_nil key_result["key_data"]
    key_id = key_result["key_data"]["id"]
    assert_not_nil key_id

    # Now upgrade use to an admin
    assert_difference [ "Event.count", 'ActionMailer::Base.deliveries.size'], @@mail_count * 1 do
      put("/keys/#{key_id.to_s}",
          {
            admin: true },
          {  'Authorization' => make_auth_token_string(@own_user_device.authentication_token),
             ApplicationController::make_header_name("user_device_id") => @own_user_device.id.to_s
         })
      check_response
    end

    # Verify we now have admin access
    get('/locks', {},
       {  'Authorization' => make_auth_token_string(@adm_user_device.authentication_token),
          ApplicationController::make_header_name("user_device_id") => @adm_user_device.id.to_s
        })
    locks_result = JSON.parse(@response.body)
    assert_equal 1, locks_result.length
    assert_equal @lock.id, locks_result.first["id"]

    # Verify we see the admin shared event
    get('/events', {},
        {  'Authorization' => make_auth_token_string(@own_user_device.authentication_token),
           ApplicationController::make_header_name("user_device_id") => @own_user_device.id.to_s
        })
    events_result = JSON.parse(@response.body)

    assert_equal @owner.id, events_result.first["user_id"] # Owner triggered event
    assert_equal 'admin_shared', events_result.first["event_type"]
  end

end
