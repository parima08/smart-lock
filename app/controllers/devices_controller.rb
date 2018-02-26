class DevicesController < ApplicationController

  before_action :json_authenticate

  respond_to :json

  # XXX Obsolete once apps move to alpha 2 model: device is created at GET /authtoken.
  def create
    # Can't require ua_token, we think:
    return if params_missing([ :device_type ], params)
    # Check if token association exists
    device = Device.get_from_token(params)
    if !device
      # Create the device
      permitted = params.permit(Device.settable).merge(uuid: request.uuid)
      device = Device.new(permitted)
    else
      # Update device endpoint registration (since the app is telling us it's active)
      device.update_push_endpoint
    end
    if !device.save
        check_save_failure(device)
    else
      user_device = UserDevice.new(user_id:   @current_account.user.id,
                                   device_id: device.id,
                                   uuid:      request.uuid,
                                   authenticated_at: DateTime.now)
      if !user_device.save
        check_save_failure(user_device)
      else
       device_hash = get_payload_hash(device, nil)
       device_hash[:user_device] = get_payload_hash(user_device, 
                                                    [
                                                     :confirmation_token,
                                                     :authentication_token,
                                                     :confirmed_at,
                                                     :decommissioned_at,
                                                     :private_key,
                                                     :keys_sent_at,
                                                     :name], nil, false)
       render :json => device_hash
      end
    end
  end

  #PUT /devices/:id authenticated, ua_token, os_version, app_version, device_model, device_type
  def update
    # Note that user, device, and user_device are implicit in auth,
    # but we are still asking for explicit id param.
    # Validate it!
    return if params_missing([:id], params)
    return render_error(422, :WRONG_ACCOUNT_PARAM, "id") if params[:id] != @current_device.id.to_s

    if !@current_user_device.decommissioned_at.nil?
       return render_error(409, :DECOMMISSIONED)
    end

    @current_device.assign_attributes(params.permit(Device.settable))
    @current_device.update_push_endpoint
    return check_save_failure(@current_device) if !@current_device.save

    render_success
  end

  # Logout user from device. 
  # Note that user, device, and user_device are implicit in auth,
  # but we are still asking for explicit device id param here.
  # So validate it!
  def destroy
    return if params_missing([:id], params)
    return render_error(422, :WRONG_ACCOUNT_PARAM, "id") if params[:id] != @current_device.id.to_s
    return check_save_failure(@current_user_device) if !@current_user_device.logout
    render_success
  end

end
