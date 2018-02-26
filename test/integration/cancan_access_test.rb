require "test_helper"

class Alpha2DeviceLoginFlowTest < ActionDispatch::IntegrationTest

  before do
    @account = make_account(email: 'person@example.com', password: 'aba456', admin: true)
  end

  test "testing stuff...." do
    @account.roles = ["customer_support"]
    post('/accounts/sign_in', { 
      "account[email]" => @account.email, 
      "account[password]" => @account.password 
      })
    get('/admin')
    get('/admin/lock')
    #denied
    byebug
    @result = @response.body
    #loop through all the models and try to access them
  end

  #check that having both roles are honored when a person has 
  #two roles

end
