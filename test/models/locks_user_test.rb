require "test_helper"

class LocksUserTest < MiniTest::Unit::TestCase 

  describe LocksUser do 

    before do
      DatabaseCleaner.start
      @owner, @own_device, @own_user_device  = make_user('glenn.widener@gmail.com')
      @lock       = make_lock(@owner)
      @user, @device,@user_device  = make_user()
      @locks_user_data = make_admin_user(@lock, @user)
      @locks_user = LocksUser.last
    end

    after do 
      DatabaseCleaner.clean
    end

    subject { @locks_user }

    it "should update user_account_id on save" do
      assert_equal @locks_user.user_account_id,  @locks_user.user_id
      user2, dev, user_dev   = make_user
      @locks_user.user_id =  user2.id
      @locks_user.save
      assert_equal @locks_user.user_account_id,  @locks_user.user_id
    end

    it "XXX test tbd" do
    end

  end
end
