class ValidIntegerOrEmptyValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    original = record.send(attribute.to_s + "_before_type_cast")

    # Allow nil or "" values
    return if original.nil? || original == ""

    # See if it will cast correctly
    begin
      Integer original
    rescue ArgumentError
      record.errors[attribute] << (options[:message] || Util.VALIDATOR_MSGS[:INTEGER])
    end
  end
end

