require_relative 'development.rb'

GojiServer::Application.configure do
  # This config is for running a server locally for integration test.
  # Good debugging without undue performance impact.

  # Settings specified here will take precedence over those in
  # config/application.rb and development.rb included above.

  # Control release of code changes to the integration server, so you
  # can be developing unrelated changes while others are integrating
  # against your server (if set to true).
  config.cache_classes = true
  # Do not eager load code on boot.
  config.eager_load = true

  # Enable caching.
  config.action_controller.perform_caching = true

end
