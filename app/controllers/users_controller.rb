
class UsersController < ApplicationController

  # Allow detecting email non-existence when not authenticated.
  before_filter :json_authenticate, if: :token_present?

  force_ssl if: lambda{ GojiServer.config.use_ssl_if_possible }

  respond_to :json

  def show
    # This was weird, ignoring the users/id in the URL!
    @user = Account.first_by_email(params[:id]).try(:user)
    if @user.nil?
      # This is a normal flow to check for email existence so isn't logged.
      render_error_modelname(404, :MISSING_RECORD, User)
    elsif !@user.account.confirmed? && @user.account.confirmation_sent_at &&
      @user.account.send(:confirmation_period_expired?)
      render_error(401, "Confirmation Token Expired")
    elsif @user.account.confirmed? == false &&
          @user.account.encrypted_password.present? &&
          (params[:password].blank? || @user.account.valid_password?(params[:password]))
      # Either we don't supply a password, or if we do, it must match
      # Used to handle checking of existence and or temp password for unconfirmed accounts
      # See wireframe: R.4
      render_success("Found Account")
    elsif token_present? && @current_account && @user.id == @current_account.user.id
      # XXX exclude encrypted_password and any other non-secure fields!
      user = get_payload_hash(@user, [:account_id])
      user[:account] = get_payload_hash(@user.account, [:password,
                                                        :password_confirmation,
                                                        :admin,
                                                        :confirmation_token,
                                                       ], nil, false)
      render :json => user
    else
      name = "User=#{params[:id]}"
      log_security_unauthorized_alert_message("User", name, "not authenticated")
      render_error(401, :UNAUTHORIZED)
    end
  end

  # POST /users
  # Creates/re-sends an account invite for a unkown user
  def create
    return if params_missing([ :email ], params)

    account = Account.first_by_email(params[:email])
    if account
      render_error(409, "Account with this email already exists!")
    else
      account = Account.new(email: params[:email], user: User.new, uuid: request.uuid)
      if account.save
        render_success
      else
        check_save_failure(account)
      end
    end
  end

  # PUT /users/<email address>
  # Used for confirming account and adding first/last/password, and password change.
  def update
    #
    # Update Record / Change Password
    #
    if token_present? && @current_account
      if @current_account.email != params[:id]
        return render_error(422, :WRONG_PARAM, "email")
      end
      # Do any privileged operations here, we're authenticated
      # IE update name, update email?, update password
      update_account_authenticated
    #
    # ResetPassword/Confirm Account
    #
    else
      # Not authenticated...couple things we could be trying to do
      @account = Account.first_by_email(params[:id])
      if @account.nil?
        # No account found
        render_error_modelname(404, :MISSING_RECORD, User)
      #resend confirmation token (and regenerate token if expired)
      elsif params['resend'].present?
        update_resend_account
      #if the confirmation token has expired, error out
      elsif !@account.confirmed? && @account.send(:confirmation_period_expired?)
        render_error(401, "Confirmation Token Expired")
      elsif !@account.confirmed? && (params[:confirmation_token].present? || params[:old_password].present?)
        # Unconfirmed accounts
        # Confirming and setting name and password details
        update_and_confirm_account
      elsif @account.confirmed? && params[:reset_password_token]
        update_and_reset_password
      else
        name = "User=#{params[:id]}"
        log_security_unauthorized_alert_message("User", name, "not authenticated")
        render_error(401, :UNAUTHORIZED)
      end
    end
  end


  #
  # Updates an authenticated users account information
  # breaking out update/PUT method above
  #
  private def update_account_authenticated
    if params[:old_password].present? || params[:password].present?
      # We're changing our password
      # TODO Reset authtoken? and force the app to re-fetch it?
      if !@current_account.valid_password?(params[:old_password])
        return render_error(403, :INVALID_CURRENT_PASSWORD)
      end
      return if params_missing([ :password ], params)
      @current_account.password = params[:password]
      @current_account.password_confirmation =  params[:password]
      log_out_ud(@current_account, @current_device)
    else
      # Update other account information, if supplied
      @current_account.first_name = params[:first_name] if params[:first_name].present?
      @current_account.last_name  = params[:last_name]  if params[:last_name].present?
    end

    if @current_account.save
      return render_success
    else
      check_save_failure(@current_account)
    end
  end

  # If account is unconfirmed and either old_password (receive access,
  # temporary password) OR confirmation_token (create account from
  # app), password and account info are updated.
  private def update_and_confirm_account
    #checks to make sure correct password/confirmation token is provided
    if params[:old_password].present? && !@account.valid_password?(params[:old_password])
      return render_error(401, :INVALID_CURRENT_PASSWORD)
    elsif params[:confirmation_token].present?
      if !Devise.secure_compare(@account.confirmation_token, params[:confirmation_token])
        return render_error(401, "Invalid confirmation_token")
      end
    end

    return if params_missing([ :password, :first_name, :last_name ] + Device.required, params)

    @ok = true
    # XXX Need unit test cases for @ok false paths below.
    @account.transaction do

      begin
        @account.first_name = params[:first_name] if params[:first_name].present?
        @account.last_name  = params[:last_name]  if params[:last_name].present?
        @account.password   = params[:password]   if params[:password].present?
        @account.password_confirmation = @account.password # We only enter once at the API
        @account.confirm_and_save!
      rescue => e
        render_error(422, "Could not confirm account!")
        @ok = false
        raise ActiveRecord::Rollback
      end

      # Confirm account creation, and create/update device.
      # Create user_device to store auth token, preconfirmed.
      # Even if the device already exists, we should demand the
      # device info be updated.
      device = Device.get_from_request(params)
      device, user_device = create_user_device(params, device,
                                               @account.user, "confirmed")
      if !device # has reported error
        @ok = false
        raise ActiveRecord::Rollback
      end

    end # End Transaction

    render_success if @ok
  end

  private def update_and_reset_password
    if !Devise.secure_compare(@account.reset_password_token, params[:reset_password_token])
      return render_error(401, "Invalid Token")
    elsif @account.reset_password_period_valid? == false
      return render_error(401, "No longer valid")
    end
    if @account.reset_password!(params[:password], params[:password])
      log_out_ud(@account, nil)
      render_success
    else
      check_save_failure(@account)
    end
  end

  private def update_resend_account
    if @account.confirmed?
      @account.send_reset_password_instructions
      render_success
    else
      @account.send_confirmation_instructions
      render_success
    end
  end

  private def log_out_ud(account, current_device)
  user_devices = account.user.user_devices
  user_devices.each do |ud| 
    ud.logout if ud.device != current_device
  end
  end

  def self.is_dev
   Rails.env != "production" && Rails.env != "staging"
  end

end
