require "test_helper"

class KeyTest < MiniTest::Unit::TestCase

  describe Key do

    before do
      DatabaseCleaner.start
      @user, @device, @user_device        = make_user
      @lock        = make_lock(@user)
      @key         = make_key(@lock, @user)
      @key_data    = {"start_date"        => "12-12-12",
                      "end_date"          => "31-12-13",
                      "is_fob"            => true,
                      "use_limit"         => 10,
                      "notify_owner"      => true,
                      "pin_code"          => "1234",
                      "notify_locked"     => true,
                      "notify_unlocked"   => true,
                      "notify_denied"     => true,
                      "auto_unlock"       => true,
      # API supports multiple time_constraints for a key, UI does not.
      # So we don't test it at the moment.
                      "time_constraints"  => [{"monday"    => false,
                                               "tuesday"   => true,
                                               "wednesday" => false,
                                               "thursday"  => true,
                                               "friday"    => false,
                                               "saturday"  => true,
                                               "sunday"    => true,
                                               "start_offset" => "-110",
                                               "end_offset"   => "150"
                                              }
                                             ]
                     }
    end

    after do
      DatabaseCleaner.clean
    end

    def create_new_key(lock_id, email, from_user, key_data = nil)
      Key.create_new_key(lock_id, email, from_user, key_data)
    end

    subject { @key }

    it "should have offset information" do
      new_key     = create_new_key(@lock.id, 'glenn2@example.com', @user, @key_data)
      assert_equal -110, new_key.time_constraints.first.start_offset
      assert_equal 150, new_key.time_constraints.first.end_offset
    end

    it "should create lock owner and new key owner notifications for a new key on create" do
      @key_user, dev, user_dev = make_user('glenn2@example.com')
      # Tests that @key_user doesn't get an admin message for their own key
      make_admin_user(@lock, @key_user)
      assert_difference "Notification.count", +2 do
        @new_key  = make_key(@lock, @key_user)
      end
      # XXX validate Was* notification contents, based on n.was field
      # so we don't depend on create order.
      assert Notification.last.message =~ / access/
      assert Notification.last.message =~ /Front Door/
    end

    it "should create event, no notification for a lock owner" do
      assert Event.all.count == 1
      assert Notification.all.count == 0
    end

    it "should revoke a key with the revoke! method" do
      assert @key.revoked.nil?
      assert !@key.revoked?
      assert @key.revoke!(@key.lock.user)
      assert @key.revoked?
    end

    it "should have name field containing lock name" do
      assert_equal @key.name, "for " + @key.user.account.name
    end

    it "should update user_account_id on save" do
      assert_equal @key.user_account_id,  @key.user_id
      user2, dev, user_dev  = make_user
      @key.user_id =  user2.id
      @key.save
      assert_equal @key.user_account_id,  @key.user_id
    end

    it "should create a notification to lock owner and key owner for a revoked key" do
      @admin_user, dev, user_dev = make_user('glenn_admin@example.com')
      make_admin_user(@lock, @admin_user)

      @new_key  = make_guest_key(@lock, 'glenn3@example.com', @admin_user)
      assert_difference "Notification.count", +2 do
        @new_key.revoke!(@admin_user)
      end
      # XXX validate Was* notification contents, based on n.was field
      assert Notification.last.message =~ /has been cancelled/

      # Spot check to make sure the user on the event is the admin
      assert_equal EventType::KEY_REVOKED, Event.last.event_type
      assert_equal @admin_user.id, Event.last.user_id
    end

    it "should create auto-generated keys" do
      assert_difference "Key.count", 1 do
        key2 = make_auto_key(@lock, 'glenn2@example.com', @user)
      end
    end

    it "should reject keys with no email to find/create key owner's account" do
      assert_raises(ActiveRecord::RecordInvalid) do
        make_auto_key(@lock, nil, @user)
      end
    end
    it "should abandon key creation with no sharer" do
      key = make_auto_key(@lock, 'glenn2@example.com', nil)
      assert_equal key[:error], 403
    end

    it "should reject key creation with no sharer as invalid record" do
      key = make_primitive_auto_key(@lock, @user, nil)
      assert_equal key[:error], 422
    end

    it "should not have notifications for unexpired key" do
      Key.notify_expired_keys
      assert Notification.unscoped.count == 0
    end

    it "should create notifications for expired key" do
      @key.end_date = Time.now - 1.day
      assert @key.expired?
      @key.save!
      assert_difference "Notification.count", +1 do
        Key.notify_expired_keys
      end
      assert Notification.last.message =~ /has expired/
    end

    it "should not create notifications for expired key which is revoked" do
      @key.end_date = Time.now - 1.day
      assert @key.expired?
      @key.revoke!(@key.lock.user)
      @key.save!
      assert_no_difference "Notification.count" do
        Key.notify_expired_keys
      end

    end

    it "should not have more than one notification for expired key occur" do
      @key.end_date = Time.now - 1.day
      @key.save!
      assert_difference "Notification.count", +1 do
        Key.notify_expired_keys
      end
      assert Notification.first.message =~ /has expired/, "notification must say \"has expired\""
      # second call
      assert_no_difference "Notification.count" do
        Key.notify_expired_keys
      end
      @reloaded_key = Key.find(@key.id)
      assert @reloaded_key.expired_notification_generated == true
      assert Notification.unscoped.count == 1, "one notification"
      assert Notification.first.message =~ /has expired/, "notification must say \"has expired\""
    end

    it "should set original_key_id equal to id on create" do
      assert_equal @key.id, @key.original_key_id
    end

    it "should keep original_key_id on copy/update" do
      new_key = @key.dup
      @key.replaced_at = new_key.created_at = DateTime.now
      @key.save!
      new_key.save!
      assert_equal new_key.original_key_id, @key.original_key_id
      assert_not_equal new_key.original_key_id, new_key.id
    end

    it "should have a method that constructs the name according to domain logic" do
      assert_equal Key.construct_name(@user, @lock), @lock.name
    end

    it "should have a method that returns the last event timestamp for a key" do
      assert_equal @key.last_access, nil
      3.times { Event.create!(lock_id: @key.lock.id, :key_id => @key.id,
                              event_time: Time.now,
                              event_type: EventType::LOCK,
                              string_value: CommandResult::SUCCESS,
                              bolt_state: BoltState::LOCKED,
                              )}
      assert_equal @key.last_access, Event.where(:key_id => @key.id).order('event_time DESC').first.event_time
    end

    it "should have a functioning create_new_key method for basic keys" do
      @guest_email = 'glennguest@example.com'
      key = nil
      assert_difference ['Key.count','Event.count'], 1 do
        assert_difference [ 'ActionMailer::Base.deliveries.size'], ActiveSupport::TestCase.mail_count do
          key = create_new_key(@lock.id, @guest_email, @user)
        end
      end
      assert !key.user.account.confirmed?, "should be unconfirmed account"
      assert_equal @user.id, key.sharer_user_id, "sharer_user should be set"
      assert_not_equal true, key.auto_generated

      # Check that proper event was created
      event = Event.last
      assert_equal event.key_id, key.id
      assert_equal event.user_id, @user.id, "event's user should be sharing user"

      # Check that proper email was sent
      mail = ActionMailer::Base.deliveries.last
      if mail
        assert_match /sign in/, mail.body.to_s # Email includes first time           assert_match "Email: " + @guest_email, mail.body.to_s # email shown
        assert_match /Password: [^\n]+\n/, mail.body.to_s # auto-generated password shown
      end
    end

    it "should have a functioning create_new_key method for keys with additional data" do
      assert_difference "Key.count", 1 do
        assert_difference [ 'ActionMailer::Base.deliveries.size'], ActiveSupport::TestCase.mail_count do
          new_key     = create_new_key(@lock.id, 'glenn2@example.com', @user, @key_data)
          assert_equal  new_key.time_constraints.count, 1
        end
      end
    end

    it "should send a email for existing user when key is shared non-admin" do
      @user2, dev, user_dev = make_user('sharing@example.com')
      assert_difference "Key.count", 1 do
        assert_difference [ 'ActionMailer::Base.deliveries.size'], ActiveSupport::TestCase.mail_count do
          new_key = create_new_key(@lock.id, @user2.account.email, @user, @key_data)
        end
      end
    end

    it "should send a email for existing user when key is shared from admin" do
      @user3, dev, user_dev = make_user('sharing@example.com')
      make_admin_user(@lock, @user3)
      @user3.reload
      assert_difference [ 'ActionMailer::Base.deliveries.size'], ActiveSupport::TestCase.mail_count do
        new_key = Key.unscoped.create_new_key(@lock.id, @user3.account.email, @user, @key_data)
      end
      assert_equal  Key.unscoped.to_a.count, 2
    end

    it 'should create a LockUser instance when admin is set to true' do
      @key_data_admin =  @key_data.merge({"admin" => "true"})
      assert_difference 'LocksUser.count' do
        key = create_new_key(@lock.id, 'glenn2@example.com', @user, @key_data_admin)
      end
    end

    it 'should not create a LockUser instance when admin is not set to true' do
      @key_data_admin =  @key_data.merge({"admin" => "false"})
      assert_no_difference 'LocksUser.count' do
        key = create_new_key(@lock.id, 'glenn2@example.com', @user, @key_data)
        assert_not_equal true, key.auto_generated
      end
    end

    it 'should not create a LockUser instance when sharer is not the owner' do
      @key_user, dev, user_dev = make_user('glenn_admin@example.com')
      # Tests that @key_user doesn't get an admin message for their own key
      make_admin_user(@lock, @key_user)

      @key_data_admin =  @key_data.merge({"admin" => "true"})
      assert_no_difference 'LocksUser.count' do
        key = create_new_key(@lock.id, 'glenn2@example.com', @user, @key_data)
      end
    end

    it 'should only return active keys' do
      @lock2        = make_lock(@user)
      @lock3        = make_lock(@user)
      @lock4        = make_lock(@user)
      active_key1 = make_key(@lock2, @user)
      active_key2 = make_key(@lock3, @user)
      active_key3 = make_key(@lock4, @user)
      assert_equal 4, Key.active_keys.count
      active_key3.revoke!(active_key3.lock.user)
      assert_equal 3, Key.active_keys.count
    end

    it 'active scope should not return keys from decommisioned locks' do
      @lock2        = make_lock(@user)
      active_key1   = make_key(@lock2, @user)

      assert_difference "Key.active_keys.count", -1 do
        @lock2.do_decommission
      end
    end

    it 'should only allow a single active key for a given lock & user' do
      # At least for alpha

      # TODO There's an issue somewhere in create key, that cause an exception to be thrown
      # rather than just returning an invalid object...need to look into what should be
      # returned from the create_key method
      caught_exception = false
      begin
        assert_no_difference "Key.count" do
          @key2 = make_key(@lock, @user)
        end
      rescue ActiveRecord::RecordInvalid
        caught_exception = true
      end

      assert caught_exception, "did not fail to create the key"
    end

    it 'should allow a new key if others are revoked' do
      @key.revoke!(@key.lock.user)
      assert_difference "Key.count", 1 do
        @key2 = make_key(@lock, @user)
      end
    end

    it "should return only active keys, not replaced or revoked keys" do 
      @key2 = create_new_key(@lock.id, 'example@example.com', @user)
      @key3 = create_new_key(@lock.id, 'example2@example.com', @user)
      @key.revoke!(@key.lock.user)
      @key2.replaced_at = Time.now
      @key2.save!
      assert_equal 1, Key.active_keys.count
    end


     # TODO: Add two more tests for admins
  end
end
