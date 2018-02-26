# -*- coding: utf-8 -*-
require "test_helper"

class KeysControllerTest < ActionController::TestCase

  describe KeysController do

    def check_key_db_reply(key, ref_data, disallow = nil, lineno = nil)
      check_key_data(key, ref_data,
                     JSON.parse(response.body),
                     [:authtoken, :email], nil, true, disallow, lineno )
    end
    def check_key_db_update_reply(key, ref_data, disallow = nil, lineno = nil)
      ref_data[:id] = key.id
      check_key_db_reply(key, ref_data, disallow, lineno)
    end
    def check_key_db(key, ref_data, lineno = nil)
      check_key_data(key, ref_data, nil,
                     [:authtoken, :email], nil, nil, nil, lineno)
    end

    describe "index" do
      subject { KeysController }

      before do
        DatabaseCleaner.start
        @routes = Rails.application.routes
        @user, @device, @user_device  = make_user
        @guest_email = @@guest_email
        @guest_user, @guest_device, @guest_user_device = make_user(@guest_email)
        @lock   = make_lock(@user)
        @key    = make_guest_key(@lock, @guest_email, @user)
        @user2, @device2, @user_device2  = make_user('glenn2@example.com')
        make_admin_user(@lock, @user2)
        @key2   = make_key(@lock, @user2)
        @lock2   = make_lock(@user)
        @user3, @device3, @user_device3  = make_user('glenn3@example.com')
      end

      after do
        DatabaseCleaner.clean
      end

      it "must respond" do
        @key3   = make_key(@lock, @user)
        send_auth(@user_device)
        get(:index)
        assert @routes
        check_keys_response(@key3)
      end

      it "should get unauthorized response from index without authtoken" do
        get(:index)
        check_response :unauthorized, :UNAUTHORIZED
      end

      it "should get unauthorized response from index with bad authtoken" do
        header_auth("junk", @user_device.id)
        get(:index)
        check_response :unauthorized, :UNAUTHORIZED
      end

      it "should return correct payload for a guest key" do
        send_auth(@guest_user_device)
        get(:index)
        check_keys_response(@key)
      end

      it "should return correct payload for an admin key" do
        send_auth(@user_device2)
        get(:index)
        check_keys_response(Key.last)
      end

      it "should contain valid lock last_access attribute" do
        send_auth(@guest_user_device)
        get(:index)
        json_arr = JSON.parse(response.body)
        json = json_arr.first
        key_data, key_info = get_keys_from_signed_response_body(json)
        assert_nil key_info["last_access"]
        3.times do
          Event.create!(:lock_id => @key.lock_id,
                        :key_id => @key.id,
                        :event_time => DateTime.now.utc.iso8601(3),
                        :event_type => EventType::LOCK,
                        :string_value => CommandResult::SUCCESS,
                        :bolt_state => BoltState::UNLOCKED)
        end
        send_auth(@guest_user_device)
        get(:index)
        json = JSON.parse(response.body).first
        key_data, key_info = get_keys_from_signed_response_body(json)
        assert_equal @key.last_access.to_s(:db), DateTime.parse(key_info["last_access"]).to_s(:db)
        assert_equal @key.lock.new_credentials, key_info["new_credentials"]
      end

      it "should contain lock_user when admin queries their locks" do
        send_auth(@user_device2)
        get(:index)
        json = JSON.parse(response.body).first
        key_data, key_info = get_keys_from_signed_response_body(json)
        log_json(response, "Keys GET")
        assert_equal true, key_info["lock_user"]["admin"]
      end

      it "should not return revoked keys in index" do
        @key3 = make_guest_key(@lock2, @user2.account.email, @user)
        send_auth(@user_device2)
        get(:index)
        reply1 = JSON.parse(response.body)
        assert_equal 2, reply1.count
        @key2.revoke! @user
        send_auth(@user_device2)
        get(:index)
        reply2 = JSON.parse(response.body)
        assert_equal 1, reply2.count
        @key3.reload # Changes due to pending status change happening on GET :index
        check_keys_response(@key3)
      end

      it 'should return the correct lock time_zone if set' do
        @lock.time_zone = "PDT"
        @lock.save
        send_auth(@user_device2)
        get(:index)
        check_keys_response(Key.last)
      end

	  it "should not return replaced_at-updated keys in index" do
        @key3 = make_guest_key(@lock2, @user2.account.email, @user)
        send_auth(@user_device2)
        get(:index)
        reply1 = JSON.parse(response.body)
        assert_equal 2, reply1.count
        #now = DateTime.now
        assert_no_difference [ "LocksUser.count"] do
          # access_changed
          assert_difference [ "Key.count", "Event.count"], 1 do
            assert_difference [ "ActionMailer::Base.deliveries.size" ], @@mail_count do
              ref_data = update_key(@key3.id, {
                                      time_constraints: [{
                                                           start_time: "18:00Z",
                                                           end_time: "18:00Z"
                                                         }]
                                    }, @user_device)
              check_response
            end
          end
        end
        send_auth(@user_device2)
        get(:index)
        reply2 = JSON.parse(response.body)
        assert_equal 2, reply2.count
        assert_equal @key3.replaced_at, nil
        key_reply = []
        reply2.each do |i|
          key_reply = i if i["key_data"]["id"] == Key.last.id
        end
        check_key_data(Key.last, nil, key_reply);
      end
    end

    def basic_key_data(email, lock, extra)
      # XXX fill out and check all fields
      key_data = {
        :email => email,
        :lock_id => lock.id,
        # test LP17149960
        :admin => 'false',
      }
      if extra
        key_data.merge!(extra)
      end
      return key_data
    end
    def update_key(id, data, user_device)
      if data
        data.merge!({ id: id })
      else
        data = { id: id }
      end
      if user_device
        send_auth(user_device)
      else
        header_auth
      end
      put(:update, data)
      return data
    end

    def create_basic_key(email, lock, user_device, extra = nil)
      key_data = basic_key_data(email, lock, extra)
      if user_device
        send_auth(user_device)
      end
      post(:create, key_data)
      return key_data
    end

    describe "create action" do
      subject { KeysController }

      before do
        DatabaseCleaner.start
        @routes = Rails.application.routes
        @user, @device, @user_device = make_user
        @user2, @device2, @user_device2  = make_user('glenn2@example.com')
        @guest_email = @@real_email
        @lock = make_lock(@user)
        create_basic_key(@user.account.email, @lock, @user_device)
        @user3, @device3, @user_device3 = make_user('glenn3@example.com')
      end

      after do
        DatabaseCleaner.clean
      end

      it "should delete old key when creating new one for user {demo hack}" do
        cnt = Key.count
        create_basic_key(@user.account.email, @lock, @user_device)
        cnt2 = Key.count
        assert_equal cnt, cnt2
      end

      it "should respond with invalid params with missing lock_id or user_id" do
        send_auth(@user_device)
        post(:create)
        check_response 422, :MISSING_PARAM
      end

      it "should respond with full key data" do
        json = JSON.parse(response.body).first
        assert json # valid object
      end


      it "should reject unparsable start_date" do
        create_basic_key(@user3.account.email, @lock, nil, {
                           # We might relax this restriction
                           start_date: 'abcdefg',
                           end_date: (DateTime.now-1.day).utc.iso8601(3),
                         })
        error = JSON.parse(response.body)["error"]
        assert_false error.include?(Util.VALIDATOR_MSGS[:DATE_ORDER]), "error message should not report bogus end > start"
        check_response 422, Util.VALIDATOR_MSGS[:DATE]
      end

      it "should reject unparsable end_date" do
        create_basic_key(@user3.account.email, @lock, nil, {
                           end_date: 'abcdefg',
                         })
        check_response 422, Util.VALIDATOR_MSGS[:DATE]
      end

      # XXX obsolete, replace all these tests with start/end_offset
      it "should reject start_time later than end_time" do
        create_basic_key(@user3.account.email, @lock, nil,
                         {
                           time_constraints: [{
                                                start_time: "18:01Z",
                                                end_time: "18:00Z"
                                              }]
                         })
        check_response 422, Util.VALIDATOR_MSGS[:TIME_ORDER]
      end

      it "should reject unparsable tc.start_offset" do
        create_basic_key(@user3.account.email, @lock, nil,
                         {
                           time_constraints: [{
                                                monday: "true",
                                                wednesday: "true",
                                                start_offset: "abcdefg",
                                                # Tests start_and_end_offset override
                                                end_offset: "-110"
                                              }]
                         })
        # Yes, we want to report classname when errors come from
        # multiple classes.
        error = JSON.parse(response.body)["error"]
        assert_false error.include?(Util.VALIDATOR_MSGS[:OFFSET_ORDER]), "error message should not report bogus end > start"
        assert error.include?("TimeConstraint"), "missing classname in error message"
        check_response 422, Util.VALIDATOR_MSGS[:INTEGER]
      end

      it "should reject unparsable tc.end_offset" do
        create_basic_key(@user3.account.email, @lock, nil,
                         {
                           time_constraints: [{
                                                monday: "true",
                                                wednesday: "true",
                                                start_offset: "18:00Z",
                                                end_offset: "abcdefg"
                                              }]
                         })
        check_response 422, Util.VALIDATOR_MSGS[:INTEGER]
      end

      it "should reject tc.start_offset later than tc.end_offset" do
        create_basic_key(@user3.account.email, @lock, nil,
                         {
                           time_constraints: [{
                                                start_offset: 0,
                                                end_offset: -10,
                                              }]
                         })
        check_response 422, Util.VALIDATOR_MSGS[:OFFSET_ORDER]
      end

      it "should return key creation json in correct format" do
        ref_data = create_basic_key(@user3.account.email, @lock, nil, nil)
        check_response
        log_json(response, "Keys POST")
        #XXX add time constraints (in test_helper_core.db)
        key = Key.last
        #XXX internally-generated db fields not checked.
        check_key_db_reply(key, ref_data, nil, __LINE__)
      end

      it "should reject key create when not lock owner or admin" do
        user3, device3, user_device3 = make_user(email = 'glenn3@example.com', password = 'aba456')
        lock3 = make_lock(user3)
        create_basic_key(@user.account.email, lock3, @user_device)
        check_response :forbidden
      end

      it "should reject key create of an admin when not lock owner" do
        user3, device3, user_device3 = make_user(email = 'glenn3@example.com', password = 'aba456')
        lock3 = make_lock(user3)
        make_admin_user(@lock, @user)
        ref_data = create_basic_key(@user.account.email, lock3, @user_device,
                                    { admin: 'true' })
        check_response :forbidden
      end

      it 'should respond successfully if an admin attempts to make a key' do
        user3, device3, user_device3 = make_user(email = 'glenn3@example.com', password = 'aba456')
        make_admin_user(@lock, user3)
        user3.reload
        ref_data = {:lock_id => @lock.id, :email => user3.account.email}
        send_auth(user_device3)
        post(:create, ref_data)
        check_response
        key = Key.last
        check_key_db_reply(key, ref_data, nil, __LINE__)
      end

      it "should create a new unconfirmed account if the account doesn't exist" do
        ref_data = nil
        assert_difference [ "Account.count", "Event.count" ], 1 do
          # FIXED bug LP17149960: extra event here
          ref_data = create_basic_key('testkey@emmoco.com', @lock, @user_device)
          check_response
        end
        key = Key.last
        ref_data[:pending] = 'true'
        check_key_db_reply(key, ref_data, nil, __LINE__)
        evs = Event.all.order('created_at ASC')
        ev_admin = evs[evs.length-1]  # bug: 1
        check_key_shared_event(ev_admin, key)
      end

      it "should create a new key if the account doesn't exist" do
        assert_difference "Key.count", +1 do
          create_basic_key('testkey@emmoco.com', @lock, @user_device)
          check_response
        end
      end

      it "should create a new temp password and send if the account exists but is not confirmed when sharing key" do
        account_unconfirmed = make_unconfirmed_account('notconfirmed3@example.com')
        user_unconfirmed, device, user_device = make_user_from_account(account_unconfirmed)

        assert_difference ["Event.count", "Key.count"], +1 do
          assert_difference [ "ActionMailer::Base.deliveries.size" ], @@mail_count do
           key = create_basic_key(account_unconfirmed.email, @lock, user_device)
          end
        end
        mail = ActionMailer::Base.deliveries.last
        if mail # Won't be there SEND_TEST_EMAIL enabled.
          mail_text = mail.body.to_s
          assert_match /sign in/, mail_text
          assert_match /Password: [^\n]+\n/, mail_text
        end
      end

      it "should save the uuid on all created objects - Event and Account" do
        @admin, device, user_device = make_user("adminuser@example.com")
        make_admin_user(@lock, @admin)
        ref_data = nil
        assert_difference ["Key.count", "Event.count", "Account.count"], +1 do
          ref_data = create_basic_key('example@example.com', @lock, user_device,
                                      {
                                        admin: 'false' })
          check_response
        end
        key = Key.last
        event = Event.all.order('created_at ASC').last
        account = Account.last
        # XXX uuid's are nil, no way to set in test framework, so not really tested.  Need to modify test framework.
        assert_equal key.uuid, event.uuid
        assert_equal key.uuid, account.uuid
      end

      it "should not be case sensitive on emails when creating a key" do
        assert_difference "Key.count", +1 do
          assert_no_difference "Account.count" do
            create_basic_key(@user2.account.email.upcase, @lock, nil)
            check_response
          end
        end
      end

      it "should set pending to false if sharing and receiving user are the same" do
        # This happens during commissioning
        key = Key.last
        assert_equal key.lock.user, key.sharer
        assert_equal key.pending, false
      end

      it "should create a key with multiple time constraints" do
        # This is a mode not supported in the current app wireframes, but was existing support in the server.
        # Found this difficult to create a http variables to represent this. May have to pass JSON if this is
        # ever needed.
        ref_data =  {
          lock_id: @lock.id,
          email: 'testfuturekey@example.com',
          time_constraints: [{
                               monday: "true",
                               tuesday: "true",
                             },
                             {
                               start_time: "5:00:00Z",
                               end_time: "14:00:00Z"
                             }]
        }
        assert_difference "TimeConstraint.count", +2 do
          assert_difference "Key.count", +1 do
              send_auth(@user_device)
              post(:create, ref_data)
              check_response
          end
        end
        check_key_db_reply(Key.last, ref_data, nil, __LINE__)
      end

      it "should not create an Admin Key with time constraints" do
        ref_data = ref_data =  {
          lock_id: @lock.id,
          email: 'testfuturekey@example.com',
          admin: true,
          time_constraints: [{
                               monday: "true",
                               tuesday: "true",
                             },
                             {
                               start_time: "5:00:00Z",
                               end_time: "14:00:00Z"
                             }]
        }
        assert_no_difference "TimeConstraint.count" do 
          assert_no_difference "Key.count" do
              send_auth(@user_device)
              post(:create, ref_data)
              check_response 422
          end
        end
      end

      it "should create a key with start/end datetime constraint" do
        # From wireframe, S.2, Date Range case
        # Example would be house guests. Give my friend access starting Aug 8 @ 9:30pm through Aug 10 @ 3:am
        ref_data = {
                    lock_id: @lock.id,
                    email: 'testfuturekey@example.com',
                      start_date: "2020-08-08T21:30:00.000Z",
                      end_date: "2020-08-10T03:00:00.000Z"
                    }
        assert_difference "Key.count", +1 do
          assert_no_difference "TimeConstraint.count" do # When it's just date, we don't have a timecontraint record
            send_auth(@user_device)
            post(:create, ref_data)
          end
        end
        check_response
        check_key_db_reply(Key.last, ref_data, nil, __LINE__)
      end

      it "should create a key with recurring restricted access" do
        # From wireframe, S.2, Recurring case
        # Example would be housecleaning serviec. Give this person access from 2-5pm every Monday and Wednesday
        ref_data = {
          lock_id: @lock.id,
          email: 'testfuturekey@example.com',
          time_constraints: [{
                               monday: "true",
                               wednesday: "true",
                               start_time: "14:00Z",
                               end_time: "18:00Z"
                             }]
        }
        assert_difference ["Key.count", "TimeConstraint.count"], +1 do
          send_auth(@user_device)
          post(:create, ref_data)
          check_response
        end
        check_key_db_reply(Key.last, ref_data, nil, __LINE__)

      end

      it "should create a key with recurring restricted access using offsets" do
        # From wireframe, S.2, Recurring case
        # Example would be housecleaning serviec. Give this person access from 2-5pm every Monday and Wednesday
        ref_data = {
          lock_id: @lock.id,
          email: 'testfuturekey@example.com',
          time_constraints: [{
                               monday: "true",
                               wednesday: "true",
                               start_offset: "510",
                               end_offset: "840"
                             }]
        }
        assert_difference ["Key.count", "TimeConstraint.count"], +1 do
          send_auth(@user_device)
          post(:create, ref_data)
          check_response
        end
        assert_equal ref_data[:time_constraints][0][:start_offset], Key.last.time_constraints.first.start_offset.to_s
        assert_equal ref_data[:time_constraints][0][:end_offset],   Key.last.time_constraints.first.end_offset.to_s
        check_key_db_reply(Key.last, ref_data, nil, __LINE__)
      end

      it "should create a key plus LocksUser admin privileges record and send an email" do
        ref_data = nil
        assert_difference ["Key.count", "LocksUser.count"], 1 do
          # FIXED bug LP17149960: extra event/email here
          assert_difference [ "Event.count" ], 1 do
            assert_difference [ 'ActionMailer::Base.deliveries.size'], @@mail_count do
              ref_data = create_basic_key(@guest_email, @lock, @guest_user_device,
                                          { admin: 'true' })
              check_response
            end
          end
        end
        check_key_db_reply(Key.last, ref_data, nil, __LINE__)
        check_locks_user(@lock, Key.last.user_id, true)
        # Check that the right mail was sent
          # FIXED bug LP17149960: check first (proper) email
        mail = ActionMailer::Base.deliveries.last
        if mail
          assert_match /Get the app/, mail.body.to_s
          assert_match "Email: " + @guest_email, mail.body.to_s # email shown
          assert_match /Password: [^\n]+\n/, mail.body.to_s # auto-generated password shown
        end
      end

      it "should not allow more than one key to be created" do
      # We don't support merging access times for multiple keys yet.
        ref_data2 = nil
        assert_difference ["Key.count", "LocksUser.count"], +1 do
          # FIXED bug LP17149960: extra event/email here
          assert_difference ["ActionMailer::Base.deliveries.size"], @@mail_count do
            ref_data = create_basic_key(@guest_email, @lock, @guest_user_device,
                                        { admin: 'true' })
            check_response
          end
        end
        assert_no_difference ["Key.count", "LocksUser.count"] do
          assert_no_difference ["ActionMailer::Base.deliveries.size"], +1 do
            # Should update existing LocksUser record, not create a new one (LU.count +1).
            ref_data2 = create_basic_key(@guest_email, @lock, @guest_user_device,
                                         { admin: 'false' })
            check_response :conflict
          end
        end
      end

      it "admins should NOT be able to create an admin key for a new non-admin account" do
        # Is it really defined whether it creates a non-admin key, or just errors?
        @admin, device, user_device = make_user("adminuser@example.com")
        make_admin_user(@lock, @admin)

        ref_data = nil
        assert_difference ["Key.count"], 1 do
          assert_difference ["ActionMailer::Base.deliveries.size"], @@mail_count do
            assert_difference "LocksUser.count", 0 do
              ref_data = create_basic_key(@guest_email, @lock, user_device,
                                          {
                                            admin: 'true' })
            end
          end
        end
      end

      it "admins should be able to create a non-admin key for a existing account" do
        @admin, device, user_device = make_user("adminuser@example.com")
        make_admin_user(@lock, @admin)
        @guest_user, guest_device, guest_user_device  = make_user(@guest_email)

        ref_data = nil
        assert_difference ["Key.count"], 1 do
          assert_difference ["ActionMailer::Base.deliveries.size"], @@mail_count do
            assert_difference "LocksUser.count", 0 do
              ref_data = create_basic_key(@guest_user.account.email, @lock, user_device,
                                          {
                                            admin: 'false' })
              check_response
            end
          end
        end
        key = Key.last
        check_key_db_reply(key, ref_data, nil, __LINE__)
        evs = Event.all.order('created_at ASC')
        check_key_shared_event(evs.last, key, @admin)

        # Check that the right mail was sent
        mail = ActionMailer::Base.deliveries.last
        if mail
          assert_match /Open the Goji App/, mail.body.to_s # existing account button variant.
          assert_match /owned by/, mail.body.to_s # Email says lock is owned by another user
          assert_no_match "Email: " + @guest_email, mail.body.to_s
          assert_no_match /Password: [^\n]+\n/, mail.body.to_s
        end
      end

      it "admins should be able to create a non-admin key for a new account" do
        @admin, device, user_device = make_user("adminuser@example.com")
        make_admin_user(@lock, @admin)
        ref_data = nil
        assert_difference ["Key.count"], 1 do
          assert_difference ["ActionMailer::Base.deliveries.size"], @@mail_count do
            assert_difference "LocksUser.count", 0 do
              ref_data = create_basic_key(@guest_email, @lock, user_device,
                                          {
                                            admin: 'false' })
              check_response
            end
          end
        end
        check_key_db_reply(Key.last, ref_data, nil, __LINE__)

        # Check that the right mail was sent
        mail = ActionMailer::Base.deliveries.last
        if mail
          assert_match /Get the app/, mail.body.to_s # new account button variant.
          assert_match /owned by/, mail.body.to_s # Email says lock is owned by another user
          assert_match "Email: " + @guest_email, mail.body.to_s # email shown
          assert_match /Password: [^\n]+\n/, mail.body.to_s # auto-generated password shown
        end
      end

      # Surely the 4th email case will be right...

    end

    describe "update/PUT" do
      subject { KeysController }

      before do
        DatabaseCleaner.start
        @routes = Rails.application.routes
        @user, @device, @user_device = make_user
        @lock = make_lock(@user)
        @user2, @device2, @user_device2  = make_user('glenn2@example.com')
        make_admin_user(@lock, @user2)
        @guest_user, @guest_device, @guest_user_device  = make_user(@@real_email)
        create_basic_key(@guest_user.account.email, @lock, @user_device)
        @user3, @device3, @user_device3 = make_user('glenn2@example.com')
      end

      after do
        DatabaseCleaner.clean
      end

      it "should reject update with no auth" do
        key = Key.last
        ref_data = update_key(key.id, {
                                #use_* not in requirements now.
                                use_limit:  100,
                                use_count: 10,
                              }, nil)
        check_response :unauthorized, :UNAUTHORIZED
      end

      it "should reject update if not lock owner/admin" do
        lock3 = make_lock(@user3)
        make_guest_key(lock3, @user3.account.email, @user3)
        ref_data = update_key(Key.last.id, {
                                use_limit:  100,
                                use_count: 10,
                              }, @user_device)
        check_response 403, :ADMIN_ACCESS
      end

      it "should resend invitation email for existing account, with no temp password" do
        key = Key.last
        ref_data = nil
        assert_no_difference "Key.count" do
          assert_difference [ "Event.count" ], 1 do
            assert_difference [ "ActionMailer::Base.deliveries.size" ], @@mail_count do
              ref_data = update_key(Key.last.id, {
                                      resend:  "true",
                                      # ignored, so won't cause an error!
                                      use_count: 10,
                                      start_date: "garbage",
                                    }, @user_device)
              check_response
            end
          end
        end
        mail = ActionMailer::Base.deliveries.last
        if mail # Won't be there SEND_TEST_EMAIL enabled.
          mail_text = mail.body.to_s
          assert_no_match /sign in/, mail_text
          assert_no_match /Password:/, mail_text
        end
        key.reload
        check_key_db_reply(key, ref_data, [ :resend, :use_count, :start_date], __LINE__)
      end

      it "should resend invitation email for new account, with new temp password" do
        account_unconfirmed = make_unconfirmed_account('notconfirmed3@example.com')
        user_unconfirmed, device, user_device = make_user_from_account(account_unconfirmed)
        key = make_guest_key(@lock, user_unconfirmed.account.email, @lock.user)
        ref_data = nil
        assert_no_difference "Key.count" do
          assert_difference [ "Event.count" ], 1 do
            assert_difference [ "ActionMailer::Base.deliveries.size" ], @@mail_count do
              ref_data = update_key(key.id, {
                                      resend:  "true",
                                    }, @user_device)
              check_response
            end
          end
        end
        mail = ActionMailer::Base.deliveries.last
        if mail # Won't be there SEND_TEST_EMAIL enabled.
          mail_text = mail.body.to_s
          assert_match /sign in/, mail_text
          assert_match /Password: [^\n]+\n/, mail_text
        end
        key.reload
        check_key_db_reply(key, ref_data, [ :resend, :use_count, :start_date], __LINE__)
      end

      # TBD LP17721652: test expiration: need to override expiration time for testing.

      # We define an update with nil time_constraints to erase any
      # existing constraints.  Perhaps inconsistent with the only
      # change supplied fields model...
      it "should accept an update without an admin change, if lock admin" do
        lock3 = make_lock(@user3)
        make_guest_key(lock3, @user3.account.email, @user3)
        # The requesting user
        make_admin_user(lock3, @user)
        ref_data = nil
        assert_no_difference [ "LocksUser.count" ] do
          assert_difference [ "Key.count", "Event.count" ], 1 do
            ref_data = update_key(Key.last.id, {
                                    use_count: 10,
                                  }, @user_device)
            check_response
          end
        end
        key = Key.last
        key.reload
      end

      it "should reject update if not lock owner {just admin} and key user is admin" do
        lock3 = make_lock(@user3)
        make_guest_key(lock3, @user3.account.email, @user3)
        make_admin_user(lock3, @user3)
        # The requesting user is admin, not owner
        make_admin_user(lock3, @user)
        ref_data = update_key(Key.last.id, {
                                use_limit:  100,
                                use_count: 10,
                              }, @user_device)
        check_response 403, :ADMIN_NOT_OWNER
      end

      it "should reject update if not lock owner {just admin} and adding admin true" do
        lock3 = make_lock(@user3)
        make_guest_key(lock3, @user3.account.email, @user3)
        # The requesting user is admin, not owner
        make_admin_user(lock3, @user)
        ref_data = update_key(Key.last.id, {
                                admin: 'true',
                              }, @user_device)
        check_response 403, :ADMIN_NOT_OWNER
      end

      it "adding admin and time_constrants should return error" do
        key = Key.last
        check_locks_user(@lock, key.user_id, false)
        ref_data = nil
        assert_no_difference [ "LocksUser.count", "Key.count"] do
          # admin_shared only, no access_changed when becoming admin
          assert_no_difference [ "Event.count"] do
            ref_data = update_key(key.id, {
                                    is_fob: true,
                                    auto_unlock: 'true',
                                    use_limit:  100,
                                    use_count: 10,
                                    admin: 'true',
                                    time_constraints: [{
                                                         monday: "true",
                                                       }]
                                  }, @user_device)
          end
        end
        check_response 422, Util.VALIDATOR_MSGS[:ADMIN_KEY_UNLIMITED]
      end

      it "adding admin and end_date should return error" do
        key = Key.last
        ref_data = nil
        assert_no_difference [ "LocksUser.count", "Key.count"] do
          assert_no_difference [ "Event.count", 'ActionMailer::Base.deliveries.size'] do
            ref_data = update_key(key.id, {
                                    is_fob: true,
                                    auto_unlock: 'true',
                                    end_date:  (DateTime.now+1.day).utc.iso8601(3),
                                    use_limit:  100,
                                    use_count: 10,
                                    admin: 'true',
                                  }, @user_device)
          end
        end
        check_response 422, Util.VALIDATOR_MSGS[:ADMIN_KEY_UNLIMITED]
      end

      it "adding admin, removing admin and changing access times" do
        key = Key.last
        ref_data = nil
        assert_no_difference [ "Key.count", "LocksUser.count"] do
          assert_difference [ 'Event.count'], 1 do
            assert_difference [ 'ActionMailer::Base.deliveries.size'], @@mail_count do
              ref_data = update_key(key.id, {
                                      is_fob: 'true',
                                      auto_unlock: 'true',
                                      use_limit:  100,
                                      use_count: 10,
                                      admin: 'true',
                                    }, @user_device)
              check_response
            end
          end
        end

        key.reload
        check_key_db(key, ref_data, __LINE__)
        check_locks_user(@lock, key.user_id, true)
        check_admin_event(Event.last, key.lock, @guest_user, @user, EventType::ADMIN_SHARED, __LINE__)
        # Check that the right email was sent
        mail = ActionMailer::Base.deliveries.last
        if mail
          assert_match /Open the Goji App/, mail.body.to_s
          assert_match "upgraded", mail.body.to_s
        end
        # now make not admin, add time_constraint

        now = DateTime.now
        assert_no_difference [ "LocksUser.count"] do
          assert_difference [ "Key.count"], 1 do
            # admin_revoked+access_changed; for now, let both messages
            # be delivered, really should have a combined message,
            # both email and notification. LP17755057
            assert_difference [ "Event.count" ], 2 do
              assert_difference [ "ActionMailer::Base.deliveries.size" ], @@mail_count * 2 do
                ref_data = update_key(key.id, {
                                        admin: 'false',
                                        time_constraints: [{
                                                             start_time: "5:00:00",
                                                             end_time: "14:00:00"
                                                           }]
                                    }, @user_device)
                check_response
              end
            end
          end
        end
        log_json(response, "Keys PUT")
        new_key = check_replaced_key(key, now)
        # Order not specified.
        swapped = put_event_last(EventType::ACCESS_CHANGED)
        check_admin_event(@@ev_first, key.lock, @guest_user, @user, EventType::ADMIN_REVOKED, __LINE__)
        check_access_event(@@ev_second, new_key, nil, __LINE__)
        check_key_db_update_reply(new_key, ref_data, nil, __LINE__)
        check_locks_user(@lock, key.user_id, false)
        # Check that the right mails were sent
        mail1 = ActionMailer::Base.deliveries[ActionMailer::Base.deliveries.count-2]
        mail2 = ActionMailer::Base.deliveries.last
        if swapped
          tmp = mail2
          mail2 = mail1
          mail1 = tmp
        end
        if mail1
          assert_match /Open the Goji App/, mail1.body.to_s
          assert_match "restricted",        mail1.body.to_s
        end
        if mail2
          assert_match /Open the Goji App/, mail2.body.to_s
          assert_match "given new access times", mail2.body.to_s
        end
      end

      it "should reject unparsable start_date" do
        key = Key.last
        # admin_shared only, no access_changed when becoming admin
        ref_data = update_key(key.id, {
                                start_date: "garbage"
                              }, @user_device)
        check_response 422, Util.VALIDATOR_MSGS[:DATE]
      end

      it "should reject unparsable end_date" do
        key = Key.last
        # admin_shared only, no access_changed when becoming admin
        ref_data = update_key(key.id, {
                                end_date: "abcdefg"
                              }, @user_device)
        check_response 422, Util.VALIDATOR_MSGS[:DATE]
      end

      it "should reject end_date before start_date" do
        key = Key.last
        # admin_shared only, no access_changed when becoming admin
        ref_data = update_key(key.id, {
                                start_date: (DateTime.now+1.day).utc.iso8601(3),
                                end_date:  (DateTime.now).utc.iso8601(3),
                              }, @user_device)
        check_response 422, Util.VALIDATOR_MSGS[:DATE_ORDER]
      end

      it "should reject unparsable tc.start_time" do
        key = Key.last
        # admin_shared only, no access_changed when becoming admin
        update_key(key.id, {
                     time_constraints: [{
                                          monday: "true",
                                          wednesday: "true",
                                          start_time: "abcdefg",
                                          end_time: "18:00Z"
                                        }]
                   }, @user_device)
        check_response 422, Util.VALIDATOR_MSGS[:TIME]
      end

      it "should reject unparsable tc.end_time" do
        key = Key.last
        # admin_shared only, no access_changed when becoming admin
        update_key(key.id, {
                     time_constraints: [{
                                          monday: "true",
                                          wednesday: "true",
                                          start_time: "18:00Z",
                                          end_time: "b"
                                        }]
                   }, @user_device)
        check_response 422, Util.VALIDATOR_MSGS[:TIME]
      end

      it "should reject tc.start_time later than tc.end_time" do
        key = Key.last
        # admin_shared only, no access_changed when becoming admin
        update_key(key.id, {
                     time_constraints: [{
                                          start_time: "18:01Z",
                                          end_time: "18:00Z"
                                        }]
                   }, @user_device)
        check_response 422, Util.VALIDATOR_MSGS[:TIME_ORDER]
      end

      it "should allow tc.start_time equal to tc.end_time.  At least it does, even though it's a disabled key!" do
        key = Key.last   #user3 non-admin key, no constraints.
        # ??? what admin_shared?  What's in @@ev_first???
        # admin_shared only, no access_changed when becoming admin
        ref_data = nil
        now = DateTime.now
        assert_no_difference [ "LocksUser.count"] do
          # access_changed
          assert_difference [ "Key.count", "Event.count"], 1 do
            assert_difference [ "ActionMailer::Base.deliveries.size" ], @@mail_count do
              ref_data = update_key(key.id, {
                                      time_constraints: [{
                                                           start_time: "18:00Z",
                                                           end_time: "18:00Z"
                                                         }]
                                    }, @user_device)
              check_response
            end
          end
        end
        new_key = check_replaced_key(key, now)
        check_access_event(Event.last, new_key, nil, __LINE__)
        check_key_db_update_reply(new_key, ref_data, nil, __LINE__)
        check_locks_user(@lock, key.user_id, false)
        # email checked above.
      end

      it "should reject unparsable tc.start_offset" do
        key = Key.last
        # admin_shared only, no access_changed when becoming admin
        update_key(key.id, {
                     time_constraints: [{
                                          monday: "true",
                                          wednesday: "true",
                                          start_offset: "abcd",
                                          # Tests start_and_end_offset override
                                          # But result (no start_and_end_offset message) not checked
                                          end_offset: "-110"
                                        }]
                   }, @user_device)
        check_response 422, Util.VALIDATOR_MSGS[:INTEGER]
      end

      it "should reject tc.start_offset later than tc.end_offset" do
        key = Key.last
        # admin_shared only, no access_changed when becoming admin
        update_key(key.id, {
                     time_constraints: [{
                                          monday: "true",
                                          wednesday: "true",
                                          start_offset: "252",
                                          end_offset: "110"
                                        }]
                   }, @user_device)
        check_response 422, Util.VALIDATOR_MSGS[:OFFSET_ORDER]
      end

      it "should update the key with many fields, make them admin, then not, creating admin events, access event on not admin only" do
        key = Key.last
        check_locks_user(@lock, key.user_id, false)
        ref_data = nil
        assert_no_difference [ "LocksUser.count", "Key.count"] do
          # admin_shared only, no access_changed when becoming admin
          assert_difference [ "Event.count"], 1 do
            ref_data = update_key(key.id, {
                                    is_fob: true,
                                    auto_unlock: 'true',
                                    use_limit:  100,
                                    admin: 'true',
                                  }, @user_device)
          end
        end
        log_json(response, "Keys PUT")
        # XXX make a utility to fully validate response
        check_response 200
        check_admin_event(Event.last, key.lock, @guest_user, @user, EventType::ADMIN_SHARED, __LINE__)
        key.reload
        # Errors, but processes admin change and clears time restrictions
        ref_data[:start_date] = nil
        # But no response body!
        check_key_db(key, ref_data, __LINE__)
        check_locks_user(@lock, key.user_id, true)

        # now make not admin
        now = DateTime.now
        assert_no_difference [ "LocksUser.count"] do
          assert_difference [ "Key.count"], 1 do
            # admin_revoked+access_changed
            assert_difference [ "Event.count" ], 2 do
              assert_difference [ "ActionMailer::Base.deliveries.size" ], @@mail_count * 2 do
                ref_data = update_key(key.id, {
                                        start_date: DateTime.now.utc.iso8601(3),
                                        end_date:  (DateTime.now+1.day).utc.iso8601(3),
                                        admin: 'false',
                                      }, @user_device)
                check_response
              end
            end
          end
        end
        new_key = check_replaced_key(key, now)
        check_key_db_update_reply(new_key, ref_data, nil, __LINE__)
        # Order not specified.
        put_event_last(EventType::ACCESS_CHANGED)
        check_admin_event(@@ev_first, key.lock, @guest_user, @user, EventType::ADMIN_REVOKED, __LINE__)
        check_access_event(@@ev_second, new_key, nil, __LINE__)
        check_locks_user(@lock, key.user_id, false)
        # email checked above.
      end

      it "should update the key with one field, not make a LocksUser record/admin" do
        key = Key.last
        ref_data = nil
        assert_no_difference [ "Key.count", "LocksUser.count", "Event.count"] do
          ref_data = update_key(key.id, nil, @user_device)
          check_response
        end
        key.reload
        check_key_db_reply(key, ref_data, nil, __LINE__)
      end

      it "LP21938390 should correctly update/create key when moving from recurring to anytime" do
        key = Key.last

        # Make it a recurring key to start
        key.time_constraints << TimeConstraint.new(monday: true, tuesday: true)
        key.save!
        assert_equal 1, key.time_constraints.length

        # Modify it to be a anytime key
        assert_no_difference "Key.active_keys.count", "TimeConstraint.count" do
          assert_difference ["Key.count", "Event.count"], +1 do
            update_key(key.id, {}, @user_device)
          end
        end

        key = Key.last
        assert_equal 0, key.time_constraints.length
      end

      it "should wipe out start/end date on change unless supplied" do
        key = Key.last
        key.start_date = 2.days.ago
        key.end_date = 1.day.ago
        key.pending = true # actually already is...
        key.save!
        #key.lock.credentials_changed

        ref_data = nil
        request = {
          time_constraints: [{
                               monday: "true",
                               wednesday: "true",
                               thursday: "true",
                               start_time: "14:00Z",
                               end_time: "18:00Z",
                             }]
        }
        now = DateTime.now
        assert_no_difference [ "LocksUser.count"] do
          assert_difference [ "Key.count", "Event.count"], 1 do
            ref_data = update_key(key.id, request,  @user_device)
            check_response
          end
        end

        new_key = check_replaced_key(key, now)
        assert_not_nil key.end_date
        assert_not_nil key.start_date
        assert_nil new_key.end_date
        assert_nil new_key.start_date

        assert_true key.pending, "old key is still pending"
        # XXX check not-pending in another test.
        assert_true new_key.pending, "new key is still pending"
        check_key_db_update_reply(new_key, ref_data, nil, __LINE__)
      end

      def check_replaced_key(key, now)
        old_key = key.dup
        key.reload
        check_now_date(key.replaced_at, "replaced_at", now)
        new_key = Key.all.order('created_at ASC').last
        assert_equal key.replaced_at, new_key.created_at
        key.replaced_at = nil
        check_unchanged_record(old_key, key)
        assert_true new_key.lock.new_credentials, "lock.new_credentials true"
        return new_key
      end

      # .dup is a shallow copy, no tc's, no id/created_at/updated_at
      def check_unchanged_record(duped, new)
        duped.updated_at = new.updated_at
        duped.created_at = new.created_at
        duped.id = new.id
        assert_equal duped, new, "original record unchanged"
      end

      it "should update the key start_date field and create access_changed event" do
        key = Key.last
        ref_data = nil
        now = DateTime.now
        assert_no_difference [ "LocksUser.count"] do
          assert_difference [ "Key.count", "Event.count"], 1 do
            ref_data = update_key(key.id, {
                                    start_date: DateTime.now.utc.iso8601(3),
                                  }, @user_device)
            check_response
          end
        end
        new_key = check_replaced_key(key, now)
        check_key_db_update_reply(new_key, ref_data, nil, __LINE__)
        check_access_event(Event.last, new_key, nil, __LINE__)
      end
      it "should update the key end_date field and create access_changed event" do
        key = Key.last
        ref_data = nil
        now = DateTime.now
        assert_no_difference [ "LocksUser.count"] do
          assert_difference [ "Key.count", "Event.count"], 1 do
            ref_data = update_key(key.id, {
                                    end_date: DateTime.now.utc.iso8601(3),
                                  }, @user_device)
            check_response
          end
        end
        new_key = check_replaced_key(key, now)
        check_key_db_update_reply(new_key, ref_data, nil, __LINE__)
        check_access_event(Event.last, new_key, nil, __LINE__)
      end

      it "should update the key expired end_date field and create access_changed and expired events" do
        key = Key.last
        ref_data = nil

        assert_no_difference ["LocksUser.count"] do
          assert_difference ["Key.count", "Event.count"], 1 do
            assert_difference "Notification.count", +2 do
              ref_data = update_key(key.id, {
                                  #authtoken: @user.account.authentication_token,
                                  end_date: (DateTime.now - 1.minute).utc.iso8601(3),
                                  }, @user_device)
              assert_equal Event.last.event_type, EventType::ACCESS_CHANGED
              assert Notification.last.message =~ /access times for Front Door have been changed/
              check_response
            end
          end
        end

        # TODO this is broken, or it may be broken above and fail here
        # Error is: ActiveRecord::RecordInvalid: Validation failed: The Lock does not belong to the user
        #assert_difference "Notification.count", +3 do
        #  assert_difference "Event.count", +1 do
        #    Key.notify_expired_keys
        #    assert_equal Event.last.event_type, EventType::KEY_EXPIRED
        #    assert Notification.last.message =~ /has expired/
        #  end
        #end
      end

      it "should update the key with time_constraints and create access_changed event" do
        key = Key.last
        ref_data = nil
        request = {
          time_constraints: [{
                               monday: "true",
                               wednesday: "true",
                               thursday: "true",
                               start_offset: "150",
                               end_offset: "250",
                             }]
        }
        now = DateTime.now
        assert_no_difference [ "LocksUser.count"] do
          assert_difference [ "Key.count", "Event.count"], 1 do
            ref_data = update_key(key.id, request, @user_device)
            check_response
          end
        end
        new_key = check_replaced_key(key, now)
        check_key_db_update_reply(new_key, ref_data, nil, __LINE__)
        check_access_event(Event.last, new_key, nil, __LINE__)

        # Again!
        request[:time_constraints][0][:start_offset] = nil
        now = DateTime.now
        assert_no_difference [ "LocksUser.count"] do
          assert_difference [ "Key.count", "Event.count"], 1 do
            ref_data = update_key(key.id, request, @user_device)
            check_response
          end
        end
        new_key = check_replaced_key(key, now)
        check_key_db_update_reply(new_key, ref_data, nil, __LINE__)
        check_access_event(Event.last, new_key, nil, __LINE__)

        # Again!
        request[:time_constraints][0][:friday] = "true"
        now = DateTime.now
        assert_no_difference [ "LocksUser.count"] do
          assert_difference [ "Key.count", "Event.count"], 1 do
            ref_data = update_key(key.id, request, @user_device)
            check_response
          end
        end
        new_key = check_replaced_key(key, now)
        check_key_db_update_reply(new_key, ref_data, nil, __LINE__)
        check_access_event(Event.last, new_key, nil, __LINE__)

        # Again!
        request[:time_constraints][0][:friday] = "false"
        now = DateTime.now
        assert_no_difference [ "LocksUser.count"] do
          assert_difference [ "Key.count", "Event.count"], 1 do
            ref_data = update_key(key.id, request, @user_device)
            check_response
          end
        end
        new_key = check_replaced_key(key, now)
        check_key_db_update_reply(new_key, ref_data, nil, __LINE__)
        check_access_event(Event.last, new_key, nil, __LINE__)
      end
      it "should update the key with the same time_constraints and create no access_changed event" do
        key = Key.last
        ref_data = {
          time_constraints: [{
                               monday: "true",
                               wednesday: "true",
                               thursday: "true",
                               start_offset: "-150",
                               end_offset: "350",
                             }]
        }
        now = DateTime.now
        ref_data = update_key(key.id, ref_data, @user_device)
        key = check_replaced_key(key, now)
        ref_data[:time_constraints][0][:wednesday] = "true"
        assert_no_difference [ "Key.count", "LocksUser.count", "Event.count"] do
          ref_data = update_key(key.id, ref_data, @user_device)
          check_response
        end
        key.reload
        check_key_db_reply(key, ref_data, nil, __LINE__)
      end

      it "should update the key with empty then nil time_constraints and create no access_changed events" do
        key = Key.last
        ref_data = {
          time_constraints: [],
        }
        assert_no_difference [ "Key.count", "LocksUser.count", "Event.count"] do
          ref_data = update_key(key.id, ref_data, @user_device)
          check_response
        end
        key.reload
        check_key_db_reply(key, ref_data, nil, __LINE__)

        ref_data[:time_constraints] = nil
        assert_no_difference [ "Key.count", "LocksUser.count", "Event.count"] do
          ref_data = update_key(key.id, ref_data, @user_device)
          check_response
        end
        key.reload
        check_key_db_reply(key, ref_data, nil, __LINE__)
      end

      it "should not cause an admin event notification if updated with admin=false" do
        key = Key.last
        ref_data = {
          admin: false,
          start_date: "2020-08-08T21:30:00.000Z",
          end_date: "2020-08-09T21:30:00.000Z",
        }
        now = DateTime.now
        assert_no_difference [ "LocksUser.count"] do
          # Access changed event only
          assert_difference [ "Key.count", "Event.count"], 1 do
            ref_data = update_key(key.id, ref_data, @user_device)
          end
        end
        assert_equal "access_changed", Event.last.event_type
        new_key = check_replaced_key(key, now)
        check_key_db_update_reply(new_key, ref_data, nil, __LINE__)
      end

      it "should update the key with time constraints that use offsets" do
        key = Key.last
        ref_data = {
          time_constraints: [
            monday: true,
            wednesday: true,
            start_offset: -115,
            end_offset: 85,
          ],
        }
        now = DateTime.now
        assert_no_difference [ "LocksUser.count"] do
          assert_difference [ "Key.count", "Event.count"], 1 do
            ref_data = update_key(key.id, ref_data, @user_device)
          end
        end
        new_key = check_replaced_key(key, now)
        # XXX goes away when check_key_data checks tc's
        assert_equal ref_data[:time_constraints][0][:start_offset], new_key.time_constraints.first.start_offset
        assert_equal ref_data[:time_constraints][0][:end_offset],   new_key.time_constraints.first.end_offset
        check_key_db_update_reply(new_key, ref_data, nil, __LINE__)
      end

