if ENV["RAILS_ENV"] == ""
   ENV["RAILS_ENV"] == "staging"
end

require "test/test_helper_core"

# This leverages the test framework to setup a fixed user+lock+key for integration test.
# Run it against the integration database:
#    cd ..
#    ruby -I . ./bin/rails runner test/create_integration_data.rb
# ignore error:
#    /home/vagrant/.gem/ruby/2.0.0/gems/minitest-4.7.5/lib/minitest/unit.rb:1037:in `block in process_args': invalid option: -e (OptionParser::InvalidOption)
# Must clear the db to redo: 
#   export RAILS_ENV=staging
#   rake db:drop
#   rake db:create
#   rake db:migrate
#   unset RAILS_ENV
 
class IntegrationSetup < ActiveSupport::TestCase
    def install
      @user        = make_user('glenn.widener@room5.com')
      @user2       = make_user('glenn.widener2@room5.com')
      @lock        = make_lock(@user)
      @key         = make_key(@lock, @user)
      puts "test user id = #{@user.id}"
      puts "test lock id = #{@lock.id}"
      puts "test key id = #{@key.id}"
# stop now or the test framework kills the records!  Have to find a better way.
byebug
      #puts "test user=" + @user.inspect
      #puts "test account=" + @user.account.inspect
      #puts "test lock=" + @lock.inspect
    end 
end

setup = IntegrationSetup.new 'dummy'
setup.install
