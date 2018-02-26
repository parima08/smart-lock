class PicturesController < ApplicationController

  # Only lock posts here. However, current alpha2 auth checks don't seem to be compatible
  # TODO proper lock only authentication for this method
  #before_filter :json_lock_auth

  respond_to :json

  def create
    return if params_missing([ :lock_id, :lock_serial ], params, true)
    return if params_missing([ :picture, :taken_at ], params)

    # Allow sending picture before commissioning is complete.
    lock = Lock.get_active_else_not(params)
    return render_error_modelname(404, :MISSING_RECORD, Lock) if lock.nil?

    # TODO, reject excessively large images (as quickly as possible,
    # ideally with server request size limit)
    # TODO, reject images with taken_at outside reasonable range.

    lock.update_with_wifi(LockCommState::LOCK_COMM_UP, request.uuid)

    # TODO, do we need some sort of transaction handling around this?
    picture = params[:picture]
    logger.debug "Byte count from picture[:data]: #{picture[:data].bytesize}\n"
    logger.debug "First 40 bytes from picture[:data]: #{picture[:data][0..40]}\n"
    logger.debug "Mime Content Type:         #{picture[:content_type]}\n"
    logger.debug "Filename :                 #{picture[:original_filename]}\n"
    # decode64 not strict, should not fail.
    pic = Picture.new(data: StringIO.new(Base64.decode64(picture[:data])),
                      lock: lock,
                      taken_at: params[:taken_at],
                      data_content_type: picture[:content_type],
                      data_file_name:    picture[:original_filename],
                      )
    if pic.save
      render_success
    else
      check_save_failure(pic)
    end
  end

end
