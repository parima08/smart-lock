require "test_helper"

class LockManagementPage < Capybara::Rails::TestCase
  before do
    DatabaseCleaner.start
    @account = make_account(email: 'person@example.com', password: 'aba456', admin: true)
    @user, @device, @user_device = make_user
    @lock = make_lock(@user)
    login
  end

  after do
    DatabaseCleaner.clean
  end

  #Tests for lock health pages
  test "shows correct icon/color for wifi up" do
    Lock.send_wifi_events([@lock], LockCommState::LOCK_COMM_UP)
    visit RailsAdmin.config.navigation_static_links['Lock Management']
    check_icon(page, "reported_wifi_status_field", "green", ".fa.fa-arrow-up")
  end

  test "shows correct icon/color for wifi down" do
    Lock.send_wifi_events([@lock], LockCommState::LOCK_COMM_DOWN)
    visit RailsAdmin.config.navigation_static_links['Lock Management']
    check_icon(page, "reported_wifi_status_field", "red", ".fa.fa-arrow-down")
  end

  test "show green if the sync time is now" do
    @lock.last_sync = Timecop.freeze(DateTime.now)
    @lock.save
    Timecop.return
    visit RailsAdmin.config.navigation_static_links['Lock Management']
    assert page.has_css?(".last_sync_time_field span.green"), "Does not have correct green color"
  end

  test "show green if the sync time is within 1 hour" do
    @lock.last_sync = Timecop.freeze(Time.now - GojiServer.config.status_sync_time + 1.minute)
    @lock.save
    Timecop.return
    visit RailsAdmin.config.navigation_static_links['Lock Management']
    assert page.has_css?(".last_sync_time_field span.green"), "Does not have correct green color"
  end

  test "show orange if the sync time is within 1-2 hours" do
    @lock.last_sync = Timecop.freeze(Time.now - (GojiServer.config.status_sync_time * 2) + 1.minute)
