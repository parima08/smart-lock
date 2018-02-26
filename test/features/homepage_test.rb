require "test_helper"
#Warden.test_mode!

class  HomepageTest < Capybara::Rails::TestCase
  before do
    DatabaseCleaner.start
    # RailsAdmin.config do |c|
    #   c.authenticate_with { warden.authenticate! scope: :account }
    # end
    @account = make_account(email: 'person@example.com', password: 'aba456', admin: true)
    @entropy_settings = RailsAdmin.config.registry["app_globals"][:password][:entropy]
    @good_score = (@entropy_settings[:good].to_f*100)/@entropy_settings[:max]
  end

  after do
    DatabaseCleaner.clean
   # Warden.test_reset!
  end

  test "we cannot access the home page if we are not signed in" do
    #the engine we're using with capaybara can't execute javascript, so
    #we're setting the entropy manually and seeing how it executes. 
    # +1 due to rounding error somewhere...
    @account.password_entropy_percent = @good_score+1;
    @account.save
    login
    assert_content page, "Site Administration"
    find_link("Log out").click
    assert_content page, "Sign in"   
  end

  
  test "if the score is less than \"strong\" redirect to edit account" do
    @account.password_entropy_percent = @good_score -1;
    @account.save
    login
    assert_content page, "Edit Sysadmin users"
  end
  test "if the score is nil redirect to edit account" do
    @account.password_entropy_percent = nil
    @account.save
    login
    assert_content page, "Edit Sysadmin users"
  end

  #this test would be best refractored if I could get 
  #the rails_admin routes to work
  test "each path in rails_admin has the correct list view" do
    @account.password_entropy_percent = @good_score;
    @account.save
    login
    visit rails_admin_path
    models = RailsAdmin.config.models.map { |m| m.label } - ["User account"]
    links = find(".sidebar-nav").all("a")
    links.each do |l|
      l.click
      assert_content page, l.text
      # TODO: Doesn't take into account non-visible rails_admin
      # fields. Figure out how to test for only visible fields.
      # m_name = l.first(:xpath,".//..")["data-model"]
      # if m_name 
      #   list_view_fields = RailsAdmin.config.models.select{ |m| m.label == m_name.capitalize.gsub(/[_]/, ' ')}.first.list.fields.map{ |m| m.label }
      #   byebug
      #   list_view_fields.each do |field|
      #       assert_content page, field
      #   end
      # end
      visit rails_admin_path
    end
  end

  def login
    visit root_path
    assert_content page, "Sign in"
    fill_in "account_email", with: @account.email
    fill_in "account_password", with: @account.password
    find_button('Sign in').click
  end
end
