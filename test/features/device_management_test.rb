require "test_helper"

class LockManagementPage < Capybara::Rails::TestCase
  before do
    DatabaseCleaner.start
    @account = make_account(email: 'person@example.com', password: 'aba456', admin: true)
    # @lock = make_lock(@user)
    login
  end

  after do
    DatabaseCleaner.clean
  end

  #Tests for lock health pages
  test "accurately formats the list of user_devices for a device" do
    set_up_user_devices
    visit RailsAdmin.config.navigation_static_links['Device Management']
    assert page.has_css?(".dm_user_devices")
    assert page.has_css?(".dm_user_devices a", :count => @device.user_devices.count)
    assert page.has_css?(".dm_user_devices a.green", :count => 1)
    green_element =  page.find(".dm_user_devices a.green")
    assert_equal green_element.text, @ud1.display_name
    href = RailsAdmin::Engine.routes.url_helpers.show_path(model_name: 'user_device', id: @ud1.id)
    assert_equal green_element['href'], href
    node = find(".dm_user_devices").native
    assert page.has_css?(".dm_user_devices a.red", :count => 2)
    assert page.has_css?(".dm_user_devices a.orange", :count => 1)
  end

  test "accurately formats the show of user_devices for a device" do
    set_up_user_devices
    visit RailsAdmin.config.navigation_static_links['Device Management']
    show_page = RailsAdmin::Engine.routes.url_helpers.show_path(model_name: 'device', id: @device.id)
    all("td.last.links a").first.click
    assert_content page, "Details for Manage Device '#{@device.display_name}'"
    assert page.has_css?(".dm_show_user_devices .active a", :count => 1)
    assert page.has_css?(".dm_show_user_devices .decommissioned a", :count => 1)
    assert page.has_css?(".dm_show_user_devices .not_in_use a", :count => 2)
  end

  def set_up_user_devices
    user1, @device, @ud1 = make_user
    user2 = make_user.first
    user3 = make_user.first
    user4 = make_user.first
    @ud2 = make_user_device(user2, @device)
    @ud3 = make_user_device(user3, @device)
    @ud4 = make_user_device(user4, @device)
    @ud1.update!(decommissioned_at: nil, 
                authenticated_at: Time.now, 
                confirmed_at: Time.now,
                keys_sent_at: Time.now)
    @ud2.update(confirmed_at: DateTime.now)
    @ud3.update(confirmed_at: DateTime.now - 1.hour, 
                keys_sent_at: DateTime.now - 1.hour,
                decommissioned_at: DateTime.now)
    #this wouldn't happen in reality, as the keys would
    #be sent if the user was confirmed? 
    @ud4.update(keys_sent_at: DateTime.now)

  end

  def login
    visit root_path
    assert_content page, "Sign in"
    fill_in "account_email", with: @account.email
    fill_in "account_password", with: @account.password
    find_button('Sign in').click
  end
end
