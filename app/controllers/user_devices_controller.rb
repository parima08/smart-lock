class UserDevicesController < ApplicationController

  before_action :json_authenticate

  respond_to :json

  #PUT /user_devices/:id , 
  # device_confirmation_token to confirm user_device registration...
  def update
    # Note that user, device, and user_device are implicit in auth,
    # but only user matches the id arg; an existing device must confirm a new device.
    return if params_missing([:id, :device_confirmation_token], params)
    user_device = UserDevice.find_by_id(params[:id])
    return render_error_modelname(404, :MISSING_RECORD, UserDevice) if !user_device

    return render_error(422, :WRONG_ACCOUNT_PARAM, "id") if user_device.user.account != @current_account
    # Must NOT confirm from new device!
    return render_error(422, :WRONG_DEVICE, "id") if params[:id] == @current_user_device.id.to_s
    # Don't check token until all of above pass.  I think.
    return render_error(422, :WRONG_PARAM, "device_confirmation_token") if (params[:device_confirmation_token] != user_device.confirmation_token)

    if !user_device.decommissioned_at.nil?
       return render_error(409, :DECOMMISSIONED)
    end

    if user_device.confirmed_at.nil?
      user_device.confirmed_at =  DateTime.now
      return check_save_failure(user_device) if !user_device.save
    end
    
    render_success
  end

  # Disassociate user from device.
  # Note that user, device, and user_device are implicit in auth,
  # but we are still asking for explicit user_device id param here.
  # So validate it!
  def destroy
    return if params_missing([:id], params)
    return render_error(422, :WRONG_ACCOUNT_PARAM, "id") if params[:id] != @current_user_device.id.to_s
    @current_user_device.decommissioned_at = DateTime.now
    return check_save_failure(@current_user_device) if !@current_user_device.save
    # XXX should we decommission the device too if this is the last user?
    render_success
  end

end
