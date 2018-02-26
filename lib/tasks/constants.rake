namespace :constants do

  desc "generates shared constants"
  task :generate do
    MATCH_STRINGS = /static const char \*([\d\w]+)Strings\[\]\=\{([^\}]+)\}\;/m # Match multiline
    MATCH_CONSTANTS = /case\s([A-Z_]+):\s+return\s+([\d\w]+)Strings\[(\d+)\];/
    MATCH_STRING_LENGTH = /#define\s+(\w+)\s+(\d+)/
    MATCH_CRYTO_DEFINE = /#define\s+(RSA[A-Z_]+)\s+([\"].+[\"])/

    SOURCE_FILE = File.dirname(__FILE__) + '/../../../firmware/firmware/common/goji_types.c'
    H_SOURCE_FILE =  File.dirname(__FILE__) + '/../../../firmware/firmware/common/goji_types.h'
    OUTPUT_FILE = File.dirname(__FILE__) + '/../../config/initializers/goji_constants.rb'

    FILE_HEADER = <<EOF
#
# Auto Generated Constants for Goji Project
# Do Not Edit This File Directly!
# Generated by rake constants:generate
#

#
# Base class to hold helpers for working with constants
#
class GojiConstants
  #
  # This is designed for using with validations
  #
  def self.values
    return constants.map { |co| const_get(co) }
  end
end

EOF

    code = File.read(SOURCE_FILE)
    rawstrings   = code.scan(MATCH_STRINGS)
    rawconstants = code.scan(MATCH_CONSTANTS)
    # Parse out string values
    string_data = {}
      rawstrings.map do |key,vals|
      string_data[key] = JSON.parse('['+vals+']')
    end

    # Group up the constants
    constants_groups = rawconstants.group_by { |v| v[1] }

    # Merge the definitions with the values
    constants_full = {}
    constants_groups.each do |group, constants|
      temp = {}
      constants.map do |const, key, idx|
        begin
          temp[const] = string_data[key][idx.to_i]
        rescue
          puts "Could not find values for " + const
        end
      end
      constants_full[group] = temp
    end

    constants_full["eventType"].merge!({
      'KEY_SHARED' => 'key_shared',
      'KEY_REVOKED' => 'key_revoked',
      'KEY_EXPIRED' => 'key_expired',
      'ADMIN_SHARED' => 'admin_shared',
      'ADMIN_REVOKED' => 'admin_revoked',
      'ACCESS_CHANGED' => 'access_changed',
      'LOCK_DECOMMISSIONED' => 'lock_decommissioned',
      'USER_DEVICE_CONFIRMED' => 'user_device_confirmed',
      'ERROR_NOTIFY_SYSADMIN ' => 'error_notify_sysadmin',
      'ERROR_NOTIFY_OWNER_ADMIN' => 'error_notify_owner_admin'
    })

    constants_full["ErrorEventCode"] = {
      "ERR_EV_CODE_UNDEFINED" => '0',
      "ERR_EV_CODE_LOCK_REJECT_CREDENTIAL" => '1',
      "ERR_EV_CODE_INTERNAL_OTA_FAILURE" => '2',
      "ERR_EV_CODE_EXTERNAL_OTA_FAILURE" => '3'
    }

    # Reads goji_type.h for constants for String Length
    h_code = File.read(H_SOURCE_FILE)
    h_rawstrings = h_code.scan(MATCH_STRING_LENGTH)
    h_string_data = {}
      h_rawstrings.map do |key,vals|
      h_string_data[key] = vals
    end
    constants_full["stringLength"] = h_string_data

    #Read cryto parameters string definition
    crypt_def = File.read(H_SOURCE_FILE)
    crypt_strings = h_code.scan(MATCH_CRYTO_DEFINE)
    h_string_data = {}
      crypt_strings.map do |key,vals|
      vals = vals.tr("'\"", "")
      h_string_data[key] = vals
    end
    h_string_data['STRLIM_DB'] = '255'
    constants_full["stringLength"].merge!(h_string_data)
    constants_full["gojiCryptoParam"] = {}
    output = FILE_HEADER

    # Alternatively, to use only a specified list
    #     TO_INCLUDE = ['boltState', 'batteryState', 'heartbeatState', 'networkState', 'eventType', 'proximityEventType', 'orientationType', 'commissionStateType', 'commandResult']
    # TO_INCLUDE.each do |group|
    constants_full.map do |group, items|
      class_name = group.classify
      const_prefix = class_name.underscore.upcase # Prefix being removed
      const_prefix = "EVTYPE" if const_prefix == "EVENT_TYPE" # Special case
      const_prefix = "BOLT" if const_prefix == "BOLT_STATE"

      #puts "Class_name: " + class_name
      #puts "Const_prefix: " + const_prefix
      if class_name=='GojiCryptoParam'
        output += "class " + class_name + " < StringLength\n"
      else
        output += "class " + class_name + " < GojiConstants\n"
      end

     if class_name == 'ErrorEventCode'
       constants_full[group].map do |key, val|
         output += "  "+ key.sub(const_prefix + "_", "") + " = " + val + "\n"
        end
     else
      constants_full[group].map do |key, val|
        output += "  "+ key.sub(const_prefix + "_", "") + " = '" + val + "'\n"
      end
     end
      output += "end\n\n"
    end

    puts output

    # Write it
    File.open(OUTPUT_FILE, 'w') { |file| file.write(output) }

  end

end