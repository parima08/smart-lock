# I have split off TestCase so that it can be used to generate db records for
# integration testing, see ./create_integration_data.rb .
#

ENV["RAILS_ENV"] = "test"
require File.expand_path('../../config/environment', __FILE__)

# load before all else 
require 'simplecov'
require 'simplecov-rcov'
require 'byebug'

SimpleCov.use_merging true
SimpleCov.command_name("minitest:#{Time.now.to_i}") # This to fix Minitest merging
SimpleCov.formatters = [
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::RcovFormatter,
]
SimpleCov.start 'rails' unless ENV['NO_COVERAGE']

require "rails/test_help"
require "minitest/rails"
require 'minitest/spec'
require 'minitest/autorun'
require "minitest/rails/capybara"

# Uncomment if you want awesome colorful output
require "minitest/pride"

# ensures test database is kept in pristine state
require "database_cleaner"
# Transaction is usually faster, but prevents testing foreign_key
# constraints.  Truncation fails spectacularly without adding a
# transaction around the truncation in the DC code
# (and even still has one problem with foreign key constraints,
# so this test is disabled in locks_users_controller_test.rb.)
DatabaseCleaner.strategy = :truncation
DatabaseCleaner.strategy = :transaction

require "test_helper_core"

class ActionController::TestCase
  # Add more helper methods to be used by ActiveSupport tests here...
  # even if you're not sign_in with devise, you need it for account model
  include Devise::TestHelpers
  include Rails.application.routes.url_helpers
  include RailsAdmin::Engine.routes.url_helpers
  include ActiveSupport::Testing::SetupAndTeardown
  include ActionController::TestCase::Behavior
  include FactoryGirl::Syntax::Methods
  #include Warden::Test::Helpers
end
