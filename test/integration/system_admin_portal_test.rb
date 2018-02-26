require "test_helper"

class SystemAdminPortalTest < ActionDispatch::IntegrationTest
  test "that the admin portal does not allow access without signin" do
    get '/admin/'
    assert_redirected_to '/accounts/sign_in'
  end
end