#  TODO There a few edge cases around both keys with time constraints always allowing, and keys with time constraints that never allow
#  To come back to at a later date.
#      it "updating with empty then effectively empty time_constraints should create no access_changed events" do
#        key = Key.last
#        ref_data = {
#          authtoken: @user.account.authentication_token,
#          time_constraints: [],
#        }
#        assert_no_difference [ "Key.count", "LocksUser.count", "Event.count"] do
#          ref_data = update_key(key.id, ref_data, @user_device)
#          check_response
#        end
#        key.reload
#        check_key_db_reply(key, ref_data, nil, __LINE__)
#
#        ref_data[:time_constraints] = [{
#                               sunday: "true",
#                               monday: "true",
#                               tuesday: "true",
#                               wednesday: "true",
#                               thursday: "true",
#                               friday: "true",
#                               saturday: "true",
#                               start_time: "00:00Z",
#                               end_time: "24:00Z",
#                             }]
#        assert_no_difference [ "Key.count", "LocksUser.count", "Event.count"] do
#          ref_data = update_key(key.id, ref_data)
#          check_response
#        end
#        key.reload
#        check_key_db_reply(key, ref_data, nil, __LINE__)
#
#        ref_data[:time_constraints] = [{
#                               start_time: "00:00Z",
#                               end_time: "24:00Z",
#                             }]
#        assert_no_difference [ "Key.count", "LocksUser.count", "Event.count"] do
#          ref_data = update_key(key.id, ref_data)
#          check_response
#        end
#        key.reload
#        check_key_db_reply(key, ref_data, nil, __LINE__)
#      end
      it "updating with effectively same nil/false time_constraints should create no access_changed event" do
        key = Key.last
        tc = [{
                sunday: "true",
                monday: "true",
                tuesday: "true",
                wednesday: "true",
                thursday: "true",
                friday: false,
              }]
        ref_data = {
          time_constraints: tc,
        }
        now = DateTime.now
        ref_data = update_key(key.id, ref_data, @user_device)
        key = check_replaced_key(key, now)
        tc[0][:friday] = nil
        tc[0][:saturday] = false
        ref_data[:time_constraints] = tc
        assert_no_difference [ "Key.count", "LocksUser.count", "Event.count"] do
          ref_data = update_key(key.id, ref_data, @user_device)
          check_response
        end
        key.reload
        check_key_db_reply(key, ref_data, nil, __LINE__)
      end
      # Trivial bug not tested: enter admin with empty time_constraints, currently errors

      # No need to retest in PUT, same code:
      # "admins should NOT be able to create an admin key for a new non-admin account" do

    end

    describe "delete action" do
      subject { KeysController }
      before do
        DatabaseCleaner.start
        @routes = Rails.application.routes
        @user, @device, @user_device = make_user
        @lock = make_lock(@user)
        @user2, @device2, @user_device2  = make_user('glenn2@example.com')
        create_basic_key(@user.account.email, @lock, @user_device)
      end

      after do
        DatabaseCleaner.clean
      end

      it "marks a guest key as revoked when deleted by the owner" do
        key = Key.last
        send_auth(@user_device)
        delete(:destroy, :id => key.id)
        check_response
        key.reload
        check_now_date(key.revoked, "revoked")
      end

      it "marks an admin key as revoked when deleted by the owner" do
        assert_difference ["LocksUser.count"], +1 do
          create_basic_key(@user2.account.email, @lock, nil, { admin: 'true' })
        end
        @user2.reload
        @lock.reload

        key = Key.last
        assert_difference [ "LocksUser.count"], -1 do
          send_auth(@user_device)
          delete(:destroy, :id => key.id)
          check_response
        end
        key.reload
        check_now_date(key.revoked, "revoked")
      end

      it "marks a guest key as revoked when deleted by the admin" do
        create_basic_key(@user2.account.email, @lock, nil)
        key = Key.last
        @user4, @device4, @user_device4 = make_user('person@example.com')
        make_admin_user(@lock, @user4)
        send_auth(@user_device4)
        delete(:destroy, :id => key.id)
        check_response 200
        key.reload
        check_now_date(key.revoked, "revoked")

        # Spot check to make sure the user on the event is the admin
        assert_equal EventType::KEY_REVOKED, Event.last.event_type
        assert_equal @user4.id, Event.last.user_id
      end

      it "returns unauthorized when a person other than the admin and owner attempt to revoke key" do
        key = Key.last
        @user4, device, user_device = make_user('person@foo.com')
        send_auth(user_device)
        delete(:destroy, :id => key.id)
        check_response :unauthorized, :UNAUTHORIZED
      end

      it "returns unauthorized when an admin tries to revoke another admin's key" do
        create_basic_key(@user2.account.email, @lock, nil, {admin: 'true'})
        key = Key.last
        @user4, device, user_device = make_user('person@example.com')
        make_admin_user(@lock, @user4)
        send_auth(user_device)
        delete(:destroy, :id => key.id)
        check_response :unauthorized, :UNAUTHORIZED
      end

      it "returns key not found when trying to destroy a non-existent key" do
        key = Key.last
        send_auth(@user_device)
        delete(:destroy, :id => key.id + 1)
        check_response 404
      end

      it "returns already revoked when trying to destroy a revoked key" do
        key = Key.last
        send_auth(@user_device)
        delete(:destroy, :id => key.id)
        send_auth(@user_device)
        delete(:destroy, :id => key.id)
        check_response 422
      end


      it "should cause and event but no notifications when a revoking an expired key" do
        key = Key.last
        key.end_date = 2.days.ago
        key.save!

        assert_no_difference "Notification.count" do
          send_auth(@user_device)
          delete(:destroy, :id => key.id)
        end
        assert_equal EventType::KEY_REVOKED, Event.last.event_type
      end


      # LP19872663
      # Note: I don't believe this applies to alpha2 code...due to alpha2 creating a new key record on each edit
      it "should clear the expired notification generated flag on key update and seton notify" do
        key = Key.last
        key.end_date = 2.days.ago
        key.expired_notification_generated = true
        key.save!

        ref_data = update_key(key.id, {
          end_date: 2.days.ago # Shouldn't actually matter what gets updated?
          }, @user_device)
        check_response 200
        resp = JSON.parse(@response.body)
        new_key = Key.find(resp["key_data"]["id"])
        assert_false new_key.expired_notification_generated, "expired_notification_generated flag cleared"

        Key.notify_expired_keys

        new_key.reload
        assert_true new_key.expired_notification_generated, "expired_notification_generated flag set"
        assert_equal     key.original_key_id, new_key.original_key_id, "original_key_id matches"
        assert_equal     key.original_key_id, key.id, "and matches original key id"
        assert_not_equal key.id, new_key.id, "yes it's a new key"
      end


      #TBD: Implement this test
      #Cannot be done due to the demo hack where there cannot be two keys with the same user

      # it "should not delete lock_users when deleting the next-to-last key belonging to a user" do
      #   assert_difference [ "LocksUser.count"], 1 do
      #    create_basic_key(@user2.account.email, @lock, { admin: 'true' })
      #   end
      #   key1 = Key.last
      #   assert_no_difference ["LocksUser.count"] do
      #     assert_difference "Key.count", 1 do
      #       create_basic_key(@user2.account.email, @lock, { admin: 'true'})
      #     end
      #   end
      #   key2 = Key.last
      # end
    end
  end

end
