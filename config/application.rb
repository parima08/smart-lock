require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env)

# Require stuff that I can't seem to get to autoload
require './lib/error_recorder.rb'

module GojiServer
  # shorthand:
  def self.config
    Application.config
  end

  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # schema.rb doesn't support views.  minitest doesn't support
    # structure.sql.  So schema_plus is required.
    #config.active_record.schema_format = :sql

    config.middleware.use Rack::ContentLength unless ENV['RACK_CONTENTLENGTH'] && ENV['RACK_CONTENTLENGTH'] == 'false'

    config.aws_push_arn = {
      ios:            ENV["PUSH_ARN_IOS"],
      iosdevelopment: ENV["PUSH_ARN_IOSDEVELOPMENT"],
      android:        ENV["PUSH_ARN_ANDROID"],
    }

    config.status_sync_time = 1.hour
   end
end
