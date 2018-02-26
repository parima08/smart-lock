require "test_helper"

# XXX Needs refactoring, we should be directly testing notifications,
# not testing events creation of notifications, e.g. so that we
# can check non-db extra field.
# These tests are redundant with, and weaker than, the tests in event_test.rb

class NotificationTest < MiniTest::Unit::TestCase

  describe Notification do

    before do
      DatabaseCleaner.start
      @user, @device, @user_device    = make_user
      @admin_user, @dadm_evice, @adm_user_device   = make_user('glenn2@example.com', 'aba456', false, "Glenn", "Widener")
      @guest_user, @gue_device, @gue_user_device   = make_user('glenn3@example.com', 'aba456', false, "guest", "user")
      @lock    = make_lock(@user)
      @key     = make_key(@lock, @user)
      make_admin_user(@lock, @admin_user)
      @event = Event.create!(lock_id: @lock.id,
                             event_type: EventType::BATTERY,
                             event_time: Time.now,
                             string_value: BatteryState::LOW,
                             )
      @notification = @event.notifications.first
    end

    after do
      DatabaseCleaner.clean
    end

    def check_notification(notification)
      assert notification.valid?, 'should be valid'
      assert notification.name.start_with?(notification.event.event_type), "notification.name misconstructed"
      assert @notification.message
    end

    subject { @notification }

    # shoulda matchers
    it "should create a notification object" do
      check_notification(@notification)
    end

    # Each value, but not NETWORK (firmware only, for possible later use)
    # LOCK/UNLOCK tested below
    # Other results tested in event_test.
    (EventType.values - [EventType::LOCK, EventType::UNLOCK, EventType::NETWORK]).each do |nt|
      string_value = nt == EventType::LOCK_COM ? LockCommState::LOCK_COMM_DOWN :
                     nt == EventType::BATTERY ? BatteryState::LOW :
                     nt == EventType::PROXIMITY ? ProximityEventType::INTO :
                     nil
      it "should create a message for event #{nt} #{string_value}" do
        @new_admin_user, device, user_device   = make_user('glenn4@example.com', 'aba456', false, "G", "W")
        # Note that user_id is ignored for wifi/battery/proximity/fail
        event = Event.create!(add_extra_data({
                              :user_id           => @user.id,
                              :lock_id           => @lock.id,
                              :key_id            => @key.id,
                              :admin_user_id     => @new_admin_user.id, # for admin_* only, ignored otherwise
                              :event_type        => nt,
                              :string_value      => string_value,
                              :event_time        => Time.now,
                             }))
        # Be sure to log all notifications for spec.
        # XXX check that the right extra notifications are generated.
        event.notifications.each do |nt|
          check_notification(nt)
          log_notification(nt)
        end
      end
    end

    # A basic test to make sure a message can be created
    # for each possible result state for a lock request
    # Many of these aren't really possible, e.g LOCK request failing
    # due to invalid key, ending up UNLOCKED...
    [EventType::LOCK, EventType::UNLOCK].each do |evtype|
      CommandResult.values.each do |nt|
        BoltState.values.each do |bolt|
          # Firmware not to report moving state
          next if bolt == "moving"
          it "should handle #{evtype} CommandResult state #{nt} and BoltState #{bolt}" do
            @key2    = make_guest_key(@lock, @guest_user.account.email, @user)
            event = nil
            assert_difference ["Event.count"], +1 do
              event = Event.create!(:lock_id           => @lock.id,
                                    :key_id            => @key2.id,
                                    :event_type        => evtype,
                                    :string_value      => nt,
                                    :event_time        => Time.now,
                                    :bolt_state        => bolt)
            end
            @notification = event.notifications.first
            check_notification(@notification)
            log_notification(@notification)
          end
        end
      end
    end

    # redundant?
    it "should create a message for unlock v2 event" do
      # Need another user, since no notification created for single user
      assert_difference "Notification.count", +1 do
        @event =        Event.create!(user_id: @user.id,
                                      lock_id: @lock.id,
                                      key_id: @key.id,
                                      event_type: EventType::UNLOCK,
                                      string_value: CommandResult::SUCCESS,
                                      bolt_state: BoltState::UNLOCKED,
                                      event_time: Time.now)
        @notification = @event.notifications.first
        @event.notifications.each do |nt|
          check_notification(nt)
          log_notification(nt)
        end
      end
    end

    it "should have a nice boolean method" do
      assert @notification.respond_to?(:nb), "missing notification.nb"
      assert_equal @notification.nb(false), "No"
      assert_equal @notification.nb(true), "Yes"
    end

    #XXX add test case for admin sharing of key
    it "should send_apn notification for user with devices " do
      # TODO this is kludgy, is it covered in event_test?
      @event.event_type = EventType::KEY_SHARED
      @event.event_time = Time.now
        notification = Notification.create!(add_extra_data({
                                          :user_id => @user.id,
                                          :lock_id => @lock.id,
                                          :key_id  => @key.id,
                                          :event_id => @event.id,
                                          }))

      check_notification_devices(notification, @user, 1, true)
      # remove when more complete check is in above call.
      attempts = notification.push_result
      assert_equal attempts.first.keys.first, @device.endpoint_arn

      check_notification(@notification)
      log_notification(notification)
    end


    it "should send push notification for user with multiple devices" do
      device, user_device = make_confirmed_device(@user)
      device2, user_device2 = make_confirmed_device(@user,'aaaaaaaaaaaaaaaaaaadc2d6da1f2781e8b74d39b49c1e521108db9109b1be35')
      @event.event_type = EventType::KEY_SHARED
      @event.event_time = Time.now
      notification = Notification.create!(add_extra_data({
	user_id:  @user.id,
	lock_id:  @lock.id,
	key_id:   @key.id,
	event_id: @event.id,
      }))
      check_notification_devices(notification, @user, 3, true)
    end

    it "should not send push notification to unconfirmed device" do
      @user_device.confirmed_at = nil
      @user_device.save
      @event.event_type = EventType::KEY_SHARED
      @event.event_time = Time.now
      notification = Notification.create!(add_extra_data({
	user_id:  @user.id,
	lock_id:  @lock.id,
	key_id:   @key.id,
	event_id: @event.id,
      }))
      check_notification_devices(notification, @user, 0, true)
    end

    it "should send email for user with key_revoked and key is nil" do
      @event1 = Event.create!(user_id: @user.id,
                              lock_id: @lock.id,
                              event_type: EventType::KEY_REVOKED,
                               event_time: Time.now,
                               string_value: nil,
                               )
        @event1.event_time = Time.now
        notification = Notification.create!(add_extra_data({
                                            :user_id => @user.id,
                                            :lock_id => @lock.id,
                                            :key_id  => nil,
                                            :event_id => @event1.id,
                                            }))
        check_notification(@notification)
        log_notification(notification)
    end

    it "should have a nice bool method to return true or false values" do
      assert_equal @notification.nb(false), "No"
      assert_equal @notification.nb(true),  "Yes"
    end

    it "should update user_account_id on save" do
      assert_equal @notification.user_account_id,  @notification.user_id
      user2, device, user_device = make_user
      @notification.user_id =  user2.id
      @notification.save
      assert_equal @notification.user_account_id,  @notification.user_id
    end

    it "should nilify any foreign keys set as zero" do
      @notification = Notification.new(
        lock_id: @lock.id,
        key_id: 0,
        user_id: @user,
      )
      @notification.valid?
      assert_equal nil, @notification.key_id
    end

    it "should not create a valid notification because string length exceeds 255 chars" do
      notification = Notification.create(add_extra_data({
                                          :user_id => @user.id,
                                          :lock_id => @lock.id,
                                          :key_id  => @key.id,
                                          :event_id => @event.id,
                                          :recipient => "lock",
                                          :message => "thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_"
                                          }))
      assert_equal false, notification.valid?
    end

  end
end
