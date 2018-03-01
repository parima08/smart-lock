source 'https://rubygems.org'

ruby "2.1.3"

gem 'rails', '4.2.7.1'

gem 'awesome_print'
gem 'hex_string'
gem 'aws-sdk'
gem 'bcrypt-ruby', '~> 3.0.0'
gem 'clockwork'
gem 'certified'
gem 'forgery'
gem 'foreman'
gem 'httparty'
gem 'devise'
gem 'devise-encryptable'
gem 'jquery-rails'
gem 'newrelic_rpm'
gem 'newrelic-aws'
gem 'nilify_blanks'
gem 'wannabe_bool'
gem 'pg'
gem 'schema_plus'
# rails_admin requires jquery-ui-rails (~> 4.0), active_admin
# (~> 5.0).  Not sure how to deploy both at once, unless there is a way to
# override the rails_admin bindings which aren't in our Gemfile*
#gem 'rails_admin', github: 'sferik/rails_admin', ref: '9a25098'
gem 'rails_admin', github: 'sferik/rails_admin', ref: 'df22db8'
#gem 'activeadmin', github: 'activeadmin'
gem 'ransack'
gem "rails-boilerplate"
gem "protected_attributes"
gem "paperclip", '3.5.4'
gem 'term-ansicolor'
gem 'unicorn'
# uuid gem isn't heroku friendly so:
gem 'uuidtools'
gem 'browser'
gem 'bootstrap-sass'

group :development, :test, :integration do
  # Not in staging/production, which are only for use with Heroku env now.
  gem 'dotenv-rails'
  gem 'byebug'
  # minitest also needs to be declared in development and integration for some reason.
  gem 'minitest-rails'
end
group :development, :integration do
  gem 'mailcatcher'
end

group :development do
  gem 'annotate'
  gem "flatten_migrations"
  gem 'interactive_editor'
  # looksee wouldn't recompile on ruby 2.1 upgrade.
  #gem 'looksee', '2.1.1'
  # these two gems (plus awesome_print above) allow nicer console access in development
  gem 'hirb'
  gem 'wirble'
  # thin is a nice alternative to webrick in develpment.
  # unicorn kills processes after 60 seconds so....
  gem 'thin'
  gem 'ripl'
  gem 'ripl-multi_line'
  gem 'ripl-irb'
end

group :production, :staging do
  gem 'rails_12factor'
end

group :test do
  gem 'factory_girl_rails'
  # for cucumber, this format is required to avoid warnings on rails 3.2.x
  gem 'database_cleaner'
  gem 'simplecov', :require => false
  gem 'simplecov-rcov', :require => false
  gem 'm', '~> 1.3.1'
  gem 'timeliness'
  gem 'ci_reporter'
  gem 'test_after_commit'
  gem 'capybara'
  gem 'minitest-rails-capybara'
  gem 'timecop'
end
