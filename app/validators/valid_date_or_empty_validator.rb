class ValidDateOrEmptyValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    original = record.send(attribute.to_s + "_before_type_cast")

    # If we have value other than nil, then it typecasted correctly, no need to do it again
    # Otherwise allow nil or "" values
    return if !value.nil? || original.nil? || original == ""

    begin
      DateTime.parse(original)
    rescue
      record.errors[attribute] << (options[:message] || Util.VALIDATOR_MSGS[:DATE])
    end
  end
end
