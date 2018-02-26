require "test_helper"
class DeviceTest < MiniTest::Unit::TestCase

  describe Device do

    before do
      DatabaseCleaner.start
      @user, @device1, @user_device1  = make_user()
      @device, @user_device       = make_device(@user)
    end

    after do
      DatabaseCleaner.clean
      ActiveSupport::TestCase.device_start_count = 0
    end

    subject { @device }

    it "should save a device" do
      assert @device
    end

    it "should create user_devices when different users create user_devices with the same device" do
      original_id    = @user.user_devices.first.id
      original_token = @device.ua_token
      @user2, dev2, user_device2 = make_user("anothertester@example.com")
      # make_user now creates a device automatically, as it's required.
      # make_device makes with a different ua_token
      device2, user_device2    = make_device(@user2)
      assert_equal     device2.ua_token, original_token
      assert_not_equal @user2.user_devices.first.id,    original_id
      assert_equal ActiveSupport::TestCase.device_start_count, Device.all.count
    end

    it "should create user_devices when different users create user_devices with the same unidentified iosdevelopment device" do
      original_id    = @user.user_devices.first.id
      @device.ua_token = nil
      @device.save!
      # make_user now creates a device automatically, as it's required.
      @user2, dev2, user_device2 = make_user("anothertester@example.com")
      # make_device makes with a different ua_token, dummy "isodevelopment" device_type
      device2, user_device2       = make_device(@user2, nil)
      assert_equal     device2.ua_token, nil
      assert_not_equal @user2.user_devices.first.id,    original_id
      assert_equal ActiveSupport::TestCase.device_start_count, Device.all.count
    end

    it "should create user_devices when different users create user_devices with the same unidentified android device" do
      original_id    = @user.user_devices.first.id
      @device.ua_token = nil
      @device.save!
      @user2, dev, user_dev = make_user("anothertester@example.com")
      device2, user_device2 = make_device(@user2, nil)
      assert_equal     device2.ua_token, nil
      assert_equal     device2.device_type, "iosdevelopment"
      device3 =        Device.create(device_type: "android")
      assert_not_nil   device3, "android device created"
      assert_nil       device3.ua_token, "nil ua_token"
      assert_equal     device3.device_type, "android"
      assert_not_equal @user2.user_devices.first.id,    original_id
      assert_equal ActiveSupport::TestCase.device_start_count, Device.all.count - 1
    end

    it "should register device against AWS on create" do
      assert @device.endpoint_arn.present?, "endpoint ARN not present"
      assert @device.endpoint_arn.start_with?("arn:aws:sns"), "endpoint ARN nor correct"
    end

    it "has a scope that should fetch only pushable devices" do
      assert Device.pushable.include?(@device), "should include the device to start off with"

      @device.endpoint_disabled_at = 1.day.ago
      @device.save!
      assert_not Device.pushable.include?(@device), "disabled devices should not be included"

      @device.endpoint_disabled_at = nil
      @device.endpoint_arn = nil
      @device.save!
      assert_not Device.pushable.include?(@device), "devices without arn should not be included"
    end

    it "should clear endpoint_updated_at on update_push_endpoint" do
      @device.endpoint_disabled_at = 1.day.ago
      @device.update_push_endpoint
      assert_equal nil, @device.endpoint_disabled_at
    end

=begin
    # This functionality is currently disabled, see device.rb
    it "should reset the apn badge successfully" do
      assert @device.respond_to? :reset_apn_badge!
      ua_response = @device.reset_apn_badge!
      assert ua_response.success?, 'airship push was not a success'
      assert ua_response.has_key?("push_ids")
    end
=end

  end
end
