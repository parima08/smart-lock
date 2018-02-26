require "test_helper"

class LockTest < MiniTest::Unit::TestCase

  describe Lock do

    before do
      DatabaseCleaner.start
      @user, @device, @user_device  = make_user
      @lock        = make_lock(@user)
      @key         = make_key(@lock, @user)
    end

    after do
      DatabaseCleaner.clean
    end

    subject { @lock }

    it "should update sequence number on save" do
      current_sequence = @lock.seq_no
      @lock.name = "changed name"
      @lock.serial_label="my label"
      @lock.save!
      next_sequence   = @lock.seq_no
      assert current_sequence != next_sequence
      assert current_sequence + 1 == next_sequence
      assert_equal @lock.serial_label, "my label"
    end

    it "should update user_account_id on save" do
      assert_equal @lock.user_account_id,  @lock.user_id
      user2, dev, user_dev  = make_user
      @lock.user_id =  user2.id
      @lock.save
      assert_equal @lock.user_account_id,  @lock.user_id
    end

    it "should respond to sequence_number" do
      assert @lock.respond_to? :update_seq_no
      assert @lock.seq_no + 1 > @lock.seq_no
    end

    it "should reject invalid required_internal_version" do
      assert_raises ActiveRecord::RecordInvalid do
        set_field(:required_internal_version, "invalid")
      end
    end

    it "should reject invalid required_external_version" do
      assert_raises ActiveRecord::RecordInvalid do
        set_field(:required_external_version, "invalid")
      end
    end

    it "should accept valid required_internal_version" do
      make_dummy_firmware_versions()
      set_field(:required_internal_version, ActiveSupport::TestCase.INTERNAL_VERSION)
    end

    it "should accept valid required_external_version" do
      make_dummy_firmware_versions()
      set_field(:required_external_version, ActiveSupport::TestCase.EXTERNAL_VERSION)
    end

    # Lazy: a couple of Firmware validation tests here
    it "should reject invalid firmware record" do
      assert_raises ActiveRecord::RecordInvalid do
        Firmware.create!(version: "valid", for_external: "false",
                         download_url: "http://foo")
      end
    end
    it "should reject invalid firmware record" do
      assert_raises ActiveRecord::RecordInvalid do
        Firmware.create!(version: "valid",
                         download_url: "http://foo", data_file_name: "foo")
      end
    end

    def set_field(field, value)
      @lock.update_attribute(field, value)
      @lock.save!
    end

    it "should have a last_access method to return last access by any key for a lock" do
      assert_equal @lock.last_access, nil
      last_access    = Event.create(:key_id => @key.id,
                                    :event_type => EventType::LOCK,
                                    :string_value => "success",
                                    :event_time => Time.now)
      another_access = Event.create(:key_id => @key.id,
                                    :event_type => EventType::LOCK,
                                    :string_value => "success",
                                    :event_time => Time.now - 10000)
      #assert_equal 2, Event.all.count
      #assert_equal @lock.last_access, last_access.access_time
    end

    it "check_active should fire wifi down and up events" do
      # XXX use new time shifter instead to speed things up and eliminate this test_mode hack.
      # These tests are somewhat duplicated in locks_controller_test
      sleep 2
      Lock.test_mode = true
      Lock.check_active
      assert_equal 2, Event.all.count
      # Skip owner share event.
      ev = Event.all.order('created_at ASC')[1]
      assert_equal "wifi", ev.event_type
      assert_equal "down", ev.string_value
      assert_equal "up", @lock.reported_wifi_status
      @lock.reload
      assert_not_nil @lock.reported_wifi_time
      assert_equal "down", @lock.reported_wifi_status
      # No extra events
      sleep 2
      Lock.check_active
      assert_equal 2, Event.all.count

      @lock.bolt_state = "locked"
      @lock.save!
      before = DateTime.now
      Lock.check_active
      # Updates don't fire wifi events any more.
      assert_equal 2, Event.all.count
      # Only syncs.
      @lock.last_sync = DateTime.now
      @lock.save!
      Lock.check_active
      assert_equal 3, Event.all.count
      ev = Event.last
      assert_equal "wifi", ev.event_type
      assert_equal "up", ev.string_value
      @lock.reload
      assert_not_nil @lock.reported_wifi_time
      assert_operator before, :<, @lock.reported_wifi_time
      assert_equal "up", @lock.reported_wifi_status

      # Just one new down event
      sleep 2
      Lock.check_active
      assert_equal 4, Event.all.count
      ev = Event.last
      assert_equal "wifi", ev.event_type
      assert_equal "down", ev.string_value
      # No extra events
      sleep 2
      Lock.check_active
      assert_equal 4, Event.all.count
    end

    it "should find by id or serial" do
      @l2 = make_lock(@user)
      assert_equal @lock, Lock.by_id_or_lock_serial(@lock.id, nil).first
      assert_equal @l2, Lock.by_id_or_lock_serial(nil, @l2.lock_serial).first

      @lock.lock_serial = nil
      @lock.save!
      assert_equal nil, Lock.by_id_or_lock_serial(nil, nil).first
      assert_equal nil, @lock.serial_label
    end

    it "should find by id and serial, but only if they both match" do
      @l2 = make_lock(@user)
      assert_equal nil, Lock.by_id_or_lock_serial(@lock.id, @l2.lock_serial).first
      assert_equal @l2, Lock.by_id_or_lock_serial(@l2.id, @l2.lock_serial).first
    end

    it "should disallow two active locks" do
      @lock2        = make_lock(@user)
      @lock2.lock_serial = @lock.lock_serial
      assert_false @lock2.save, "save of duplicate active lock_serial rejected"
      assert_equal 2, Lock.count
      assert_equal 2, Lock.active.count
      assert_equal 1, Lock.where(lock_serial: @lock.lock_serial).count
    end

    it "should not allow a lock to be created when there's already one active" do
      assert @lock.commission_date
      @lock2 = make_lock(@user, false) # (user,false) Creates a not commissioned lock
      @lock2.lock_serial = @lock.lock_serial
      assert_not @lock2.valid?, "can not create record since one was active"
    end

    it "should not allow multiple uncommisioned locks to be created for a serial" do
      @lock.commission_date = nil
      assert @lock.save

      @lock2 = make_lock(@user, false)
      @lock2.lock_serial = @lock.lock_serial

      assert_equal 0, Lock.active.count
      assert_not @lock2.valid?
    end

    it "should not block editing of a lock that's active" do
      assert @lock.commission_date
      assert_not @lock.decommission_date
      assert @lock.valid?, "lock isn't valid from the start"
    end


    it "should find prioritized lock record by serial" do
      params = { lock_serial: @lock.lock_serial }

      assert @lock.do_decommission
      @new_lock = make_lock(@user)
      @new_lock.update!(lock_serial: @lock.lock_serial)

      active = Lock.get_active_else_not(params)
      assert_equal @new_lock.id, active.id, "didn't get active lock"

      assert @new_lock.do_decommission # won't let us create a pending now until this is decommissioned

      @pending_lock = make_lock(@user, false) # commission_date = nil
      @pending_lock.update!(lock_serial: @lock.lock_serial)
      pending = Lock.get_active_else_not(params)
      assert_equal @pending_lock.id, pending.id, "didn't get pending lock"
      @pending_lock.do_decommission

      # This is the "risky" case. It'll grab the "first" record of any matching lock
      anylock = Lock.get_active_else_not(params)
      assert anylock
      assert @lock.id, anylock.id
    end

    it "should find only the active keys for the lock" do
      active_key1 = make_guest_key(@lock, 'testuser2@example.com', @user)
      active_key2 = make_guest_key(@lock, 'testuser3@example.com', @user)
      active_key3 = make_guest_key(@lock, 'testuser4@example.com', @user)
      assert_equal 4, @lock.active_keys.count
      active_key3.revoke!(active_key3.lock.user)
      @lock.reload
      assert_equal 3, @lock.active_keys.count
      assert_equal 4, @lock.keys.count
    end

    it "should only find active locks" do
      @lock2        = make_lock(@user)
      @lock2.decommission_date = DateTime.now
      @lock2.save
      assert_equal 1, Lock.active.count

      @lock2.decommission_date = nil
      @lock2.save
      assert_equal 2, Lock.active.count

      # Validation preventing setting commission_date nil disabled.
      @lock2.commission_date = nil
      @lock2.save
      assert_equal 1, Lock.active.count

      # inactive until PUT:
      @lock3        = make_lock(@user, false)
      assert_equal 1, Lock.active.count
    end

    it "should nilify blank values on validation" do
      # TODO...maybe we should be using a
      @lock.bolt_state = "";
      @lock.reported_wifi_status = "";
      @lock.lock_serial = "";
      assert @lock.valid?
      assert_equal nil, @lock.bolt_state
      assert_equal nil, @lock.reported_wifi_status
      assert_equal nil, @lock.lock_serial
    end

    it "should allow the lock to be decommissioned" do
      assert_difference "Event.count", +1 do
        @lock.do_decommission
      end
      @lock.reload
      assert_not_equal nil, @lock.decommission_date
    end

    it "should allow the lock to be decomissioned with revoker and uuid" do
      fake_uuid = '11111111-1111-1111-1111-111111111111'
      assert_difference "Event.count", +1 do
        @lock.do_decommission(@lock.user, fake_uuid)
      end

      @lock.reload
      assert_not_equal nil, @lock.decommission_date

      # UUID and Revoker get stored in the event, let's see if they are there
      ev = Event.last
      assert_equal @lock.user.id, ev.user_id
      assert_equal fake_uuid, ev.uuid
    end

    it "should only allow the lock to be decommissioned if it's been commissioned" do
      @lock.commission_date = nil
      @lock.decommission_date = DateTime.now
      assert_not @lock.save
      assert @lock.errors.messages.keys.include?(:commission_date)
    end

  end
end
