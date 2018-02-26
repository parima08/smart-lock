require "test_helper"

class EventsControllerTest < ActionController::TestCase

  describe EventsController do

    subject { EventsController }

    before do
      DatabaseCleaner.start
      @routes = Rails.application.routes
      @user, @device, @user_device  = make_user
      @lock   = make_lock(@user)
      # A lock with no lock_user record:
      @locku2 = make_lock(@user)
      @key    = make_key(@lock, @user)
      @user2, @device2, @user_device2  = make_user('glenn2@example.com')
      @lock2  = make_lock(@user2)
      @key2   = make_key(@lock2, @user2)
      @user4, @device4, @user_device4  = make_user('glenn4@example.com')
      make_admin_user(@lock, @user4)
      @admin1_data = @make_admin_user_event_data
      make_admin_user(@lock, @user2)
      @admin2_data = @make_admin_user_event_data
      @event_time = comparable_payload_date_now
      @user3, @device3, @user_device3  = make_user('glenn3@example.com')
      @post1_data = {
        :lock_id => @lock.id,
        :key_id => @key.id,
        :event_time => @event_time,
        :event_type => EventType::LOCK,
        :string_value => CommandResult::SUCCESS,
        :bolt_state => BoltState::LOCKED,
      }
      @post2_data = @post1_data.dup
      @post2_data[:event_type] = EventType::UNLOCK
      @post2_data[:bolt_state] = BoltState::UNLOCKED
      @post3_data = @post2_data.dup
      # XXX test all failure responses from lock/unlock
      # XXX test for disallowed/missing values and ids per event type
      @post3_data[:event_type] = EventType::LOCK
      @post3_data[:string_value] = CommandResult::INVALID_KEY
      @post3_data[:bolt_state] = BoltState::UNLOCKED
      @post4_data = @post3_data.dup
      @post4_data[:key_id] = nil
      @post4_data[:bolt_state] = nil
      @post4_data[:event_type] = EventType::BATTERY
      @post4_data[:string_value] = BatteryState::LOW
      @post4_data[:int_value] = '0'
      @post5_data = {
        lock_id: @locku2.id,
        event_time: @event_time,
        event_type: EventType::LOCK_COM,
        string_value: LockCommState::LOCK_COMM_DOWN,
      }
      @post6_data = @post5_data.dup
      @post6_data[:event_type] = EventType::PROXIMITY
      @post6_data[:string_value] = ProximityEventType::INTO
      # manual unlock
      @post10_data = {
        :lock_id => @lock.id,
        #:key_id => nil,
        :event_time => @event_time,
        :event_type => EventType::LOCK,
        :string_value => CommandResult::SUCCESS,
        :bolt_state => BoltState::LOCKED,
      }
      @post11_data = @post10_data.dup
      @post11_data[:event_type] = EventType::UNLOCK
      @post11_data[:string_value] = CommandResult::HARDWARE_FAILURE
      @post12_data = {
             :lock_serial => @lock.lock_serial,
             :key_id => @key.id,
             :event_time => @event_time,
             :event_type => EventType::LOCK_COM,
             :string_value => LockCommState::LOCK_COMM_DOWN,
             :bolt_state => BoltState::UNLOCKED,
             :authtoken => nil
      }

      @post13_data = {
             :lock_serial => @lock.lock_serial,
             :key_id => @key.id,
             :event_time => @event_time,
             :event_type => EventType::ERROR_NOTIFY_SYSADMIN,
             :int_value => ErrorEventCode::ERR_EV_CODE_LOCK_REJECT_CREDENTIAL,
             :authtoken => nil
      }

      @post14_data = {
             :lock_serial => @lock.lock_serial,
             :key_id => @key.id,
             :event_time => @event_time,
             :event_type => EventType::ERROR_NOTIFY_OWNER_ADMIN,
             :int_value => ErrorEventCode::ERR_EV_CODE_INTERNAL_OTA_FAILURE,
             :authtoken => nil
      }

      @post15_data = {
             :lock_serial => @lock.lock_serial,
             :key_id => @key.id,
             :event_time => @event_time,
             :event_type => EventType::ERROR_NOTIFY_OWNER_ADMIN,
             :int_value => ErrorEventCode::ERR_EV_CODE_EXTERNAL_OTA_FAILURE,
             :authtoken => nil
      }

      @post16_data = {
             :lock_serial => @lock.lock_serial,
             :key_id => @key.id,
             :event_time => @event_time,
             :event_type => EventType::ERROR_NOTIFY_OWNER_ADMIN,
             :int_value => ErrorEventCode::ERR_EV_CODE_UNDEFINED,
             :authtoken => nil
      }

      # XXX add tests for key_shared/revoked
      # Be sure to include new events below in "collect all events"

      # For retrieve tests below.
      post(:create, @post1_data)
    end

    after do
      DatabaseCleaner.clean
    end

    it "must respond" do
      assert @routes
      check_response
    end

    it "should require a valid lock_id be sent" do
      # TODO: Validate against the eventual lock auth token
      post(:create, :lock_id => 0, :key_id => @key.id, :event_time => DateTime.now)
      check_response(404, :MISSING_RECORD)
    end

    it "should require a valid lock_serial be sent" do
      post(:create, :lock_serial => 0, :key_id => @key.id, :event_time => DateTime.now)
      check_response(404, :MISSING_RECORD)
    end

    it "should return some invalid parameter error on missing event attributes" do
      post(:create, :lock_id => @lock.id, :key_id => @key.id, :event_time => DateTime.now)
      check_response(422, :INVALID_PARAM)
    end

    it "should return invalid parameter error on empty event type" do
      post(:create, :lock_id => @lock.id, :key_id => @key.id,
           :event_time => DateTime.now,
           :event_type => "")
      check_response(422, :INVALID_PARAM)
    end

    it "should return invalid parameter error on bad event type" do
      post(:create, :lock_id => @lock.id, :key_id => @key.id,
           :event_time => DateTime.now,
           :event_type => "foo")
      check_response(422, :INVALID_PARAM)
    end

    it "should return invalid parameter error on missing bolt_state" do
      post(:create, :lock_id => @lock.id, :key_id => @key.id,
           :event_time => DateTime.now,
           :event_type => EventType::UNLOCK,
           :string_value => CommandResult::SUCCESS,
           )
      check_response(422, :INVALID_PARAM)
    end

    it "should return invalid parameter error on empty bolt_state" do
      post(:create, :lock_id => @lock.id, :key_id => @key.id,
           :event_time => DateTime.now,
           :event_type => EventType::UNLOCK,
           :string_value => CommandResult::SUCCESS,
           :bolt_state => "")
      check_response(422, :INVALID_PARAM)
    end

    it "should return invalid parameter error on bad bolt_state" do
      post(:create, :lock_id => @lock.id, :key_id => @key.id,
           :event_time => DateTime.now,
           :event_type => EventType::UNLOCK,
           :string_value => CommandResult::SUCCESS,
           :bolt_state => "foo")
      check_response(422, :INVALID_PARAM)
    end

    it "should return invalid parameter error on missing string_value" do
      post(:create, :lock_id => @lock.id, :key_id => @key.id,
           :event_time => DateTime.now,
           :event_type => EventType::UNLOCK,
           )
      check_response(422, :INVALID_PARAM)
    end

    it "should return invalid parameter error on empty string_value" do
      post(:create, :lock_id => @lock.id, :key_id => @key.id,
           :event_time => DateTime.now,
           :event_type => EventType::UNLOCK,
           :bolt_state => BoltState::UNLOCKED,
           :string_value => "")
      check_response(422, :INVALID_PARAM)
    end

    it "should return invalid parameter error on bad string_value" do
      post(:create, :lock_id => @lock.id, :key_id => @key.id,
           :event_time => DateTime.now,
           :event_type => EventType::UNLOCK,
           :bolt_state => BoltState::UNLOCKED,
           :string_value => "foo")
      check_response(422, :INVALID_PARAM)
    end

    it "should be able to use a lock_serial instead of id" do
      assert_difference('Event.count', 1) do
        post(:create, :lock_serial => @lock.lock_serial, :key_id => @key.id, :event_time => @event_time,
             :event_type => EventType::UNLOCK,
             :string_value => CommandResult::SUCCESS,
             :bolt_state => BoltState::UNLOCKED)
        check_response
      end
      assert_equal @lock.id, Event.last.lock_id
    end

    it "should return 422 when a key not belonging to the lock is sent" do
      assert_equal @lock.id, Event.last.lock_id
      @user2, device, user_device = make_user('person@example.com', 'aba456')
      @lock2 = make_lock(@user2)
      post(:create, :lock_id => @lock2.id, :key_id => @key.id,
           :event_time => DateTime.now,
           :event_type => EventType::UNLOCK)
      check_response(422)
    end

    it "should return 422 when a lock not belonging to the user is sent" do
      assert_equal @lock.id, Event.last.lock_id
      @user2, device, user_device = make_user('person@example.com', 'aba456')
      @lock2 = make_lock(@user2)
      post(:create, :lock_id => @lock.id, :key_id => @key.id, :user_id => 888,
           :event_time => DateTime.now,
           :event_type => EventType::UNLOCK)
      check_response(422)
    end