#    @lock.last_sync = Timecop.freeze(Time.now - GojiServer.config.status_sync_time - 1.minute)
    @lock.save
    Timecop.return
    visit RailsAdmin.config.navigation_static_links['Lock Management']
    assert page.has_css?(".last_sync_time_field span.orange"), "Does not have correct orange color"
  end

  test "shows red if the sync time is greater than 2 hours" do
    @lock.last_sync = Timecop.freeze(Time.now - (GojiServer.config.status_sync_time * 2) - 1.minute)
    @lock.save
    Timecop.return
    visit RailsAdmin.config.navigation_static_links['Lock Management']
    assert page.has_css?(".last_sync_time_field span.red"), "Does not have correct red color"
  end

  test "shows red if no sync time" do
    visit RailsAdmin.config.navigation_static_links['Lock Management']
    assert page.has_css?(".last_sync_time_field span.red"), "Does not have correct red color"
  end

  test "calculates correct percentage of wifi downtime" do
    visit RailsAdmin.config.navigation_static_links['Lock Management']
    Lock.send_wifi_events([@lock], LockCommState::LOCK_COMM_DOWN)
    Timecop.freeze(Time.now + 3600)
    Lock.send_wifi_events([@lock], LockCommState::LOCK_COMM_UP)
    Timecop.freeze(Time.now + 3600)
    Lock.send_wifi_events([@lock], LockCommState::LOCK_COMM_DOWN)
    Timecop.freeze(Time.now + 3600)
    Lock.send_wifi_events([@lock], LockCommState::LOCK_COMM_UP)
    Timecop.freeze(Time.now + 3600)
    Lock.send_wifi_events([@lock], LockCommState::LOCK_COMM_UP)
    Timecop.freeze(Time.now + 3600)
    Lock.send_wifi_events([@lock], LockCommState::LOCK_COMM_DOWN)
    Timecop.freeze(Time.now + 3600)
    Lock.send_wifi_events([@lock], LockCommState::LOCK_COMM_DOWN)
    Timecop.freeze(Time.now + 1000)
    Lock.send_wifi_events([@lock], LockCommState::LOCK_COMM_UP)

    check_wifi_downtime(3600 + 3600 + 3600 + 1000, (3600 * 6) + 1000)
  end

  test "calculates correct percentage of wifi downtime when currently down" do
    visit RailsAdmin.config.navigation_static_links['Lock Management']
    first = 3600
    second = 3000
    Timecop.freeze(Time.now + first)
    Lock.send_wifi_events([@lock], LockCommState::LOCK_COMM_DOWN)
    Timecop.freeze(Time.now + second)
    check_wifi_downtime(second, first + second)
  end

  def check_wifi_downtime(down_time, total_time)
    # Rounding to .1 can fail because code is based on event create time.
    percentage_should_be = (down_time.to_f/total_time * 100)
    percentage_should_be_up = percentage_should_be.ceil_frac(1).to_s + "%"
    percentage_should_be_down = percentage_should_be.floor_frac(1).to_s + "%"
    percentage_is = @lock.wifi_downtime(@lock)
    assert (percentage_is == percentage_should_be_down) ||
      (percentage_is == percentage_should_be_up),  "database downtime mismatch: " + percentage_is.to_s + " !=" + percentage_should_be.to_s
    #must login again because the time is passed the timed out time... 
    login
    visit RailsAdmin.config.navigation_static_links['Lock Management']
    Timecop.return
    on_page = all('.wifi_downtime_field').last.text
    assert (on_page == percentage_should_be_down) ||
      (on_page == percentage_should_be_up),  "shown downtime mismatch: " + on_page.to_s + " !=" + percentage_should_be.to_s
  end

  test "calculates correct error count" do
    Event.create!(lock_id: @lock.id, event_type: EventType::BATTERY, string_value: BatteryState::LOW, event_time: Time.now)
    Event.create!(lock_id: @lock.id, event_type: EventType::BATTERY, string_value: BatteryState::LOW, event_time: Time.now)
    Event.create!(lock_id: @lock.id, event_type: EventType::BATTERY, string_value: BatteryState::OK, event_time: Time.now)
    Event.create!(lock_id: @lock.id, event_type: EventType::LOCK_COM, string_value: LockCommState::LOCK_COMM_DOWN, event_time: Time.now)
    Event.create!(lock_id: @lock.id, event_type: EventType::LOCK_COM, string_value: LockCommState::LOCK_COMM_DOWN, event_time: Time.now)
    Event.create!(lock_id: @lock.id, event_type: EventType::LOCK_COM, string_value: LockCommState::LOCK_COMM_UP, event_time: Time.now)
    Event.create!(lock_id: @lock.id, event_type: EventType::LOCK_COM, string_value: LockCommState::LOCK_COMM_DOWN, event_time: Time.now)
    Event.create!(lock_id: @lock.id, event_type: EventType::LOCK, bolt_state: BoltState::UNLOCKED, string_value: CommandResult::HARDWARE_FAILURE, event_time: Time.now)
    Event.create!(lock_id: @lock.id, event_type: EventType::UNLOCK, bolt_state: BoltState::LOCKED, string_value: CommandResult::HARDWARE_FAILURE ,event_time: Time.now)
    Event.create!(lock_id: @lock.id, event_type: EventType::UNLOCK, bolt_state: BoltState::FAILED, string_value: CommandResult::EXPIRED ,event_time: Time.now)

    error_count = 8
    assert_equal @lock.error_count("list"), 8
    visit RailsAdmin.config.navigation_static_links['Lock Management']
    on_page = all('.error_count_field').last.text
    assert_equal error_count.to_s, on_page
  end

  test "shows correct icon/color for bolt locked" do
    @lock.bolt_state = BoltState::LOCKED
    @lock.save
    visit RailsAdmin.config.navigation_static_links['Lock Management']
    check_icon(page, "bolt_state_field", "green", ".fa.fa-lock")
  end

  test "shows correct icon/color for bolt unlocked" do
    @lock.bolt_state = BoltState::UNLOCKED
    @lock.save
    visit RailsAdmin.config.navigation_static_links['Lock Management']
    check_icon(page, "bolt_state_field", "green", ".fa.fa-unlock")
  end

  test "shows correct icon/color for bolt state failed" do
    @user, device, user_device = make_user
    @lock = make_lock(@user)
    @lock.bolt_state = BoltState::FAILED
    @lock.save
    visit RailsAdmin.config.navigation_static_links['Lock Management']
    check_icon(page, "bolt_state_field", "red", ".fa.fa-close")
  end

  test "check correct formatting of software version" do
    @external_firmware = Firmware.new(
      "version"=>"newer_internal",
      "description"=>"testOTA",
      "for_external"=>false,
      "download_url"=>"external/v2/0.0.9T",
      "data_file_name"=>"0.0_1_.9T",
      "data_content_type"=>"application/octet-stream",
      "data_file_size"=>125315,
      "data_updated_at"=>"2014-09-23T23:59:39.799Z")

    @internal_firmware = Firmware.new(
      "version"=>"newer_external",
      "description"=>"testOTA",
      "for_external"=>true,
      "download_url"=>"external/v2/0.0.9T",
      "data_file_name"=>"0.0_1_.9T",
      "data_content_type"=>"application/octet-stream",
      "data_file_size"=>125315,
      "data_updated_at"=>"2014-09-23T23:59:39.799Z")

    @external_firmware.save
    @internal_firmware.save
    @fv = FirmwareVersions.create(:default_required_internal_version => "newer_internal",
                           :default_required_external_version => "newer_external")
    @fv.save
    @lock.required_internal_version = "newer_internal"
    @lock.required_external_version = "newer_external"
    @lock.internal_version = ActiveSupport::TestCase.INTERNAL_VERSION
    @lock.external_version = ActiveSupport::TestCase.EXTERNAL_VERSION
    @lock.save
    visit RailsAdmin.config.navigation_static_links['Lock Management']
    assert page.has_css?(".internal_version_field span.red"), "Wrong Color, not red"
    find_link("...").click
    assert page.has_css?(".external_version_field span.red"), "Wrong Color, not"
    @lock.required_internal_version = ActiveSupport::TestCase.INTERNAL_VERSION
    @lock.save
    visit RailsAdmin.config.navigation_static_links['Lock Management']
    assert page.has_css?(".internal_version_field span.green"), "Wrong Color, not green"
    @lock.required_internal_version = nil
    @lock.save
    visit RailsAdmin.config.navigation_static_links['Lock Management']
    assert page.has_css?(".internal_version_field span.orange"), "Wrong Color, not orange"
    @lock.commission_date = nil
    @lock.save
    # uncomissioned lock not shown in static link
    visit '/admin/lock_management'
    assert page.has_css?(".internal_version_field span.gray"), "Wrong Color, not gray"
  end

  test "shows correct icon/color for unknown battery" do
    visit RailsAdmin.config.navigation_static_links['Lock Management']
    check_icon(page, "battery_state_field", "gray", ".fa.fa-question")
  end

  test "shows correct icon/color for ok battery" do
    @lock.battery_state = BatteryState::OK
    @lock.save
    visit RailsAdmin.config.navigation_static_links['Lock Management']
    check_icon(page, "battery_state_field", "green", ".fa.fa-arrow-up")
  end

  test "shows correct icon/color for low battery" do
    @lock.battery_state = BatteryState::LOW
    @lock.save
    visit RailsAdmin.config.navigation_static_links['Lock Management']
    check_icon(page, "battery_state_field", "red", ".fa.fa-arrow-down")
  end

  def check_icon(page, column, color, icon)
    assert page.has_css?(".#{column} span.#{color}"), "Wrong Color, not " + color
    assert page.has_css?(".#{column} span.#{color} #{icon}"), "Wrong Icon"
  end

  def login
    visit root_path
    assert_content page, "Sign in"
    fill_in "account_email", with: @account.email
    fill_in "account_password", with: @account.password
    find_button('Sign in').click
  end
end
