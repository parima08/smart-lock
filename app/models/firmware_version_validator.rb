class FirmwareVersionValidator < ActiveModel::Validator
  def validate(record) 
    options[:fields].each do |field|  
      required_version_available(record, field)
    end
  end

  def required_version_available(record, field)
    firm = FirmwareVersionValidator.get_firmware(record, field)
    if (firm != nil) && (firm.count == 0)
        record.errors[:field] = "#{field.to_s} is not an available firmware version"
    end
  end

  # Returns nil if lock.field required*version is absent,
  # else relation with matching firmware record if any.
  def self.get_firmware(record, field)
    value = record.read_attribute(field)
    if ApplicationController.is_empty(value)
      return nil
    end
    Firmware.where("for_external = ? AND version = ?",
                   field.to_s.include?("required_external_version"),
                   value)
  end
end