=begin
    # This doesn't tell us very much
    it "should have valid fields" do
      ae = Event.all.order('created_at ASC')
      # make_admin_user creates admin_shared event.
      # Cannot construct exact test refeence date for .now.
      #check_data(ae[0], @admin1_data, nil, true)
      #check_data(ae[1], @admin2_data, nil, true)
    end

    #XXX see locks_users_controller_test
    it "invalid test: bad lock_id param" do
        # id's continue to increment after db clean, pick a number always higher.
        get(:index, :authtoken => @user.account.authentication_token, :lock_id => @lock.id+66)
        check_response :bad_request
    end

    it "should notbe able to retrieve events if not lock owner/admin" do
        get(:index, :authtoken => @user3.account.authentication_token, :lock_id => @lock.id)
        check_response :unauthorized
    end
=end

    it "should be able to retrieve all events for lock_id" do
      send_auth(@user_device)
      get(:index, :lock_id => @lock.id)
      @json = JSON.parse(response.body)
      assert_equal 4, @json.count
      assert_equal @json[0]["lock_id"], @lock.id
    end

    it "should be able to retrieve all events for lock_id as admin" do
      send_auth(@user_device)
      get(:index, :lock_id => @lock.id)
      @json = JSON.parse(response.body)
      assert_equal 4, @json.count
      assert_equal @json[0]["lock_id"], @lock.id
    end


    it "should be able to retrieve all events for all locks owned by current user" do
      send_auth(@user_device)
      get(:index)
      @json = JSON.parse(response.body)
      assert_equal 4, @json.count
      # Check order, default db order has been shown to be unpredictable.
      events = Event.all.order("events.event_time DESC, events.created_at DESC").to_a
      for i in 0..events.count-3 do
        check_event_data(events[i], @json[i])
      end
      # Skip key_shared event on lock2.
      check_event_data(events[events.count-1], @json[3])
    end

    it "should be able to update the lock wifi status" do
      @lock.reported_wifi_status = LockCommState::LOCK_COMM_DOWN
      @lock.save
      assert_difference "Event.count", +2 do
        post(:create, @post1_data)
      end
      @lock.reload
      assert_equal @lock.reported_wifi_status, LockCommState::LOCK_COMM_UP
      fuzzy_compare_datetime(Time.now, @lock.updated_at, 2)
    end

    it "should be able to retrieve all events for all locks admined by current user" do
      post(:create, @post1_data)
      send_auth(@user_device2)
      get(:index)
      @json = JSON.parse(response.body)
      assert_equal 6, @json.count
      assert_equal @json[0]["lock_id"], @lock.id
      assert_equal @json[1]["lock_id"], @lock.id
      assert_equal @json[2]["lock_id"], @lock.id
      assert_equal @json[3]["lock_id"], @lock.id
    end
    it "should retrieve no events not belonging to current user" do
      send_auth(@user_device3)
      get(:index)
      @json = JSON.parse(response.body)
      assert_equal 0, @json.count
    end

    it "should not retrieve events for decommmissioned lock" do
      send_auth(@user_device)
      @lock.decommission_date = DateTime.now
      @lock.save!
      get(:index)
      @json = JSON.parse(response.body)
      assert_equal 0, @json.count
    end

    def get_image
      File.open("#{Rails.root}/test/data/test.jpeg", 'r') do |f|
        @raw_file = f.read
        @encoded_file = Base64.encode64(@raw_file)
      end
    end

    it "should be able to correctly parse and save a base64 encoded image" do
      Event.destroy_all
      get_image
      post(:create,
           lock_id: @lock.id,
           key_id: @key.id,
           event_time: @event_time,
           event_type: EventType::LOCK,
           string_value: CommandResult::SUCCESS,
           bolt_state: BoltState::LOCKED,
           picture: {data: @encoded_file, content_type: 'image/jpeg', original_filename: 'test.jpeg'})

      s3_file_url   = Event.first.picture.data.expiring_url
      # print "s3_file_url=" + s3_file_url
      s3_file       = HTTParty.get(s3_file_url).body
      @raw_file.bytes.each_with_index do |char, i|
        if s3_file.bytes[i] != char
          print "wrong char at " + i.to_s + ": #{char}  #{s3_file.bytes[i]}\n"
          print "s3_file=" + s3_file
        end
        assert_equal s3_file.bytes[i], char
      end
    end

    def check_picture(check_invalid = false)
      resp = JSON.parse(@response.body)
      first = resp[0]
      url = first["picture_url"]
      e_pic_id = first["picture_id"]
      assert_not_nil Picture.last, "picture should be present"
      picture_id = Picture.last.id
      assert_not_nil e_pic_id, "picture id should be present"
      assert_equal picture_id, e_pic_id, "wrong picture id"
      assert_not_nil url, "picture url should be present"
      assert url.include?('http'), 'does not look like a valid url: ' + url
      s3_file       = HTTParty.get(url)
      assert_equal String, s3_file.parsed_response.class, "expected no error hash from S3, but got " + s3_file.parsed_response.to_s
      # Tests below are expensive, especially sleep.
      return if !check_invalid

      # Trash the S3 signature, make sure the url doesn't work.
      s3_file       = HTTParty.get(url + "A")
      assert_equal Hash, s3_file.parsed_response.class, "expected error hash from S3 due to bad signature"
      plain_url = url.slice(0, url.index("?"))
      s3_file       = HTTParty.get(plain_url)
      assert_equal Hash, s3_file.parsed_response.class, "expected error hash from S3, due to no credentials"
      # expire isn't terribly accurate, oh well.
      sleep GojiServer.config.s3_url_expire + 3
      s3_file       = HTTParty.get(url)
      assert_equal Hash, s3_file.parsed_response.class, "expected error hash from S3, due to expired url"
    end

    def check_no_picture(delay = false)
      resp = JSON.parse(@response.body)
      first = resp[0]
      url = first["picture_url"]
      e_pic_id = first["picture_id"]
      assert_not_nil Picture.last, "picture should be present"
      assert_nil e_pic_id, "picture id should not be present in event"
      assert_nil url, "picture url should not be present in event"
      if delay != "skip_pending"
        assert_not_nil first["picture_pending"], "picture_pending should be present"
        assert_equal !delay, first["picture_pending"].to_b, "picture_pending should be " + (!delay).to_s
      end
    end

    it "should return the picture url when an event has a picture, with security" do
      get_image

      # Setup... this isn't done in before, because it'd cause an upload for every event.
      assert_difference "Event.count", +1 do
        post(:create,
             lock_id: @lock.id,
             key_id: @key.id,
             event_time: comparable_payload_date_now,
             event_type: EventType::UNLOCK,
             string_value: CommandResult::SUCCESS,
             bolt_state: BoltState::UNLOCKED,
             picture: {data: @encoded_file, content_type: 'image/jpeg', original_filename: 'test.jpeg'})
        check_response
      end

      # Now we get the events list, as user would in the app
      send_auth(@user_device)
      get(:index)
      check_picture
    end

    # TODO: dup in an integration test, using actual POST /pictures ?
    it "should return the picture url when picture time is before event time" do
      # XXX LP17822243: use the time shifter Parima added,
      # when we disallow uploads with unreasonable taken_at v.s. .now
      get_image
      pic = Picture.create!(data: StringIO.new(@raw_file),
                            lock: @lock,
                            taken_at: DateTime.parse(@event_time) - 1.second,
                            data_content_type: 'image/jpeg',
                            data_file_name:    'test.jpeg')
      assert_not_nil pic, "picture should be created"
      send_auth(@user_device)
      get(:index)
      check_picture("check_invalid")
    end

    it "should return the picture url when picture time is 4 seconds after event time" do
      get_image
      pic = Picture.create!(data: StringIO.new(@raw_file),
                            lock: @lock,
                            taken_at: DateTime.parse(@event_time) + (ApplicationController.MAX_PICTURE_SKEW - 1).seconds,
                            data_content_type: 'image/jpeg',
                            data_file_name:    'test.jpeg')
      send_auth(@user_device)
      get(:index)
      check_picture
    end

    it "should not return the picture url when picture time is 6 seconds after event time" do
      get_image
      pic = Picture.create!(data: StringIO.new(@raw_file),
                            lock: @lock,
                            taken_at: DateTime.parse(@event_time) + (ApplicationController.MAX_PICTURE_SKEW + 1).seconds,
                            data_content_type: 'image/jpeg',
                            data_file_name:    'test.jpeg')
      send_auth(@user_device)
      get(:index)
      check_no_picture
    end

    it "should not return the picture url for a non-photo event" do
      Event.delete_all
      post(:create, @post4_data) # BATTERY
      get_image
      pic = Picture.create!(data: StringIO.new(@raw_file),
                            lock: @lock,
                            taken_at: Event.last.event_time,
                            data_content_type: 'image/jpeg',
                            data_file_name:    'test.jpeg')
      send_auth(@user_device)
      get(:index)
      check_no_picture("skip_pending")
    end

    it "should return the picture url for a proximity event" do
      Event.delete_all
      get_image
      @post6_data[:lock_id] = @lock.id
      post(:create, @post6_data) # PROXIMITY
      pic = Picture.create!(data: StringIO.new(@raw_file),
                            lock: @lock,
                            taken_at: Event.last.event_time,
                            data_content_type: 'image/jpeg',
                            data_file_name:    'test.jpeg')
      send_auth(@user_device)
      get(:index)
      check_picture
    end

    it "should not return the picture url when picture is uploaded for different lock" do
      get_image
      Event.delete_all
      post(:create, @post6_data) # PROXIMITY, @locku2
      pic = Picture.create!(data: StringIO.new(@raw_file),
                            lock: @lock,
                            taken_at: Event.last.event_time,
                            data_content_type: 'image/jpeg',
                            data_file_name:    'test.jpeg')
      assert_not_nil pic, "picture should be created"
      send_auth(@user_device)
      get(:index)
      check_no_picture
    end

    it "should not return the picture url when picture time is before window" do
      get_image
      pic = Picture.create!(data: StringIO.new(@raw_file),
                            lock: @lock,
                            taken_at: DateTime.parse(@event_time) - ApplicationController.MAX_PICTURE_ASYNC_TIME - 1.second,
                            data_content_type: 'image/jpeg',
                            data_file_name:    'test.jpeg')
      assert_not_nil pic, "picture should be created"
      send_auth(@user_device)
      get(:index)
      check_no_picture
      # Picture taken at event time could show up MAX_PICTURE_ASYNCH
      # after event, so we make app wait before giving up.
      Timecop.freeze(ApplicationController.MAX_PICTURE_ASYNC)
      send_auth(@user_device)
      get(:index)
      check_no_picture("delayed")
      # Too busy.
      #log_json(response, "Events GET picture_pending")
      Timecop.return
    end

    it "should not return the picture url when picture time is before window, reconfigured" do
      ENV["MAX_PICTURE_ASYNC"]="2"
      assert_equal 2.seconds, ApplicationController.MAX_PICTURE_ASYNC_TIME
      get_image
      pic = Picture.create!(data: StringIO.new(@raw_file),
                            lock: @lock,
                            taken_at: DateTime.parse(@event_time) - ApplicationController.MAX_PICTURE_ASYNC_TIME - 1.second,
                            data_content_type: 'image/jpeg',
                            data_file_name:    'test.jpeg')
      assert_not_nil pic, "picture should be created"
      send_auth(@user_device)
      get(:index)
      check_no_picture
      Timecop.freeze(ApplicationController.MAX_PICTURE_ASYNC)
      send_auth(@user_device)
      get(:index)
      check_no_picture("delayed")
      Timecop.return
    end

    it "should return the picture url when picture is uploaded asyncronously, event time just before time window closes" do
      # LP17822243 Ditto
      get_image
      pic = Picture.create!(data: StringIO.new(@raw_file),
                            lock: @lock,
                            taken_at: DateTime.parse(@event_time) - ApplicationController.MAX_PICTURE_ASYNC_TIME + 1.second,
                            data_content_type: 'image/jpeg',
                            data_file_name:    'test.jpeg')
      assert_not_nil pic, "picture should be created"
      send_auth(@user_device)
      get(:index)
      check_picture
      # retest for picture id caching.
      send_auth(@user_device)
      get(:index)
      check_picture
    end

    it "should return the most recent picture url when two pictures are uploaded asyncronously" do
      # LP17822243 Ditto
      get_image
      pic = Picture.create!(data: StringIO.new(@raw_file),
                            lock: @lock,
                            taken_at: DateTime.parse(@event_time) - ApplicationController.MAX_PICTURE_ASYNC_TIME + 1.second,
                            data_content_type: 'image/jpeg',
                            data_file_name:    'test.jpeg')
      assert_not_nil pic, "picture should be created"
      pic = Picture.create!(data: StringIO.new(@raw_file),
                            lock: @lock,
                            taken_at: DateTime.parse(@event_time) - ApplicationController.MAX_PICTURE_ASYNC_TIME + 2.seconds,
                            data_content_type: 'image/jpeg',
                            data_file_name:    'test.jpeg')
      assert_not_nil pic, "picture should be created"
      send_auth(@user_device)
      get(:index)
      check_picture
      # retest for picture id caching.
      send_auth(@user_device)
      get(:index)
      check_picture
    end

    it "should be able to retrieve single event" do
      send_auth(@user_device)
      last = Event.last
      get(:show, :id => last.id)
      @json = JSON.parse(response.body)
      check_event_data(last, @json)
    end

    it "should not retrieve an event if event id is empty" do
      send_auth(@user_device)
      get(:show, :id => '')
      check_response(404, :MISSING_RECORD)
    end

    it "should not retrieve an event if event id doesn't exist" do
      send_auth(@user_device)
      get(:show, :id => 99999)
      check_response(404, :MISSING_RECORD)
    end

    # API Tests
    it "should handle a lock event" do
      # XXX check notification counts in all of these, though mostly they should be covered in event_test.rb
      assert_difference('Event.count', 1) do
        # two admins, not triggering owner
        assert_difference('Notification.count', 2) do
          post(:create, @post1_data)
          check_response
        end
      end
      check_data_no_auth(@post1_data)
      # (reply is only status).
    end

    it "should handle a unlock event" do
      assert_difference('Event.count', 1) do
        post(:create, @post2_data)
        check_response
      end
      check_data_no_auth(@post2_data)
    end

    it "should handle a failed lock event" do
      assert_difference('Event.count', 1) do
        post(:create, @post3_data)
        check_response
      end
      check_data_no_auth(@post3_data)
    end

    it "should reject obsolete deny event" do
      assert_difference('Event.count', 0) do
        deny_data = @post3_data.dup
        deny_data[:event_type] = "deny"
        post(:create, deny_data)
        check_response 422
      end
    end

    it "should handle a battery event" do
      assert_difference('Event.count', 1) do
        post(:create, @post4_data)
        check_response
      end
      check_data_no_auth(@post4_data)
    end
    it "should handle a wifi event" do
      assert_difference('Event.count', 1) do
        post(:create, @post5_data)
        check_response
      end
      check_data_no_auth(@post5_data)
    end
    it "should handle a proximity event" do
      assert_difference('Event.count', 1) do
        post(:create, @post6_data)
        check_response
      end
      check_data_no_auth(@post6_data)
    end
