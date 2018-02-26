require "test_helper"

class AccountTest < MiniTest::Unit::TestCase

  describe Account do

    before do
      DatabaseCleaner.start
      @user, @device, @user_device = make_user
      @account     = @user.account
      @lock        = make_lock(@user)
      @key         = make_key(@lock, @user)
    end

    after do
      DatabaseCleaner.clean
    end

    subject { @account }

    it "should have a update_full_name callback" do
      assert @account.respond_to?(:update_full_name)
    end

    it "should update full name on save" do
      assert @account.full_name != "Chan Marshall"
      @account.first_name = "Chan"
      @account.last_name  = "Marshall"
      @account.password   = "aba123"
      @account.password_confirmation = "aba123"
      @account.save!
      assert @account.full_name == "Chan Marshall"
    end

    it "should have a has_no_password? method for devise" do
      assert_equal @account.encrypted_password.blank?, @account.has_no_password?
    end

    it "should have a only_if_unconfirmed method for devise" do
      assert @account.respond_to? :only_if_unconfirmed
      @account.only_if_unconfirmed
      assert @account.errors[:email]
      assert_equal @account.errors[:email].first, "was already confirmed, please try signing in"
    end

    it "should have an attempt_set_password method for devise" do
      @account.confirmed_at = nil
      # Devise doesn't support clearing password, at least not directly.
      @account.encrypted_password = nil
      @account.save!
      assert_true @account.has_no_password?, "password not present"
      assert @account.attempt_set_password({:password => "foobar",
                                             :password_confirmation => "foobar"})
      @account.reload
      assert_false @account.has_no_password?, "password present"
    end

    it "attempt_set_password should fail on mismatch" do
      @account.confirmed_at = nil
      @account.encrypted_password = nil
      @account.save!
      assert_true @account.has_no_password?, "password not present"
      assert_false @account.attempt_set_password({:password => "foobar",
                                                  :password_confirmation => "foo"}), "should reject mismatched password and password_confirmation in model"
      @account.reload
      assert_true @account.has_no_password?, "password not present"
    end

    it "attempt_set_password should fail on password_confirmation missing" do
      @account.confirmed_at = nil
      @account.encrypted_password = nil
      @account.save!
      assert_true @account.has_no_password?, "password not present"
      assert_false @account.attempt_set_password({:password => "foobar"}), "should reject password without password_confirmation in model"
      @account.reload
      assert_true @account.has_no_password?, "password not present"
    end

    it "confirm_and_save! should be atomic" do
      @account.confirmed_at = nil
      @account.save!
      @account.encrypted_password = nil

      begin
        @account.confirm_and_save!
      rescue
        @errored = true
      end
      @account.reload

      assert @errored
      assert !@account.confirmed?, 'should still be unconfirmed'
    end

    it "should only allow valid email formats" do
      @account_new = Account.new(email: "abc123", 
                                 password_confirmation: "passwordabc1235",
                                 password: 'passwordabc1235')
      assert_no_difference "Account.count" do
        @account_new.save
        assert @account_new.errors.messages.keys.include?(:email), 'should error on email'
      end
    end

    it "should allow 255 chars in email" do
      @account_new = Account.new(email: "thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_@gmailaddrs.com", 
                                 password_confirmation: "passwordabc1235",
                                 password: 'passwordabc1235')
      assert_difference "Account.count", 1 do
        @account_new.save
      end
    end

=begin
    # XXX Just errors, need validation instead.
    # Needs checking in user_controller, testing in user_controller_test.
    it "should not allow more than 255 chars in email" do
      @account_new = Account.new(email: "thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_@gmailaddres.com", 
                     password_confirmation: "passwordabc1235",
                     password: 'passwordabc1235')
      assert_no_difference "Account.count" do
        assert @account_new.valid? == false, "reported invalid"
        assert @account_new.errors.messages.keys.include?(:email), 'maximum email character limit exceeded reported'
        assert @account_new.errors.messages[:email] == 'maximum is 255 characters', "correct error message"
        @account_new.save
      end
    end
=end

    it "should have a working first_by_email method" do
      found = Account.first_by_email(@account.email)
      assert_equal @account, found
    end

    it "should ignore case in first_by_email" do
      found = Account.first_by_email(@account.email.upcase)
      assert_equal @account, found
    end

    it "should nilify name fields when blank" do
      @account_unconfirmed = make_unconfirmed_account('notconfirmed3@example.com')
      @account_unconfirmed.first_name = ""
      @account_unconfirmed.last_name = ""
      assert @account_unconfirmed.save, "should be able to save"
      assert_equal nil, @account_unconfirmed.first_name
      assert_equal nil, @account_unconfirmed.first_name
      assert_equal nil, @account_unconfirmed.full_name
    end

  end
end
