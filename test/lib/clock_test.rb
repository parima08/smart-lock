require 'test_helper'
require 'clock'

class ClockTest <  MiniTest::Unit::TestCase

  describe Key do
    before do
      DatabaseCleaner.start
      @manager = Clockwork.manager
    end

    after do
      DatabaseCleaner.clean
    end

    it "should notify expired keys every minute" do
      @user, @device, @user_device = make_user
      @lock = make_lock(@user)
      @key = make_key(@lock, @user)
      @key.end_date = Time.now - 1.day
      @key.save!
      @key.reload
      start = Time.now
      assert_difference "Event.count", +1 do
        assert_difference "Notification.count", +1 do
          assert_equal 2, @manager.tick(start).size
        end
      end
      ev = Event.last
      assert_equal EventType::KEY_EXPIRED, ev.event_type
      assert_equal @user.id, ev.user_id
      assert_equal @key.id, ev.key_id 
      assert_equal @lock.id, ev.lock_id
      assert_equal_fuzzy_datetime(start, ev.event_time, 2)
      assert_equal 0, @manager.tick(start+30).size
      assert_equal 0, @manager.tick(start+59).size
      assert_equal 1, @manager.tick(start+60).size
      assert_equal 0, @manager.tick(start+61).size
      assert_equal 1, @manager.tick(start+(60*2)).size
    end
  end 

  describe Lock do 
    before do
      DatabaseCleaner.start
      @manager = Clockwork.manager
    end

    after do
      DatabaseCleaner.clean
    end

    it "should communicate Lock's wifi status every 10 minutes" do
      @user, @device, @user_device = make_user
      @lock = make_lock(@user)
      @key = make_key(@lock, @user)
      sleep 2
      Lock.test_mode = true
      start = Time.now
      assert_equal 2, @manager.tick(start + GojiServer.config.status_sync_time).size
      assert_equal 2, Event.all.count
      ev = Event.last
      assert_equal "wifi", EventType::LOCK_COM
      assert_equal "down", ev.string_value
      assert_equal "up", @lock.reported_wifi_status
      @lock.reload
      assert_not_nil @lock.reported_wifi_time
      assert_equal "down", @lock.reported_wifi_status
      assert_equal 0, @manager.tick(start + GojiServer.config.status_sync_time + 30).size
      assert_equal 1, @manager.tick(start + GojiServer.config.status_sync_time + 60).size
      assert_equal 2, @manager.tick(start + (GojiServer.config.status_sync_time * 2)).size
    end
  end

end


