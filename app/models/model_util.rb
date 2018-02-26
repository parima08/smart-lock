# Common model "mixin".
# An intermediate subclass of ActiveRecord::Base has special semantics
# and is not an option.
# Mixin methods aren't public, so can't be called from an including
# class method on an instance it owns. (see create_user_key)
# So we don't really mixin this (though we could).

module ModelUtil

  # Returns: formatted error string from model.
  def self.format_validation_error(model)
      "Invalid #{model.class} parameters: " + Util.format_validation_errors(model.errors)
  end

end
