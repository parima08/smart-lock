require_relative 'development.rb'

GojiServer::Application.configure do
  # Settings specified here will take precedence over those in
  # config/application.rb and development.rb included above.

  # The test environment is used exclusively to run your application's
  # test suite. You never need to work with it otherwise. Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs. Don't rely on the data there!
  config.cache_classes = true

  # Do not eager load code on boot. This avoids loading your whole application
  # just for the purpose of running a single test. If you are using a tool that
  # preloads Rails for running tests, you may have to set it to true.
  config.eager_load = false

  # Configure static asset server for tests with Cache-Control for performance.
  config.serve_static_assets  = true
  config.static_cache_control = "public, max-age=3600"
  # Run fast:
  config.assets.debug = false

  # Raise exceptions instead of rendering exception templates.
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Valid time in seconds for picture/firmware urls, short to test.
  config.s3_url_expire = 10

  # Changed: taking development default: Raise an error on page load
  # if there are pending migrations
  # config.active_record.migration_error = :page_load

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test
  config.action_mailer.default_url_options = { :host => ENV['MAILER_URL'] }
  config.action_mailer.asset_host = 'http://' + ENV['MAILER_URL']

if ENV['SEND_TEST_EMAIL']
  # Turn on actual email for testing
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.smtp_settings = {
    :address        => 'smtp.sendgrid.net',
    :port           => '587',
    :authentication => :plain,
    :user_name      => ENV['SENDGRID_USERNAME'],
    :password       => ENV['SENDGRID_PASSWORD'],
    :domain         => 'room5.com'
  }
end

  config.paperclip_defaults[:s3_credentials][:bucket] = "goji-server-test"

end
