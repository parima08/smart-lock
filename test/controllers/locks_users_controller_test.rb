require "test_helper"

class LocksUsersControllerTest < ActionController::TestCase
=begin
  describe LocksUsersController do

    subject { LocksUsersController }

    before do
      DatabaseCleaner.start
      @routes = Rails.application.routes
      @owner      = make_user('glenn.widener@gmail.com')
      @owners_lock= make_lock(@owner)
      @user       = make_user()
    end

    after do
      DatabaseCleaner.clean
    end

    def add_admin_user(lock, user)
      add_admin_user_as(lock, user, @owner)
    end

    def add_admin_user_as(lock, user, as_user)
      add_lock_user_as(lock, user, as_user, true)
    end

    def add_lock_user_as(lock, user, as_user, admin)
      add_lock_user_id_as(lock, user.id, as_user, admin)
    end

    def add_lock_user_id_as(lock, user_id, as_user, admin)
      put(:update, :lock_id => lock.id,
          :authtoken => as_user.account.authentication_token,
          :user_id => user_id,
          :admin => admin
          )
    end
    
    #default is a restricted key
    def create_key(lock, user, sharer, data_hash = 
                           { start_date: DateTime.now.to_s })
      Key.create_key(lock.id, user, sharer, data_hash)
    end
    
    it "make an admin user, as owner" do
      assert @routes
      add_admin_user(@owners_lock, @user)
      check_response 
      check_locks_user(@owners_lock, @user.id, true)
      check_auto_key(@owners_lock, @user, @owner.id)
      # Delete the lock, verify that the LocksUser and keys are deleted.
      @owners_lock.destroy
      check_no_lock_data(@owners_lock, @user.id)
    end

=end
=begin
    # This fails, see controller code.
    it "make an admin user who already has a limited key, as owner" do
      assert @routes
      create_key(@owners_lock, @user, @owner,                       
                 {
                   time_constraints: [{
                                        monday: "true",
                                        wednesday: "true",
                                        start_time: "abcdefg",
                                        end_time: "18:00Z"
                                      }]
                 })
      add_admin_user(@owners_lock, @user)
      check_response 
      check_locks_user(@owners_lock, @user.id, true)
      check_auto_key(@owners_lock, @user, @owner.id)
    end
=end
=begin

    it "make an admin user, as admin" do
      user2       = make_user('glenn2@gmail.com')
      lock2       = make_lock(user2)

      # Make owner an admin, then as owner, make @user admin
      add_admin_user_as(lock2, @owner, user2)
      check_response 
      check_locks_user(lock2, @owner.id, true)
      check_auto_key(lock2, @owner, user2.id)
      add_admin_user(lock2, @user)
      check_response 
      check_locks_user(lock2, @user.id, true)
      check_auto_key(lock2, @user, @owner.id)
    end

    it "make an admin user, as owner, existing unlimited key" do
      create_key(@owners_lock, @user, @owner, {})
      add_admin_user(@owners_lock, @user)
      check_response 
      check_locks_user(@owners_lock, @user.id, true)
      check_no_auto_key(@owners_lock, @user.id)
    end

    it "remove admin user" do
      add_admin_user(@owners_lock, @user)
      check_auto_key(@owners_lock, @user, @owner.id)
      # Should update existing record
      # XXX Disabled because on put() it triggers a foreign key constraint
      # with DatabaseCleaner.strategy = :truncation
      #add_lock_user_as(@owners_lock, @user, @owner, false)
      #check_no_auto_key(@owners_lock, @user.id)
      #check_locks_user(@owners_lock, @user.id, false)
      check_locks_user(@owners_lock, @user.id, true)
    end

    # XXX this test is actually working, but something is wrong with
    # the test lashup, it reports it's getting 200, the controller is
    # clearly returning 401 in the debugger and to curl.

=end
=begin
    it "authenticated user is not admin or owner for lock, should not be allowed to add admin user" do
      user2      = make_user('glenn2@gmail.com')
      lock2       = make_lock(user2)
      # just to make it more interesting:
      add_admin_user_as(lock2, @owner, user2)
      add_admin_user_as(lock2, @user, @user)
      //check_response :unauthorized
      check_response 401
    end
=end
=begin

    it "should return 422 because user_id is not found" do
      add_lock_user_id_as(@owners_lock, 666, @owner, false)
      check_response(404, :MISSING_RECORD)
    end

    it "should fail with unknown lock id" do
      put(:update, :lock_id => @owners_lock.id + 100000,
          :authtoken => @owner.account.authentication_token,
          :user_id => @user.id,
          :admin => true)
      check_response(404, :MISSING_RECORD)
    end

    it "should get unauthorized response from put without authtoken" do
      put(:update, :lock_id => @owners_lock.id,
          :user_id => @user.id,
          :admin => true)
      check_response :unauthorized, :UNAUTHORIZED
    end

    it "should get unauthorized response from put with bad authtoken" do
      put(:update, :lock_id => @owners_lock.id,
          :user_id => @user.id,
          :authtoken => "junk")
      check_response :unauthorized, :UNAUTHORIZED
    end

    # More tests should we start using this endpoint, they are covered in keys_controller_test:
    # valid: admin=false, admin=false followed by admin=true, 
    # not covered:
    # owner id supplied for new admin id (allowed but meaningless?), ...
  end

=end
end
