# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)

GojiServer::Application.load_tasks

# Include the test/lib directory when running rake minitest
# Only in test environments...otherwise Heroku complains about MiniTest

# environments/*.rb not yet loaded here, ugh!
#  if GojiServer.config.minitest
# Matches Gemfile.
if Rails.env.development? || Rails.env.test? || Rails.env.integration?
  MiniTest::Rails::Testing.default_tasks << 'lib'
  MiniTest::Rails::Testing.default_tasks << 'features'
end
