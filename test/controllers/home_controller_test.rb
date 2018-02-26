require "test_helper"

class HomeControllerTest < ActionController::TestCase


  subject { HomeController }

  before do
    DatabaseCleaner.start
    @routes = Rails.application.routes
    @user,@device, @user_device = make_user
    @lock = make_lock(@user)
    @key  = make_key(@lock, @user)
    sign_in(@user.account)
    get(:index)
  end

  after do
    DatabaseCleaner.clean
  end

  it "should exist" do
    assert @routes
    assert_response 200
  end

end
