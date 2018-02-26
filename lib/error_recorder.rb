class ErrorRecorder

  def self.notice_exception(msg, ex, options = {})
    Rails.logger.error("GojiOps: Exception Noticed: " + msg + " : " + ex.message)
    NewRelic::Agent.notice_error(ex, options)
  end

  def self.notice_problem(msg)
    Rails.logger.warn("GojiOps: Problem Noticed: " + msg)
  end

end
