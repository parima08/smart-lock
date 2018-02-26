class StringLengthValidator < ActiveModel::Validator
  def validate(record)
    check_attributes = options[:exclude] ? record.class.accessible_attributes.to_a - options[:exclude] :
                                          record.class.accessible_attributes.to_a
    check_attributes.each do |name|
      if record.has_attribute?(name) && record.read_attribute(name).class == String && 
         record.read_attribute(name).length > StringLength::STRLIM_DB.to_i
          record.errors[:msg] = "#{name} exceeds maximum string length of #{StringLength::STRLIM_DB}"
      end
    end
  end
end
