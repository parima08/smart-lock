require_relative 'production.rb'

# This configuration is for both full integration test and staging,

GojiServer::Application.configure do
  # Settings specified here will take precedence over those in
  # config/application.rb and production.rb included above.

  # Set to :debug to see everything in the log.
  # This is a non-operative setting under Heroku (12factor gem overrides)!
  config.log_level = :debug

  # We don't want firmware uploaded through production, it must be
  # tested first.
  # XXX And we don't want a server instance with upload capability to be publically accessable.
  config.allow_firmware_upload = true

  # Allow bypass of auth with "noauth" request parameter, plus a dummy
  # current_user_id.  If we all have test accounts, this isn't necessary.
  config.noauth = true
end
