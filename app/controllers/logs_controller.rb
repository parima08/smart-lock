class LogsController < ApplicationController
  before_filter :json_authenticate, if:  :token_present?
  before_filter :json_lock_auth,    unless: :token_present?
  respond_to :json

  # Map ua_token and lock_serial to device and lock id's, may get lock.
  def get_ids(params)
    return false if !get_lock_id(params)
    # ua_token support not actually required in POST case
    if params[:ua_token]
      device = Device.where(ua_token: params[:ua_token])
      if (device.count == 0)
        render_error_modelname(404, :MISSING_RECORD, Device)
        return false
      end
      params[:device_id] = device.first.id
    end
    return true
  end

  # GET /logs/id, GET /logs/serial/serial,
  # GET /logs/device_id/id, GET /logs/ua_token/ua_token
  # Currently only returns existence.
  def show
    return if params_missing([ :id, :lock_serial, :device_id, :ua_token ],
                             params, true)
    return if params_missing([:source, :fault_time ], params)
    return if !get_ids(params)

    log = nil
    where_clause = {
      source: params[:source],
      fault_time: DateTime.parse(params[:fault_time])
    }
    if params[:device_id]
        where_clause[:device_id] = params[:device_id]
    else
      where_clause[:lock_id] = params[:lock_id]
    end
    log = Log.where(where_clause)

    # TBD: Depending on how the lock sends logs to the
    # server, we have to set wifi up
    # LP: 19485385
    # if token_present?
    #   lock =  Lock.find_by_lock_serial(params[:lock_serial])
    #   lock.update_with_wifi(LockCommState::LOCK_COMM_UP, request.uuid)
    # end

    if log && (log.count > 0)
      render_success
    else
      render_error_modelname(404, :MISSING_RECORD, Log)
    end
  end

  # POST /logs
  def create
    return if params_missing([ :lock_id, :lock_serial, :device_id, :ua_token ],
                             params, true)
    return if params_missing([:source, :data, :fault_time ], params)

    if params[:source] != "lock" && @current_account == nil
      return render_error(401, :UNAUTHORIZED)
    end

    # Undefined what happens on a repeat upload.  You just get another currently.

    # Model validators handle param validity, once mapped to lock_id
    return if !get_ids(params)
    params[:data] = Base64.decode64(params[:data])
    params[:uuid] = request.uuid
    # Create the data item, add id to log item.
    log_data = LogData.new(params.permit(LogData.settable))
    return check_save_failure(log_data) if !log_data.save

    params[:log_data_id] = log_data.id
    log = Log.new(params.permit(Log.settable))
    if !log.save
      # Delete the bad data record created above
      log_data.delete
      return check_save_failure(log)
    end
    render_success
  end

end
