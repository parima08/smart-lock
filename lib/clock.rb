require File.expand_path('../../config/boot',        __FILE__)
require File.expand_path('../../config/environment', __FILE__)
require 'clockwork'

module Clockwork
  error_handler do |error|
    ErrorRecorder.notice_exception("Clock Process Error", error)

    if error.class == ActiveRecord::StatementInvalid && error.message.include?("PG::ConnectionBad")
      # Our PG connection has died, and easiest way to recover seems to be
      # to exit. Heroku will reboot us, which should reconnect.
      abort "Error: Clockwork DB Connection failed, PG::ConnectionBad detected, terminating process"
    end
  end
end


Clockwork.every(1.minute, 'Expired Key Notifications') do
  Key.notify_expired_keys
end
# Can be <= max wifi sync interval, larger values help performance
# (same as sync doubles max time to discover wifi state change)
# If it's longer, short down intervals can be missed.
Clockwork.every(GojiServer.config.status_sync_time, 'Lock Communication Check') do
  Lock.check_active
end
