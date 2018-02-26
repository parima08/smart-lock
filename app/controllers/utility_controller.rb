class UtilityController < ApplicationController

  force_ssl if: lambda {GojiServer.config.use_ssl_if_possible}

  before_filter :authenticate_account!
  before_filter :ensure_admin_account

  respond_to :html

  #
  # Raises an exception on demand
  # Useful for testing/verifying exception logging/notifications
  #
  def error
    raise "This is only a test: Raising Exception!"
  end

  def soft_error
    begin
      raise "This is only a test: Handle this error gracefully!"
    rescue => e
      ErrorRecorder.notice_exception("recovered from error", e)
    end
    render text: "Error was raised, but handled"
  end

  def download_log_file
    send_data LogData.find(params[:log_data_id]).data ,
              :filename => "log_#{params[:log_data_id]}.txt"
  end

end
