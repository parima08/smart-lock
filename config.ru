# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../config/environment',  __FILE__)
# doesn't work, see application.rb:
# use Rack::ContentLength
run Rails.application
