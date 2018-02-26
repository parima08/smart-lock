require "test_helper"

class UtilityControllerTest < ActionController::TestCase

  describe UtilityController do

    subject { UtilityController }

    before do
      DatabaseCleaner.start
      @admin_user, @adm_device, @adm_user_device = make_user('gojiadmin@emmoco.com','aba456',true)
      @non_admin_user, @device, @user_device = make_user('gojiadmin@emmoco.com','aba456',false)
    end

    after do
      DatabaseCleaner.clean
    end

    it "should throw an exception upon request" do
      sign_in(@admin_user.account)
      errored = false
      begin
        get(:error)
      rescue
        errored = true
      end
      assert errored
    end

  end

end
