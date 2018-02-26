class AuthtokenController < ApplicationController

  respond_to :json

  force_ssl if: lambda{ GojiServer.config.use_ssl_if_possible }

  def show
    headers_to_params

    # Authtoken is user_device-specific.
    # We could require ua_token here even when device_id is present.
    # But it's not essential, just for updating ua_token on change.
    # Further, ua_token may not be sent if notifications are disabled.
    # Device_type is required to lookup by ua_token.
    # XXX passing user/pass in params is deprecated for security, will be
    # removed once apps catch up.
    return if params[:ua_token] && !params[:device_id] &&
              params_missing([:device_type], params)

    ret = nil
    missing = params_missing([:password, :email], params, false, false)
    if missing
      # Collect header user+pass, authenticate below.
      if authenticate_with_http_basic do |user, pass| 
          params[:email] = user
          params[:password] = pass
        end
      else
        return render_params_missing(missing, false)
      end
    end

    # Would like to lookup the device first, ahead of variable-timed
    # password validation hashing.  But more important not to create
    # a device/send email without authenticating.
    account = Account.first_by_email(params[:email])
    # Note that this omits the HTTP standard WWW-Authenticate+realm
    # header on 401 reply, which we don't currently need for our
    # device client.
    if !account || !account.valid_password?(params[:password])
      log_security_brute_force_alert_message(params[:email], !account)
      return render_error(401, :UNAUTHORIZED)
    end
    # No user_device? Add unconfirmed device to account, return
    # device_id.  Start/resend device confirmation if unconfirmed,
    # unless device_id is provided, in which case return error (user
    # Continue button)
    # Note that if the app user data is cleared (app uninstall on IOS)
    # the user must confirm device, same as adding a new one, but
    # only if not already confirmed.
    # User-requested email resend on the wait screen is indicated by
    # sending no device_id.
    # ua_token must be unique, so we share one device record with null
    # ua_token for all unidentified devices of the same type.
    # Debatable whether this should be allowed at all, given no
    # notification.
    device = Device.get_from_request(params)
    # Find else create device, user_device
    device, user_device, user_device_exists = create_user_device(params, device,
                                                                 account.user, false)
    return if !device # create_user_device has reported error
    if !user_device_exists || 
       (!user_device.confirmed_at && !params[:device_id])
      # Do not auth, instead start/resend device confirmation.
      user_device.create_confirmation_event
      render :json => {
        device_id: device.id,
      }
      return
    elsif !user_device.confirmed_at 
      # Not ready to authenticate yet, user must respond before Continue.
      return render_error(409, "New device not yet confirmed")
    end

    # Update the ua_token and device info which can change at any time.
    if params[:device_id] && params[:ua_token] &&
         (device.ua_token != params[:ua_token])
      device.ua_token = params[:ua_token]
      device.save!
    end


    # Policy: only one user_device should be marked authenticated for
    # any given device at a time (else multiple notifications will be
    # sent to the same device)
    # performance: Would straight SQL be more efficient here?
    logged_in = UserDevice.where(device_id: device.id)
                          .where.not(id: user_device.id)
    logged_in.each do |ud|
      return check_save_failure(ud) if !ud.logout
    end
    return check_save_failure(user_device) if !user_device.login

    json = {
      authtoken:      user_device.authentication_token,
      user_id:        account.user.id,
      user_device_id: user_device.id,
      device_id:      device.id,
    }
    # If this delivery of keys to the device fails, the
    # device login will also fail.  Then the device needs to ask
    # for the keys at next login if it does not have the Arxan keys.
    # Also if the app user data is cleared.  Hence this need_keypair flag!  
    # Once apps are sending need_keypair, we don't really need to check
    # keys_sent_at here, but I'd still like to track the state at the
    # server I think.  It really amounts to "first login date/time".
    if !user_device.keys_sent_at || params["need_keypair"]
      ud_arxan_gen = UserDeviceArxanKeysGen.new
      ud_arxan_gen.gen_arxan_key_pairs
      arxan_private_key_base64, arxan_public_key_base64 = ud_arxan_gen.get_user_device_arxan_key_pairs_base64
      if !arxan_private_key_base64 || !arxan_public_key_base64
        return render_error(422, "Could not create user-device Arxan keypair!")
      end
      user_device.private_key = ud_arxan_gen.get_openssl_priv_key_data
      user_device.keys_sent_at =  DateTime.now
      # XXX Performance: eliminate extra save v.s. ud.login above.
      # Would be nice if there was a dirty bit in the model - is there?
      return check_save_failure(user_device) if !user_device.save
      # Now signal that credentials need updating to locks.
      user_device.update_credentials

      id = user_device.id
      udd = arxan_public_key_base64  #udd: Arxan pub key, ude Arxan priv key
      ude = arxan_private_key_base64
      key_pair = {id: id, udd: udd, ude: ude}
      json_string = render_to_string :json => key_pair
      json[:user_device_keypair] =  key_pair
      json[:signature] =  GojiMasterKeysGen.sign(json_string)
    end
    render :json => json
  end

end