=begin No Longer allowed through this endpoint
    it "should handle an admin_revoked event" do
      assert_difference('Event.count', 1) do
        post(:create, @post7_data)
        check_response
      end
      check_data_no_auth(@post7_data)
    end
    it "should handle an admin_shared event" do
      assert_difference('Event.count', 1) do
        post(:create, @post8_data)
        check_response
      end
      check_data_no_auth(@post8_data)
    end
=end
    it "should handle a manual lock event" do
      assert_difference('Event.count', 1) do
        # there is no triggering user, all users get notified.
        assert_difference('Notification.count', 3) do
          post(:create, @post10_data)
          check_response
        end
      end
      check_data_no_auth(@post10_data)
    end
    it "should handle a failed manual unlock event" do
      assert_difference('Event.count', 1) do
        assert_difference('Notification.count', 3) do
          post(:create, @post11_data)
          check_response
        end
      end
      check_data_no_auth(@post11_data)
    end


    # Clones of tests without Authtokens, and using lock_serial
    # TODO: Clone again to validate against the eventual lock auth token
    # For now, use lock_serial to bypass authentication, they are tied
    # together for alpha, but this connection will be removed for
    # production.

    def clone_serial_no_auth(post_data)
      post_data[:lock_serial] = Lock.find(post_data[:lock_id]).lock_serial
      post_data[:lock_id] = nil
      post_data[:authtoken] = nil
      post_data
    end

    # result is still with id, not serial
    def check_id_not_serial(ref, id = @lock.id)
      ref[:lock_id] = id
      check_data(Event.last, ref, [:lock_serial], true)
    end

    it "should not allow a lock_id be sent without authtoken" do
      post(:create, :lock_id => 0, :key_id => @key.id, :event_time => DateTime.now)
      check_response(404, :MISSING_RECORD)
    end

    it "should {TBD not} allow a lock_serial be sent without authtoken" do
      post(:create, :lock_serial => 0, :key_id => @key.id, :event_time => DateTime.now)
      check_response :not_found
    end

    it "should return missing record error on invalid lock id" do
      post(:create, :lock_id => 6666, :key_id => @key.id, :event_time => DateTime.now)
      check_response(404, :MISSING_RECORD)
    end

    it "should return missing record error on invalid lock serial" do
      post(:create, :lock_serial => 6666, :key_id => @key.id, :event_time => DateTime.now)
      check_response(404, :MISSING_RECORD)
    end

    it "should return missing params when lock id and lock serial are missing" do
      post(:create, :key_id => @key.id, :event_time => DateTime.now)
      check_response(422, :MISSING_ALL_PARAMS)
    end

    it "should be able to use a lock_serial instead of id without authtoken" do
      post_data = clone_serial_no_auth(@post2_data)
      assert_difference('Event.count', 1) do
        post(:create, post_data)
        check_response
      end

      check_id_not_serial(post_data)
    end

     it "should be able to correctly parse and save a base64 encoded image without authtoken" do
      Event.destroy_all
      File.open("#{Rails.root}/test/data/test.jpeg", 'r') do |f|
        @raw_file = f.read
        @encoded_file = Base64.encode64(@raw_file)
      end
      post(:create,
           :lock_serial => @lock.lock_serial,
           :key_id => @key.id,
           :event_time => @event_time,
           :event_type => EventType::UNLOCK,
           :string_value => CommandResult::SUCCESS,
           :bolt_state => BoltState::UNLOCKED,
           picture: {data: @encoded_file, content_type: 'image/jpeg', original_filename: 'test.jpeg'})

      s3_file_url   = Event.first.picture.data.expiring_url
      s3_file       = HTTParty.get(s3_file_url).body
      @raw_file.bytes.each_with_index do |char, i|
        if s3_file.bytes[i] != char
          print "wrong char at " + i.to_s + ": #{char}  #{s3_file.bytes[i]}\n"
          print "s3_file=" + s3_file
        end
        assert_equal s3_file.bytes[i], char
      end
    end

     it "should handle a lock event without authtoken" do
      post_data = clone_serial_no_auth(@post1_data)
      assert_difference('Event.count', 1) do
        post(:create, post_data)
        check_response
      end
      check_id_not_serial(post_data)
    end

    it "should handle a unlock event without authtoken" do
      post_data = clone_serial_no_auth(@post2_data)
      assert_difference('Event.count', 1) do
        post(:create, post_data)
        check_response
      end
      check_id_not_serial(post_data)
    end

    it "should handle a failed lock event without authtoken" do
      post_data = clone_serial_no_auth(@post3_data)
      assert_difference('Event.count', 1) do
        post(:create, post_data)
        check_response
      end
      check_id_not_serial(post_data)
    end

    it "should handle a battery event without authtoken" do
      post_data = clone_serial_no_auth(@post4_data)
      assert_difference('Event.count', 1) do
        post(:create, post_data)
        check_response
      end
      check_id_not_serial(post_data)
    end

    it "should handle a wifi event without authtoken" do
      id = @post5_data[:lock_id]
      post_data = clone_serial_no_auth(@post5_data)
      assert_difference('Event.count', 1) do
        post(:create, post_data)
        check_response
      end
      check_id_not_serial(post_data, id)
    end

    it "should handle a proximity event without authtoken" do
      id = @post6_data[:lock_id]
      post_data = clone_serial_no_auth(@post6_data)
      assert_difference('Event.count', 1) do
        post(:create, post_data)
        check_response
      end
      check_id_not_serial(post_data, id)
    end

    it "should not create not_allowed decommission event from lock without authtoken" do
      assert_difference('Event.count', 0) do
        post(:create, :lock_serial => @lock.lock_serial, :key_id => @key.id, :event_time => @event_time,
             :event_type => EventType::LOCK_DECOMMISSIONED,
             :authtoken => nil)
         check_response 422
      end
    end

    it "should not create not_allowed KEY_REVOKED event from lock without authtoken" do
       assert_difference('Event.count', 0) do
        post(:create, :lock_serial => @lock.lock_serial, :key_id => @key.id, :event_time => @event_time,
             :event_type => EventType::KEY_REVOKED,
             :string_value => CommandResult::SUCCESS,
             :bolt_state => BoltState::UNLOCKED,
             :authtoken => nil)
        check_response 422
      end
    end

    it "should create error_notify_sysadmin for lock rejects credential event from lock without authtoken" do
      assert_difference('Event.count', 1) do
         assert_difference('Notification.count', 0) do
           post(:create, @post13_data)
           check_response
         end
      end
    end

    it "should create error_notify_owner_admin for lock internal OTA failure event from lock without authtoken" do
      assert_difference('Event.count', 1) do
         assert_difference('Notification.count', 2) do
           post(:create, @post14_data)
           check_response
         end
      end
      log_notification(Notification.last)
    end

    it "should create error_notify_owner_admin for lock external OTA failure event from lock without authtoken" do
      assert_difference('Event.count', 1) do
         assert_difference('Notification.count', 2) do
           post(:create, @post15_data)
           check_response
         end
      end
      log_notification(Notification.last)
    end

     it "should create error_notify_owner_admin for undefined error message from lock without authtoken" do
      assert_difference('Event.count', 1) do
         assert_difference('Notification.count', 2) do
           post(:create, @post16_data)
           check_response
         end
      end
    end

    it "log all events" do

      get_image
      assert_difference('Event.count', 12) do
        # already called: post(:create, @post1_data)
        @post2_data[:picture] = {data: @encoded_file, content_type: 'image/jpeg', original_filename: 'test.jpeg'}

        post(:create, @post2_data)
        post(:create, @post3_data)
        post(:create, @post4_data)
        post(:create, @post5_data)
        post(:create, @post6_data)
        # 7, 8, 9 removed since they didn't apply to lock
        post(:create, @post10_data)
        post(:create, @post11_data)
        post(:create, @post12_data)
        post(:create, @post13_data)
        post(:create, @post14_data)
        post(:create, @post15_data)
        post(:create, @post16_data)
        check_response
      end

      send_auth(@user_device)
      get(:index)
      log_json(response, "Events GET")
    end

    it 'should save the event even if the picture data was not saved' do
      assert_difference('Event.count', 1) do
        assert_difference('Picture.count', 0) do
          post(:create,
               lock_serial: @lock.lock_serial,
             key_id: @key.id,
             event_time: @event_time,
             event_type: EventType::LOCK,
             string_value: CommandResult::SUCCESS,
             bolt_state: BoltState::LOCKED,
             picture: {content_type: 'image/jpeg', original_filename: 'test.jpeg'}
             )
        end
      end
    end

#XXX verify generated notifications in DB, including to owner, admins, key recipient (key_shared)
# event_test.rb does this, but not end-to-end.

#XXX complete tests of transferred file
=begin
    it "should have good external file from tom" do
      File.open("#{Rails.root}/test/data/tom.b64", 'r') do |f|
        @raw_file     = f.read.chop
        @decoded_file = Base64.decode64(@raw_file)
      end

      File.open("#{Rails.root}/tmp/picture.jpeg_raw", 'r') do |f|
        @raw_file2     = f.read
      end

      @raw_file.bytes.each_with_index do |char, i|
        if @raw_file2.bytes[i] != char
          print "#{i} #{char}  #{@raw_file2.bytes[i]}\n"
        end
        assert_equal @raw_file2.bytes[i], char
      end

      File.open("#{Rails.root}/test/data/tom.jpeg", 'wb') do |f|
        f.write(@decoded_file)
      end

    end
=end

  end

  # Have seen a time errors, so protect.
  def check_data_no_auth(ref)
    check_data(Event.last, ref, [:authtoken], true)
  end

  def check_data_and_auth(ref)
    check_data(Event.last, ref, nil, true)
  end
end
