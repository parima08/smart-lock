require "test_helper"

class UserDevicesTest < ActiveSupport::TestCase
  describe Device do
    before do
      DatabaseCleaner.start
      # Makes a confirmed account with device and user_device
      @user, @device, @user_device = make_user
    end

    after do
      DatabaseCleaner.clean
    end

    subject { @user_device }

    it "should create user_device record" do 
      assert @user_device
      assert_equal @device.id, @user_device.device_id
      assert_not_nil @user_device.authentication_token, "authentication_token is nil"
    end

    it "should send email and push notification to confirm device" do
      assert_difference ["Event.count","Notification.count","ActionMailer::Base.deliveries.count"], +1 do
        ud = UserDevice.create!(user: @user, device: @device)
        ud.create_confirmation_event
      end
      assert_equal @user.notifications.first.event.event_type, "user_device_confirmed"
    end

    it "should not have a confirmation token on creation" do
      assert @user_device.confirmation_token.nil?, "confirmation_token should not be nil"
    end

    it "should be confirmed" do
      assert @user_device.confirmed_at.present?, "should be confirmed"
    end

    it "should be able to mark as confirmed" do
      @user_device.confirmed_at = nil
      @user_device.save!
      @user_device.mark_as_confirmed
      @user_device.save!
      @user_device.reload
      assert_not_nil @user_device.confirmed_at, "not marked confirmed"
      assert_nil @user_device.confirmation_token, "non-nil confirmation_token"
    end

    it "scope active should only return authenticated devices" do
      @user_device.update!(confirmed_at: 1.day.ago,
                           authenticated_at: nil)
      assert_equal 0, UserDevice.active.count

      @user_device.update!(authenticated_at: Time.now)
      assert_equal @user_device, UserDevice.active.first
    end

    it "scope active should not return decomissioned devices" do
      @user_device.update!(confirmed_at:      1.day.ago,
                           authenticated_at:  1.day.ago,
                           decommissioned_at: 1.day.ago)
      assert_equal 0, UserDevice.active.count

      @user_device.update!(decommissioned_at: nil)
      assert_equal @user_device, UserDevice.active.first
    end

    it "scope active should only return confirmed devices" do
      @user_device.update!(confirmed_at:     nil,
                           authenticated_at: 1.day.ago)
      assert_equal 0, UserDevice.active.count

      @user_device.update!(confirmed_at: Time.now)
      assert_equal @user_device, UserDevice.active.first
    end

  end
end
