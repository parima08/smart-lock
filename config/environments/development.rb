GojiServer::Application.configure do
  # This config is for manual debugging.
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false
  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations
  config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true
  config.log_tags = [ :uuid ]

  # We don't deploy minitest in production
  # Can't configure this way!
  # config.minitest = true

  # We don't want firmware uploaded through production, it must be
  # tested first.
  config.allow_firmware_upload = true

  # Valid time in seconds for picture/firmware urls.
  config.s3_url_expire = 60

  # Choose the admin UI: RailsAdmin or ActiveAdmin (prototype)
  # Must also:
  # - Rerun bundle install after swapping Gemfile *_admin lines.
  # - If switching to ActiveAdmin, unzip active_admin.zip, and run lib/tasks/create_active_admin_models.sh.
  # Some stuff (like admin role) not yet implemented for ActiveAdmin.
  # We would need to change account.admin to searching admin_users table.
  config.admin = "rails" # "active"

  # Allow bypass of auth with "noauth" request parameter, plus a dummy
  # current_user_id.  If we all have test accounts, this isn't necessary.
  config.noauth = true

  # Run mailcatcher on command line and visit http://localhost:1080/ to check mail
  # False avoids actually sending mail, but still sends mail for checking.
  # config.action_mailer.perform_deliveries = true
  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = { :address => "localhost", :port => 1025 }
  config.action_mailer.default_url_options = { :host => 'localhost:3000' }
  config.action_mailer.asset_host = 'http://localhost:3000'

  if ENV['SEND_TEST_EMAIL']
    config.action_mailer.default_url_options = { host: ENV['MAILER_URL'], protocol: 'http' }
    config.action_mailer.asset_host = 'https://' + ENV['MAILER_URL']

    config.action_mailer.smtp_settings = {
      :address        => 'smtp.sendgrid.net',
      :port           => '587',
      :authentication => :plain,
      :user_name      => ENV['SENDGRID_USERNAME'],
      :password       => ENV['SENDGRID_PASSWORD'],
      :domain         => 'heroku.com'
    }
  end

  config.paperclip_defaults = {
    :storage => :s3,
    :s3_permissions => :private,
    :s3_credentials => {
      :bucket => "goji-server-development",
      :access_key_id => ENV['AWS_ACCESS_KEY_ID'],
      :secret_access_key => ENV['AWS_SECRET_ACCESS_KEY']
    }
  }
  # required for flatten migrations gem
  config.active_record.schema_format = :ruby

  # Should we use SSL where supported?
  # Custom configuration variable used other places in place of checking environments
  config.use_ssl_if_possible = false

end
