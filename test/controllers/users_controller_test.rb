require "test_helper"

class UsersControllerTest < ActionController::TestCase

  describe UsersController do

    subject { UsersController }

    before do
      DatabaseCleaner.start
      @account = make_account
      @user, device, @user_device1 = make_user_from_account(@account)
      @device, @user_device = make_confirmed_device(@user)
      @lock = make_lock(@user)
      @key  = make_key(@lock, @user)
      send_auth(@user_device)
      get(:show, :id => @account.email)
      header_auth
      @json = JSON.parse(response.body)
      @account_unconfirmed = make_unconfirmed_account('notconfirmed3@example.com')
      @user_unconfirmed, @device_uncon, @user_device_uncon = make_user_from_account(@account_unconfirmed)
      @new_pass = "new_password"
      @old_pass = 'bluedoor'
      @non_device_fields = [ :id, :confirmation_token, 
                             :password, :first_name, :last_name, ]
      @confirmation_params = {
        id: @account_unconfirmed.email,
        old_password: @old_pass,
        password: "superpass123!",
        first_name: "New",
        last_name: "User",
        device_type:  "iOS",
        device_model: "newdm",
        os_version:   "newov",
        app_version:  "newav",
      }

    end

    after do
      DatabaseCleaner.clean
    end

    it "must respond" do
      assert @routes
      check_response 
    end

    it "should get a user" do
      assert assigns(:user) # valid object
    end

    it "should return valid json" do
      assert @json 
      log_json(response, "Users GET")
      # XXX check_data based on make_account list
      check_payload(@json["account"], @account, 
                    [:password,  # exclude, per users_controller list
                     :password_confirmation,
                     :admin,
                     :confirmation_token,
                     :encrypted_password,  # Be sure non-attr_accessible fields are not
                     :authentication_token,
                     :reset_password_token], 
                    nil, # allow:  default db fields
                    [])  # no server_time
      check_payload(@json, @user, [:account_id])
    end

    it "should get at 404 status code when not authenticated and account doesn't exist" do
      header_auth
      get(:show, id: "nosuchaccount@example.com")
      check_response :not_found
    end

    it "should return a 401 status code when not authenticated and confirmed account does exist" do
      header_auth
      get(:show, id: @account.email)
      check_response :unauthorized
    end

    it "should not return a different account when authenticated" do
      @account2 = make_account(email: 'anotheruser2@example.com')
      @user2, device, user_device = make_user_from_account(@account2)
      send_auth(@user_device)
      get(:show, id: @account2.email)
      check_response :unauthorized
      header_auth
    end
    
    it "should return 200 for a valid, but unconfirmed account" do
      get(:show, id: @account_unconfirmed.email)
      check_response
      resp = JSON.parse(response.body)
      assert_equal 'Found Account', resp["message"]
      js = JSON.parse(response.body)
      assert_equal 2, js.length, "should only return a message and status"
    end

    it "should allow checking if temp password is valid - wireframe R4" do
      @account_unconfirmed.update!(password: @old_pass,
                                   password_confirmation: @old_pass)
      get(:show, id: @account_unconfirmed.email,
          :password => @old_pass)
      check_response
    end

    it "should return 401 if temp password is invalid - wireframe R4" do
      @account_unconfirmed.update!(password: @old_pass,
                                   password_confirmation: @old_pass)
      get(:show, id: @account_unconfirmed.email,
                   :password => 'greendoor')
      check_response :unauthorized
    end

    it "should return 401 if the confirmation token is expired and send reconfirmation email" do
      @account_unconfirmed.update!(password: 'bluedoor', password_confirmation: 'bluedoor',
                        confirmation_sent_at: Time.now - Devise.confirm_within)
      get(:show, id: @account_unconfirmed.email,
                 :password => 'bluedoor')
      check_response :unauthorized
    end

    # Account Confirmation
    # PUT /user/<email

    it "should reject confirmation without device type" do
      put(:update,
          id: @account_unconfirmed.email,
          confirmation_token: @account_unconfirmed.confirmation_token,
          password:     "xyz",
          first_name:   "New",
          last_name:    "User",
          device_model: "newdm",
          os_version:   "newov",
          app_version:  "newav",
          )
      check_response 422, :MISSING_PARAM
      @account_unconfirmed.reload
      assert_false @account_unconfirmed.confirmed?, 'account should not be confirmed'
      assert_not_equal "New User", @account_unconfirmed.full_name
      assert_false(@account_unconfirmed.valid_password?("xyz"), 'Invalid password')
    end

    it "should reject confirmation without password" do
      put(:update,
          id: @account_unconfirmed.email,
          confirmation_token: @account_unconfirmed.confirmation_token,
          first_name:   "New",
          last_name:    "User",
          device_type:  "iOS",
          device_model: "newdm",
          os_version:   "newov",
          app_version:  "newav",
          )
      check_response 422, :MISSING_PARAM
      @account_unconfirmed.reload
      assert_false @account_unconfirmed.confirmed?, 'account should not be confirmed'
      assert_not_equal "New User", @account_unconfirmed.full_name
      assert_false(@account_unconfirmed.valid_password?("xyz"), 'Invalid password')
    end

    it "should reject confirmation without first_name" do
      put(:update,
          id: @account_unconfirmed.email,
          confirmation_token: @account_unconfirmed.confirmation_token,
          password:     "xyz",
          first_name:   "New",
          device_type:  "iOS",
          device_model: "newdm",
          os_version:   "newov",
          app_version:  "newav",
          )
      check_response 422, :MISSING_PARAM
      @account_unconfirmed.reload
      assert_false @account_unconfirmed.confirmed?, 'account should not be confirmed'
      assert_false(@account_unconfirmed.valid_password?("xyz"), 'Invalid password')
    end

    it "should reject confirmation without last_name" do
      put(:update,
          id: @account_unconfirmed.email,
          confirmation_token: @account_unconfirmed.confirmation_token,
          password:     "xyz",
          first_name:   "New",
          device_type:  "iOS",
          device_model: "newdm",
          os_version:   "newov",
          app_version:  "newav",
          )
      check_response 422, :MISSING_PARAM
      @account_unconfirmed.reload
      assert_false @account_unconfirmed.confirmed?, 'account should not be confirmed'
      assert_false(@account_unconfirmed.valid_password?("xyz"), 'Invalid password')
    end

    def confirm_test(new_device, new_user_device, line, addl_params = {}, disallow_db = [])
      assert_false @account_unconfirmed.confirmed?, 'initially account should not be confirmed'
      put_data = {
        id: @account_unconfirmed.email,
        confirmation_token: @account_unconfirmed.confirmation_token,
        password:     "xyz",
        first_name:   "New",
        last_name:    "User",
        device_model: "newdm",
        os_version:   "newov",
        app_version:  "newav",
      }.merge(addl_params)
      line_str = ", test line: " + line.to_s
      assert_difference [ 'ActionMailer::Base.deliveries.size', "Notification.count" ], 0, line_str do
        assert_difference [ "Device.count" ], new_device ? 1 : 0, line_str do
          assert_difference [ "UserDevice.count" ], new_user_device ? 1 : 0, line_str do
            put(:update, put_data)
          end
        end
      end
      check_response
      @account_unconfirmed.reload
      assert @account_unconfirmed.confirmed?, 'account should be confirmed ' + line_str
      assert_equal "New User", @account_unconfirmed.full_name, line_str
      assert_true(@account_unconfirmed.valid_password?("xyz"), 'Invalid password ' + line_str)
      user_device = UserDevice.all.order('created_at ASC').last
      device = Device.all.order('created_at ASC').last
      assert_not_nil user_device.confirmed_at, "user_device is confirmed "+ line_str
      if put_data[:device_id]
        put_data[:id] = put_data[:device_id]
        put_data[:device_id] = nil
      end
      check_data(device, put_data, @non_device_fields, disallow_db, nil, line)
    end

    it "should confirm and update an account with new device, with device_type but no ua_token" do
      confirm_test("new", "new", __LINE__, {
                     device_type:  "iOS",
                   }, [ :ua_token ])
    end

    it "should confirm and update an account with existing device by ua_token" do
      confirm_test(false, "new", __LINE__, {
                     ua_token: ActiveSupport::TestCase.confirmed_device_token,
                     device_type: "iosdevelopment",
                   })
    end

    it "should confirm and update an account with existing device by device_id" do
      confirm_test(false, "new", __LINE__, {
                     device_id: @device.id,
                     device_type: "iosdevelopment",
                   })
    end

    it "should confirm and update an account with existing device by device_id, with matching ua_token" do
      confirm_test(false, "new", __LINE__, {
                     device_id: @device.id,
                     ua_token: ActiveSupport::TestCase.confirmed_device_token,
                     device_type: "iosdevelopment",
                   })
    end

    it "should require a valid confirmation code" do # and also make sure it's not already confirmed
      put(:update, id: @account_unconfirmed.email,
                   confirmation_token: "nosuchconfirmationtoken",
                   first_name: "New",
                   last_name: "User"
          )

      @account_unconfirmed.reload
      check_response :unauthorized
      assert_not_equal "New", @account_unconfirmed.first_name
      assert_equal false, @account_unconfirmed.confirmed?, "account should not be confirmed"
    end

    it "should return error 422 when invalid info" do
      #such as no password exists in account or request.
      @account_unconfirmed.encrypted_password = nil
      @account_unconfirmed.save!
      put(:update, id: @account_unconfirmed.email,
                   confirmation_token: @account_unconfirmed.confirmation_token,
                   first_name: "New",
                   last_name: "User"
        )
      @account_unconfirmed.reload
      check_response :unprocessable_entity
      assert !@account_unconfirmed.confirmed?, 'should not end up confirmed'
    end

    it "should throw a 422 when a string exceeds 255 characters" do
    put(:update, id: @account_unconfirmed.email,
                   confirmation_token: @account_unconfirmed.confirmation_token,
                   first_name: "thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_thisistenchars_",
                   last_name: "User"
        )
    check_response 422
    end 

    it "should return 401 if the confirmation token is expired" do
      @account_unconfirmed.update!(password: 'bluedoor', password_confirmation: 'bluedoor', confirmation_sent_at: Time.now - Devise.confirm_within)
      put(:update, id: @account_unconfirmed.email,
                   confirmation_token: @account_unconfirmed.confirmation_token,
                   first_name: "Ima",
                   last_name: "User")
      check_response :unauthorized
    end

    it "should not be able to confirm an already confirmed account" do
      @account.confirmation_token = "12345"
      @account.save
      # Forcing a confirmation token, since it's normally blanked out on confirmation
      put(:update, id: @account.email,
                   confirmation_token: @account.confirmation_token)
      check_response :unauthorized
    end

    it "should be able to confirm by temporary password" do
      @account_unconfirmed.update!(password: @old_pass,
                                   password_confirmation: @old_pass)
      put(:update, @confirmation_params)
      check_response
      @account_unconfirmed.reload
      assert @account_unconfirmed.confirmed?, 'should be confirmed'
    end

    it "should not be able to confirm with invalid temporary password" do
      @confirmation_params[:password] = "thisisnotmypassword!"
      put(:update, @confirmation_params)
      check_response :unauthorized
      @account_unconfirmed.reload
      assert !@account_unconfirmed.confirmed?, 'should not be confirmed'
    end

    it "should not be able to confirm by temporary password without first_name" do
      @account_unconfirmed.update!(password: @old_pass,
                                   password_confirmation: @old_pass)
      put(:update, @confirmation_params.except(:first_name))
      check_response 422
      @account_unconfirmed.reload
      assert !@account_unconfirmed.confirmed?, 'should not be confirmed'
    end

    it "should not be able to confirm by temporary password without password" do
      @account_unconfirmed.update!(password: @old_pass,
                                   password_confirmation: @old_pass)
      put(:update, @confirmation_params.except(:password))
      check_response 422
      @account_unconfirmed.reload
      assert !@account_unconfirmed.confirmed?, 'should not be confirmed'
    end

    it "should not be able to confirm by temporary password without device_type" do
      @account_unconfirmed.update!(password: @old_pass,
                                   password_confirmation: @old_pass)
      put(:update, @confirmation_params.except(:device_type))
      check_response 422
      @account_unconfirmed.reload
      assert !@account_unconfirmed.confirmed?, 'should not be confirmed'
    end

    it 'should change the password for confirmed users' do
      send_auth(@user_device)
      put(:update, id: @account.email,
                   old_password: @account.password,
                   password: @new_pass,
          )
      @account.reload
      check_response 200
      assert_true(@account.valid_password?(@new_pass), 'Invalid password')
    end

    it 'should sign out of all other devices on password change' do
      device2, @user_device2 = make_device(@user, "64ce3cbfb716c0eb61adc2d6da1f2781e8b74d39b49c1e521108db9109b1be50")
      @user_device2.update!(decommissioned_at: nil, 
                authenticated_at: Time.now, 
                confirmed_at: Time.now,
                keys_sent_at: Time.now)
      send_auth(@user_device)
      put(:update, id: @account.email,
              old_password: @account.password,
              password: 'aba45')
      check_response 200
      @account.reload
      @user_device2.reload
      assert_true(@account.valid_password?('aba45'), 'Invalid password')
      assert_equal @user_device2.authenticated_at, nil 
      assert_equal @user_device2.authentication_token, nil
    end

    it 'should edit the name for confirmed users' do
      send_auth(@user_device)
      put(:update, id: @account.email,
                   first_name: "Joe",
                   last_name: "Smith"
      )
      @account.reload
      check_response 200
      assert_equal "Joe Smith", @account.full_name
    end

    it 'should not be able to change the password for confirmed users with invalid password' do
      send_auth(@user_device)
      put(:update, id: @account.email,
                   old_password: "wrong_password",
                   password: @new_pass,
      )
      @account.reload
      check_response 403
    end

    it 'should not be able to change the password for confirmed users with no old password' do
      send_auth(@user_device)
      put(:update, id: @account.email,
                   password: @new_pass)
      @account.reload
      check_response 403
    end

    it 'should not be able to change the password for confirmed users with empty old password' do
      send_auth(@user_device)
      put(:update, id: @account.email,
                   old_password: "",
                   password: @new_pass)
      @account.reload
      check_response 403
    end

    it 'should not be able to change the password for confirmed users with empty new password' do
      send_auth(@user_device)
      put(:update, id: @account.email,
                   old_password: @account.password,
                   password: "")
      @account.reload
      check_response 422
    end

    it 'should not be able to change the password for confirmed users with no new password' do
      send_auth(@user_device)
      put(:update, id: @account.email,
                   old_password: @account.password)
      @account.reload
      check_response 422
    end

    it 'should not be able to change the password for confirmed users without authtoken' do
      # empty auth
      header_auth
      put(:update, id: @account.email,
                   old_password: @account.password,
                   password: @new_pass)
      @account.reload
      check_response 401
    end

    it 'should not be able to change the password if email not authenticated account' do
      send_auth(@user_device)
      put(:update, id: @account_unconfirmed.email,
                   old_password: @account.password,
                   password: @new_pass)
      @account.reload
      check_response 422, :WRONG_PARAM, __LINE__
    end

    # Account Creation
    # POST /users

    it "should create an account" do
      assert_difference "Account.count", +1 do
        post(:create, email: "newaccount@example.com")
        check_response
      end

      # At least we can check that we sent something, TODO make sure it's right
      mail = ActionMailer::Base.deliveries.last
      assert_equal 'newaccount@example.com', mail['to'].to_s
    end

    it "should not create an account if one exists" do
      assert_no_difference "Account.count" do
        post(:create, email: @account.email)
      end
      check_response :conflict, ""
    end

    it "should require a email address" do
      post(:create)
      check_response :unprocessable_entity, :MISSING_PARAM
    end

    it "should require a valid/correct email address format" do
      post(:create, email: "notavalid,email@example.com")
      check_response :unprocessable_entity, "Invalid Account"
    end

    # Case Sensitivity Checks
    it "should ignore email capitalization for show method" do
      # XXX it's broken???
      get(:show, id: @account.email.upcase)
      check_response :unauthorized
    end

    it "should ignore email capitalization for create method" do
      post(:create, email: @account.email.upcase)
      check_response :conflict
    end

    it "should ignore email capitalization for update method" do
      # XXX it's broken???
      put(:update, id: @account_unconfirmed.email.upcase, 
          old_password: "dummypassword")
      check_response :unauthorized
    end
    
    # Resend confirmation mails
    it "should resend a confirmation email to a unconfirmed account" do
      assert_difference "ActionMailer::Base.deliveries.count", +1 do
        put(:update, id: @account_unconfirmed.email, resend: true)
      end
      assert ActionMailer::Base.deliveries.last.body.match /confirmation_token/
    end

    # Basic Reset Password
    it "should trigger a password reset email" do
      assert_equal nil, @account.reset_password_token
      assert_difference "ActionMailer::Base.deliveries.count", +1 do
        put(:update, id: @account.email, resend: true)
      end
      assert ActionMailer::Base.deliveries.last.body.match /reset_password_token/
      @account.reload
      assert_not_equal nil, @account.reset_password_token
    end
    
    it "should trigger a password reset email and on password reset sign out all users devices" do
      device2, @user_device2 = make_device(@user, "64ce3cbfb716c0eb61adc2d6da1f2781e8b74d39b49c1e521108db9109b1be50")
      @user_device2.update!(decommissioned_at: nil, 
                authenticated_at: Time.now, 
                confirmed_at: Time.now,
                keys_sent_at: Time.now)
      assert_equal nil, @account.reset_password_token
      assert_difference "ActionMailer::Base.deliveries.count", +1 do
        put(:update, id: @account.email, resend: true)
      end
      assert ActionMailer::Base.deliveries.last.body.match /reset_password_token/
      @account.reload
      assert_not_equal nil, @account.reset_password_token
      send_auth(@user_device)
      put(:update, id: @account.email,
            old_password: @account.password,
            password: 'aba45',)
      check_response 200
      @account.reload
      @user_device2.reload
      assert_true(@account.valid_password?('aba45'), 'Invalid password')
      assert_equal @user_device2.authenticated_at, nil 
      assert_equal @user_device2.authentication_token, nil
    end


    it "should allow resetting password with valid token" do
      assert_difference "ActionMailer::Base.deliveries.count", +1 do
        put(:update, id: @account.email, resend: true)
      end
      @account.reload

      put(:update, id: @account.email, reset_password_token: @account.reset_password_token, password: "4mynewpassword!")
      check_response :success
    end
    
    it "should not reset with an invalid token" do
      assert_difference "ActionMailer::Base.deliveries.count", +1 do
        put(:update, id: @account.email, resend: true)
      end
      
      put(:update, id: @account.email, reset_password_token: "thewrongtoken", password: "4mynewpassword!")
      check_response :unauthorized
    end

    it "should not allow resetting again with same reset token" do
      assert_difference "ActionMailer::Base.deliveries.count", +1 do
        put(:update, id: @account.email, resend: true)
      end
      @account.reload

      put(:update, id: @account.email, reset_password_token: @account.reset_password_token, password: "4mynewpassword!")
      check_response :success
      put(:update, id: @account.email, reset_password_token: @account.reset_password_token, password: "anoternewpassword!")
      check_response :unauthorized
    end

  end
end

