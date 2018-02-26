GojiServer::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.cache_classes = true

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both thread web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Enable Rack::Cache to put a simple HTTP cache in front of your application
  # Add `rack-cache` to your Gemfile before enabling this.
  # For large-scale production use, consider using a caching reverse proxy like nginx, varnish or squid.
  # config.action_dispatch.rack_cache = true

  # Disable Rails's static asset server (Apache or nginx will already do this).
  config.serve_static_assets = false

  # Compress JavaScripts and CSS.

  # Do not fallback to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # Generate digests for assets URLs.
  config.assets.digest = true

  # Version of your assets, change this if you want to expire all your assets.
  config.assets.version = '1.0'

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # Set to :debug to see everything in the log.
  # This is a non-operative setting under Heroku (12factor gem overrides)!
  config.log_level = :info

  # Prepend all log lines with the following tags.
  # config.log_tags = [ :subdomain, :uuid ]
  # Per this suggested setup, logging UUID
  # https://devcenter.heroku.com/articles/http-request-id
  config.log_tags = [ :uuid ]

  # Use a different logger for distributed setups.
  # config.logger = ActiveSupport::TaggedLogging.new(SyslogLogger.new)

  # Additional filtered parameters for non-development only
  # See also initializers/filter_parameter_logging.rb
  config.filter_parameters += [:data]

  # Use a different cache store in production.
  # config.cache_store = :mem_cache_store

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.action_controller.asset_host = "http://assets.example.com"

  # Precompile additional assets.
  # application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
  # This appears to not work at all!
  # See theming.css.scss.
  config.assets.precompile += ['rails_admin/rails_admin.css',
                               'rails_admin/custom/theming.css.scss',
                               'rails_admin/rails_admin.js']

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found).
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners.
  config.active_support.deprecation = :notify

  # Disable automatic flushing of the log to improve performance.
  # config.autoflush_log = false

  # Use default logging formatter so that PID and timestamp are not suppressed.
  # Is this a non-operative setting under Heroku??
  config.log_formatter = ::Logger::Formatter.new

  # We don't deploy minitest in production
  # Can't configure this way!
  # config.minitest = false

  # We don't want firware uploaded through production, it must be tested first.
  config.allow_firmware_upload = true

  # Allow bypass of auth with "noauth" request parameter, plus a dummy
  # current_user_id.  If we all have test accounts, this isn't necessary.
  config.noauth = false

  # Valid time in seconds for picture/firmware urls, assuming they will get used right away.
  # Scrolling event lists could completely blow this limit if the app lazy renders,
  # and the user comes back later and scrolls some more!
  config.s3_url_expire = 60

  # Choose the admin UI: RailsAdmin or ActiveAdmin (prototype)
  # See development.rb.
  config.admin = "rails"

  # False avoids actually sending mail, but still sends mail for checking.
  # config.action_mailer.perform_deliveries = true
  config.action_mailer.delivery_method = :smtp
  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options = { host: ENV['MAILER_URL'], protocol: 'https' }
  # Asset host (could be S3 or similar eventually)
  config.action_mailer.asset_host = 'https://' + ENV['MAILER_URL']

  config.action_mailer.smtp_settings = {
    :address        => 'smtp.sendgrid.net',
    :port           => '587',
    :authentication => :plain,
    :user_name      => ENV['SENDGRID_USERNAME'],
    :password       => ENV['SENDGRID_PASSWORD'],
    :domain         => 'heroku.com'
  }

  config.paperclip_defaults = {
    :storage => :s3,
    :s3_permissions => :private,
    :s3_credentials => {
      :bucket => ENV['AWS_BUCKET'],
      :access_key_id => ENV['AWS_ACCESS_KEY_ID'],
      :secret_access_key => ENV['AWS_SECRET_ACCESS_KEY']
    }
  }

  # required for flatten migrations gem
  config.active_record.schema_format = :ruby

  # Should we use SSL where supported?
  # Custom configuration variable used other places in place of checking environments
  config.use_ssl_if_possible = true

  if config.use_ssl_if_possible
    # Require SSL for devise
    # We can't require SSL for everything, since the lock currently can't do SSL
    config.to_prepare { Devise::SessionsController.force_ssl }
    config.to_prepare { Devise::RegistrationsController.force_ssl }
    config.to_prepare { Devise::PasswordsController.force_ssl }
  end
end
