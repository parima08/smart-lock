require "test_helper"

class UserTest < MiniTest::Unit::TestCase

  describe User do

    before do
      DatabaseCleaner.start
      @user, @device, @user_device  = make_user # John Doe is the name

      @lock = make_lock(@user) # Our lock
      @user2, @device2, @user_device2 = make_user('other_owner@example.com')
      @lock2 = make_lock(@user2)
      make_admin_user(@lock2, @user) # Our admined lock

      @user3,@device3, @user_device3 = make_user('another_unrelated@example.com')
      @lock3 = make_lock(@user3) # To make sure we're not sending all the locks
      make_guest_key(@lock3, @user.account.email, @user3) # A lock we're a guest on
    end

    after do
      DatabaseCleaner.clean
    end

    subject { @user }

    it "display_name should return account first_name and last_name" do
      assert_equal "John Doe", @user.display_name
    end

    it "display_name should return email if no account name is present" do
      new_account = Account.create!(email: 'johnnydoe@example.com', user: User.new, password: 'abc123', password_confirmation: 'abc123')
      assert_equal new_account.email, new_account.user.display_name
    end

    it "create should fail on password/confirmation mismatch" do
      assert_raises ActiveRecord::RecordInvalid do
        new_account = Account.create!(email: 'johnnydoe@example.com', user: User.new, password: 'abc123', password_confirmation: 'abc')
      end
    end

    it "should correctly return managed_locks" do
      locks = @user.managed_locks
      assert_equal 2, locks.count
      assert locks.include?(@lock), 'should include our owned lock'
      assert locks.include?(@lock2), 'should include our admined lock'
    end

    it "should correctly return owned locks" do
      locks = @user.locks
      assert_equal 1, locks.count
      assert_equal @lock, locks.first, 'should include our owned lock'
    end

    it "should correctly return admined locks" do
      locks = @user.admined_locks
      assert_equal 1, locks.count
      assert_equal @lock2, locks.first, 'should include our admined lock'
    end

    it "should nilify " do
      @user.time_zone = ""
      assert @user.valid?
      assert_equal nil, @user.time_zone
    end

    it "should have user_account view with all attributes" do
      ua = UserAccount.find_by_user_id(@user.id)
      assert_equal @user.account.id, ua.id
    end

  end
end
