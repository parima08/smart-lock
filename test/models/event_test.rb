require "test_helper"

class EventTest < MiniTest::Unit::TestCase

  describe Event do


    before do
      DatabaseCleaner.start
      @user, @device, @user_device = make_user
      @lock        = make_lock(@user)
      @key         = make_key(@lock, @user)
      @user2, @device2, @user_device2 = make_user('glenn2@example.com', 'aba456', false, "Glenn", "Widener")
      make_admin_user(@lock, @user2)
      lu = LocksUser.all.order('created_at ASC')
      # This isn't quite our reply format, but it parses, can be
      # compared to db, and tests enough resolution.
      # @event_time = DateTime.now.iso8601(6)
      @event_time = DateTime.now.utc.iso8601(3)
    end

    after do
      DatabaseCleaner.clean
    end

    def check_notification(record, event, to_user, is_admin)
      n_data = {
        user_id: to_user.id,
        lock_id: @event.lock_id,
        key_id: @event.key_id,
        event_id: @event.id,
        # Can't check extra here because it's not a persisted field.
        # Can only check that the password showed up in the email message.
        # Upgrade and refactor notification_test so we can test it there.
        # :extra    => @event.extra,
        # false is ok too
        admin: is_admin ? true : nil,
        # XXX test message (at least existence), picture_id.
      }
      check_data(record, n_data, nil, false,
                 # unused:
                 [:read_date, :recipient,
                 # needs checking at least once per above
                  :picture_id]);
    end

    def check_event(event)
      assert event.valid?, 'should be valid'
      start = event.event_type + (event.key ? " " : event.lock ? " on " : " for ")
      assert event.name.start_with?(start), "event.name misconstructed"
    end

    def check_invalid_event(event, bad_field = nil, count = 1)
      assert !event.valid?, 'should be invalid'
      assert(event.errors.get(bad_field), "wrong field reported in error") if bad_field
      assert event.errors.count == count, "Make sure we are failing on exactly " + count.to_s + " error(s) at a time: got " + event.errors.count.to_s + " errors: " + event.errors.messages.to_s
    end

    subject { @event }

    it "should create a valid event object" do
      @event = Event.create(lock_id: @lock.id,
                            key_id: @key.id,
                            event_time: @event_time,
                            event_type: EventType::UNLOCK,
                            string_value: CommandResult::SUCCESS,
                            bolt_state: BoltState::UNLOCKED,
                            )
      check_event(@event)
    end

    # The lock reports use of a physical key by no key_id.
    it "should create a lock event with no key" do
      @event = Event.create(lock_id: @lock.id,
                            event_time: @event_time,
                            event_type: EventType::LOCK,
                            string_value: CommandResult::SUCCESS,
                            bolt_state: BoltState::LOCKED,
                         )
      check_event(@event)
    end

    it "should not create a event object with invalid event_type string" do
      @event = Event.create(lock_id: @lock.id,
                            key_id: @key.id,
                            event_time: @event_time,
                            event_type: "foo")
      check_invalid_event(@event, :event_type)
    end

    it "should not create a event object without a lock_id" do
      @event = Event.create(key_id: @key.id,
                            event_time: @event_time,
                            event_type: EventType::BATTERY,
                            string_value: BatteryState::LOW)
      check_invalid_event(@event, :lock)
    end

    it "should not create an event without an event_type" do
      @event = Event.create(lock_id: @lock.id,
                            key_id: @key.id,
                            event_time: @event_time,
                            string_value: BatteryState::LOW)
      # Also fires string_value error because correct values depend on type.
      check_invalid_event(@event, :event_type, 2)
    end

    it "should not create an event without an event_time" do
      @event = Event.create(lock_id: @lock.id,
                            key_id: @key.id,
                            event_type: EventType::BATTERY,
                            string_value: BatteryState::LOW)
      check_invalid_event(@event, :event_time)
    end

    it "should not create a event object with a invalid lock_id" do
      @event = Event.create(lock_id: 0,
                            key_id: @key.id,
                            event_time: @event_time,
                            event_type: EventType::BATTERY,
                            string_value: BatteryState::LOW)
      check_invalid_event(@event, :lock)
    end

    it "should not create a lock event object with a invalid key_id" do
      @event = Event.new(lock_id: @lock.id,
                         key_id: 123123,
                         event_time: @event_time,
                         event_type: EventType::LOCK,
                         string_value: CommandResult::SUCCESS,
                         bolt_state: BoltState::LOCKED,
                         )
      check_invalid_event(@event, :key)
    end

    it "should not create a event object with a invalid user_id" do
      user3, dev, user_dev  = make_user('glenn3@example.com', 'aba456', false, "G", "W")
      make_admin_user(@lock, user3)
      @event = Event.new(lock: @lock,
                         user_id: 123123,
                         admin: user3,
                         event_time: @event_time,
                         event_type: EventType::ADMIN_SHARED,
                         bolt_state: BoltState::LOCKED,
                         )
      check_invalid_event(@event, :user)
    end
    it "should not create a event object with a invalid admin_user_id" do
      user3, dev, user_dev = make_user('glenn3@example.com', 'aba456', false, "G", "W")
      @event = Event.new(lock: @lock,
                         user: user3,
                         admin_user_id: 123123,
                         event_time: @event_time,
                         event_type: EventType::ADMIN_SHARED,
                         bolt_state: BoltState::LOCKED,
                         )
      check_invalid_event(@event, :admin, 2)
    end

    it "should not create a event object with an invalid event_time" do
      @event = Event.create(lock_id: @lock.id,
                            key_id: @key.id,
                            event_time: nil,
                            event_type: EventType::UNLOCK,
                            string_value: CommandResult::SUCCESS,
                            bolt_state: BoltState::UNLOCKED,
                            )
      check_invalid_event(@event, :event_time)
    end

    it "should not create a event object with an invalid bolt_state" do
      @event = Event.create(lock_id: @lock.id,
                            key_id: @key.id,
                            event_time: @event_time,
                            event_type: EventType::UNLOCK,
                            string_value: CommandResult::SUCCESS,
                            bolt_state: "junk",
                            )
      check_invalid_event(@event)
    end

    it "should not create a lock event with empty bolt_state string" do
      @event = Event.create(lock_id: @lock.id,
                            key_id: @key.id,
                            event_time: @event_time,
                            event_type: EventType::UNLOCK,
                            string_value: CommandResult::SUCCESS,
                            bolt_state: "",
                            )
      # separate blank and not-in-enum errors
      check_invalid_event(@event, :bolt_state)
    end

    it "should not create a lock event with missing bolt_state string" do
      @event = Event.create(lock_id: @lock.id,
                            key_id: @key.id,
                            event_time: @event_time,
                            event_type: EventType::UNLOCK,
                            string_value: CommandResult::SUCCESS,
                            )
      # separate blank and not-in-enum errors
      check_invalid_event(@event, :bolt_state)
    end

    it "should update user_account_id on save" do
      @event = Event.create(lock_id: @lock.id,
                            key_id: @key.id,
                            event_time: @event_time,
                            event_type: EventType::UNLOCK,
                            string_value: CommandResult::SUCCESS,
                            )
      assert_equal @event.user_account_id,  @event.user_id
      user2, dev, user_dev = make_user
      @event.user_id =  user2.id
      @event.save
      assert_equal @event.user_account_id,  @event.user_id
    end

    it "should ignore invalid user_id in types that ignore it" do
      @event = Event.new(lock_id: @lock.id,
                         key_id: @key.id,
                         user_id: 123123,
                         event_time: @event_time,
                         event_type: EventType::LOCK,
                         string_value: CommandResult::SUCCESS,
                         bolt_state: BoltState::LOCKED,
                         )
      assert @event.valid?
    end

    it "should mark as null any foreign keys set as zero" do
      @event = Event.create(lock_id: @lock.id,
                            key_id:  0,
                            user_id: 0,
                            picture_id: 0,
                            admin_user_id: 0,
                            event_time: @event_time,
                            event_type: EventType::UNLOCK,
                            string_value: CommandResult::SUCCESS,
                            bolt_state: BoltState::UNLOCKED,
                            )
      assert @event.valid?
      assert_equal nil, @event.key_id
      assert_equal nil, @event.user_id
      assert_equal nil, @event.picture_id
      assert_equal nil, @event.admin_user_id
    end

    # Need to clarify the deny event before this can be for sure true
    # it "should not create a event object with an key-lock mismatch" do
    #   @event = Event.create(
    #                         key_id: @key.id,
    #                         lock_id: 0,
    #                         event_time: @event_time,
    #                         event_type: "access",
    #                         string_value: "unlock")
    #   assert !@event.valid?
    # end

    # Possible future test, but only if we know the initiating user always matches the key
    #it "should not create a event object with an key-user mismatch" do
    #  @event = Event.create(key_id: @key.id,
    #                        user_id: 0,
    #                        event_time: @event_time,
    #                        event_type: "access",
    #                        string_value: "unlock")
    #  assert !@event.valid?
    #end

    it "should fill in user when given a key for access event" do
      event_data = {
        lock_id: @lock.id,
        key_id: @key.id,
        event_time: @event_time,
        event_type: EventType::UNLOCK,
        string_value: CommandResult::SUCCESS,
        bolt_state: BoltState::UNLOCKED,
      }
      @event = Event.create(event_data)
      check_event(@event)
      assert_equal @key.user_id, @event.user_id
      check_data(@event, event_data, nil, false,
                 [:int_value, :admin_user_id, :picture_id])
    end

    it "should not fill in a user when one is specified" do
      # This used during the grant process, where the granting user is different than the key user
      user3, dev, user_dev  = make_user('glenn3@example.com', 'aba456', false, "G", "W")
      @key3 = make_guest_key(@lock, user3.account.email, @user2)
      event_data = add_extra_data({
        lock_id: @lock.id,
        key_id: @key3.id,
        event_time: @event_time,
        user_id: @user2.id,
        event_type: EventType::KEY_SHARED,
      })
      assert_difference "Notification.count", 2, 'wrong number of notifications created, 2 expected' do
        @event = Event.create(event_data)
      end
      check_event(@event)
      check_data(@event, event_data, nil, false,
                 [:string_value, :int_value, :admin_user_id, :picture_id])
      # XXX test sharing by different user than lock owner
      ns = Notification.all.order('created_at ASC')
      n_guest = ns[ns.length-2]
      # Order undefined by spec, but assume code fires affected user
      # owner+admins (o+a order undefined).
      nt      = ns[ns.length-1]
      log_notification(n_guest)
      log_notification(nt)
      check_notification(nt,      @event, @user, true)
      check_notification(n_guest, @event, user3, false)
    end

    #XXX keep cleaning up and checking notifications below.

    it "should create a notification and update lock record on access, unlocked"  do
      # obsolete notify_*
      @lock.notify_unlocked = true
      @lock.save!
      assert_difference "Notification.count", 1, 'wrong number of notifications created, 1 expected' do
        @event = Event.create(lock_id: @lock.id,
                              key_id: @key.id,
                              event_time: @event_time,
                              event_type: EventType::UNLOCK,
                              string_value: CommandResult::SUCCESS,
                              bolt_state: BoltState::UNLOCKED,
                              )
      end
      check_event(@event)
      @lock.reload
      nt = Notification.last
      log_notification(nt)
      assert nt.key == @event.key, 'keys match'
      assert nt.key.lock == @lock, 'locks match'
      assert_not_equal nt.user_id, nt.key.user_id, 'initiator of event should not get notification'
    end

    it "should create a notification and update lock record on access, lock event"  do
      @lock.notify_locked = true
      @lock.save!
      assert_difference "Notification.count", 1, 'wrong number of notifications created, 1 expected' do
        @event = Event.create(lock_id: @lock.id,
                              key_id: @key.id,
                              event_time: @event_time,
                              event_type: EventType::LOCK,
                              string_value: CommandResult::SUCCESS,
                              bolt_state: BoltState::LOCKED,
                              )
      end
      check_event(@event)
      @lock.reload
      nt = Notification.last
      log_notification(nt)
      assert nt.key == @event.key, 'keys match'
      assert nt.key.lock == @lock, 'locks match'
      assert_not_equal nt.user_id, nt.key.user_id, 'initiator of event should not get notification'
    end

    it "should save the uuid on all created objects- Notification" do
      @key.uuid = "90bc960e-0888-4a6a-88c2-913335cb3418"
      @key.save!
      assert_difference "Notification.count", 1, 'wrong number of notifications created, 1 expected' do
        @event = Event.create(lock_id: @lock.id,
                              key_id: @key.id,
                              event_time: @event_time,
                              event_type: EventType::UNLOCK,
                              string_value: CommandResult::SUCCESS,
                              bolt_state: BoltState::UNLOCKED,
                              uuid: @key.uuid
                              )
      end
      notif = Notification.last
      assert_equal @event.uuid, notif.uuid
    end

    it "should create a notification when requested by unlock, denied/INVALID_KEY"  do
      # obsolete notify_*
      @lock.notify_denied = true
      @lock.save!
      assert_difference "Notification.count", 1, 'wrong number of notifications created, 1 expected' do
        @event = Event.create(lock_id: @lock.id,
                              key_id: @key.id,
                              event_time: @event_time,
                              event_type: EventType::UNLOCK,
                              string_value: CommandResult::INVALID_KEY,
                              bolt_state: BoltState::LOCKED,
                              )
      end
      check_event(@event)
      nt = Notification.last
      log_notification(nt)
      assert nt.key == @event.key, 'keys match'
      assert nt.key.lock == @lock, 'locks match'
      assert_equal @event.user_id, @key.user_id, 'user_ids match'
    end

    it "should create a notification on access_changed event by an admin" do
      user3, dev, user_dev = make_user('glenn3@example.com', 'aba456', false, "G", "W")
      @key3       = make_guest_key(@lock, user3.account.email, @user)
      event_data = add_extra_data({
        lock_id: @lock.id,
        user_id: @user2.id,
        key_id: @key3.id,
        event_time: @event_time,
        event_type: EventType::ACCESS_CHANGED,
      })
      assert_difference "Notification.count", 2, 'wrong number of notifications created, 2 expected' do
        @event = Event.create(event_data)
      end
      check_event(@event)
      check_data(@event, event_data, nil, false,
                 [:string_value, :int_value, :picture_id])
      ns = Notification.all.order('created_at ASC')
      nt_target = ns[ns.length-2]
      nt        = ns[ns.length-1]
      log_notification(nt_target)
      log_notification(nt)
      check_notification(nt_target, @event, user3, false)
      check_notification(nt,        @event, @user, true)
    end

    it "should create a notification on admin shared event"  do
      user3, dev, user_dev = make_user('glenn3@example.com', 'aba456', false, "G", "W")
      # Also test admin privileges
      event_data = add_extra_data({
        lock_id: @lock.id,
        user_id: @user.id,
        event_time: @event_time,
        event_type: EventType::ADMIN_SHARED,
        admin_user_id: user3.id
      })
      assert_difference "Notification.count", 2, 'wrong number of notifications created, 2 expected' do
        @event = Event.create(event_data)
      end
      check_event(@event)
      check_data(@event, event_data, nil, false,
                 [:key_id, :string_value, :int_value, :picture_id])
      ns = Notification.all.order('created_at ASC')
      nt_target = ns[ns.length-2]
      nt        = ns[ns.length-1]
      log_notification(nt_target)
      log_notification(nt)
      check_notification(nt_target, @event, user3, false)
      check_notification(nt,        @event, @user2, true)
    end

    # admin revoked by an admin not currently allowed from UI, but tested here.
    it "should create target user and owner notification on admin_revoked event by other admin"  do
      user3, dev, user_dev = make_user('glenn3@example.com', 'aba456', false, "G", "W")
      make_admin_user(@lock, user3)
      event_data = add_extra_data({
        lock_id: @lock.id,
        user_id: @user2.id,
        admin_user_id: user3.id,
        event_time: @event_time,
        event_type: EventType::ADMIN_REVOKED,
      })
      # notification to user losing admin, not to lock owner who performed the action
      assert_difference "Notification.count", 2, 'wrong number of notifications created, 2 expected' do
        @event = Event.create(event_data)
      end
      check_event(@event)
      check_data(@event, event_data, nil, false,
                 [:key_id, :string_value, :int_value, :picture_id])
      ns = Notification.all.order('created_at ASC')
      nt_target = ns[ns.length-2]
      nt        = ns[ns.length-1]
      log_notification(nt_target)
      log_notification(nt)

      # Order undefined by spec, but assume code fires affected user
      # then owner+admins (o+a order undefined).
      check_notification(nt_target, @event, user3, false)
      check_notification(nt,        @event, @user, true)
    end

    it "should create target user notification on admin_revoked event"  do
      event_data = add_extra_data({
        lock_id: @lock.id,
        user_id: @user.id, # lock owner
        admin_user_id: @user2.id,
        event_time: @event_time,
        event_type: EventType::ADMIN_REVOKED,
      })
      # notification to user losing admin, not to lock owner who performed the action
      assert_difference "Notification.count", 1, 'wrong number of notifications created, 1 expected' do
        @event = Event.create(event_data)
      end
      check_event(@event)
      check_data(@event, event_data, nil, false,
                 [:key_id, :string_value, :int_value, :picture_id])
      nt_target = Notification.last
      check_notification(nt_target, @event, @user2, false)
    end

    # Test case for admin removing their own admin privileges is not possible from UI, so no test case required.

    it "should create a notification when requested by battery low"  do
      assert_difference "Notification.count", 2, 'wrong number of notifications created, 2 expected' do
        @event = Event.create(lock_id: @lock.id,
                              event_time: @event_time,
                              event_type: EventType::BATTERY,
                              string_value: BatteryState::LOW)
      end
      check_event(@event)
      assert_equal nil, @event.user_id, "should not have user for battery event"
      nt = Notification.last
      log_notification(nt)
      assert nt.lock == @lock
    end

    it "should create a notification when requested by wifi down"  do
      assert_difference "Notification.count", 2, 'wrong number of notifications created, 2 expected' do
      @event = Event.create(lock_id: @lock.id,
                            event_time: @event_time,
                            event_type: EventType::LOCK_COM,
                            string_value: LockCommState::LOCK_COMM_DOWN)
      end
      check_event(@event)
      nt = Notification.last
      log_notification(nt)
      assert nt.lock == @lock
    end

    it "should create a notification when requested by wifi up"  do
      assert_difference "Notification.count", 2, 'wrong number of notifications created, 2 expected' do
      @event = Event.create(lock_id: @lock.id,
                            event_time: @event_time,
                            event_type: EventType::LOCK_COM,
                            string_value: LockCommState::LOCK_COMM_UP)
      end
      check_event(@event)
      nt = Notification.last
      log_notification(nt)
      assert nt.lock == @lock
    end

    it "should create notifications on proximity event"  do
      event_data = add_extra_data({
        lock_id: @lock.id,
        event_time: @event_time,
        event_type: EventType::PROXIMITY ,
        string_value: ProximityEventType::INTO
      })
      assert_difference "Notification.count", 2, 'wrong number of notifications created, 2 expected' do
        @event = Event.create(event_data)
      end
      check_event(@event)
      check_data(@event, event_data, nil, false,
                 [:key_id, :int_value, :picture_id])
      ns = Notification.all.order('created_at ASC')
      nt       = ns[ns.length-2]
      nt_admin = ns[ns.length-1]
      # admin not different.
      log_notification(nt)

      # Order undefined by spec, but assume code fires affected user
      # then owner+admins (o+a order undefined).
      which = nt[:user_id] == @user
      check_notification(nt,       @event, which ? @user : @user2, true)
      check_notification(nt_admin, @event, which ? @user2 : @user, true)
    end

    it "should ignore zeros on parameters" do
      # Firmware team often sends a zero if there's nothing being sent for the parameter
      # Result of using sprintf in C to build the HTTP payloads
      @event = nil
      assert_difference "Notification.count", 2, 'wrong number of notifications created, 2 expected' do
        assert_difference "Event.count", +1 do
          @event = Event.create(add_extra_data({
                     lock_id: @lock.id,
                     event_time: @event_time,
                     event_type: EventType::BATTERY,
                     string_value: BatteryState::OK,
                     user_id: 0,
                     key_id:  0,
                  }))
        end
      end
      check_event(@event)
      assert_equal nil, @event.user
      assert_equal nil, @event.key
      nt = Notification.last
      log_notification(nt)
      assert nt.lock == @lock
    end

    # XXX add tests for key_revoked/expired
    # Test duplicate/event triggering user notification suppression (event.rb):
    # - owner+admin, owner revokes admin, owner doesn't get message (DONE)
    # - owner+admin, admin unlocks, admin only gets primary message
    # - key_revoked, revoking user does not get message.
    # - failed lock: key owner DOES get the message!

    # XXX validate notification message and email contents, esp. inserted values
  end
end
