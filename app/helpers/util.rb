class Util
  # Returns: formatted error string from model.errors.
  def self.format_validation_errors(errors)
    if !errors.messages
      return ""
    end
    message = "validation errors: "
    errors.messages.each do |msg|
      message += msg.to_s
    end
    message
  end

  @@VALIDATOR_MSGS =  {
    DATE: "is not a valid date",
    TIME: "is not a valid time",
    INTEGER: "is not a valid integer",
    DATE_ORDER: "must be later than start_date",
    BLANK: "can't be blank",
    TIME_ORDER: "must be later than start_time",
    OFFSET_ORDER: "must be later than start_offset",
    ADMIN_KEY_UNLIMITED: "Error updating key: admin plus time-limited access not allowed: admin requires unlimited access",
  }

  def self.VALIDATOR_MSGS
    @@VALIDATOR_MSGS
  end

  def self.is_dev
    Rails.env != "production" && Rails.env != "staging"
  end

end

