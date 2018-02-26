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

class BoltState < GojiConstants
  FAILED = 'failed'
  LOCKED = 'locked'
  UNLOCKED = 'unlocked'
  MOVING = 'moving'
end

class BatteryState < GojiConstants
  LOW = 'low'
  OK = 'ok'
end

class HeartbeatState < GojiConstants
  HEARTBEAT_DEAD = 'dead'
  HEARTBEAT_ALIVE = 'alive'
end

class NetworkState < GojiConstants
  NO_WIFI = 'no_wifi'
  NO_SERVER = 'no_server'
  CONNECTED = 'connected'
end

class EventType < GojiConstants
  LOCK = 'lock'
  UNLOCK = 'unlock'
  BATTERY = 'battery'
  PROXIMITY = 'proximity'
  LOCK_COM = 'wifi'
  NETWORK = 'network'
  KEY_SHARED = 'key_shared'
  KEY_REVOKED = 'key_revoked'
  KEY_EXPIRED = 'key_expired'
  ADMIN_SHARED = 'admin_shared'
  ADMIN_REVOKED = 'admin_revoked'
  ACCESS_CHANGED = 'access_changed'
  LOCK_DECOMMISSIONED = 'lock_decommissioned'
  USER_DEVICE_CONFIRMED = 'user_device_confirmed'
  ERROR_NOTIFY_SYSADMIN  = 'error_notify_sysadmin'
  ERROR_NOTIFY_OWNER_ADMIN = 'error_notify_owner_admin'
end

class ProximityEventType < GojiConstants
  OUT_OF = 'out_of'
  INTO = 'into'
end

class OrientationType < GojiConstants
  LEFT_HAND = 'left'
  RIGHT_HAND = 'right'
end

class CommissionStateType < GojiConstants
  COMMISSIONED = 'commissioned'
  UNCOMMISSIONED = 'uncommissioned'
  WIFI_CONNECTING = 'wifi_connecting'
  WIFI_FAILED = 'wifi_failed'
  REGISTERING = 'registering'
  REGISTER_FAILED = 'register_failed'
  REGISTERED = 'registered'
end

class LockCommand < GojiConstants
  COMMAND_LOCK = 'lock'
  COMMAND_UNLOCK = 'unlock'
end

class CommandResult < GojiConstants
  SUCCESS = 'success'
  INVALID_KEY = 'invalid_key'
  OUTSIDE_TIME_DAY = 'outside_time_day'
  USE_EXCEEDED = 'use_exceeded'
  EXPIRED = 'expired'
  HARDWARE_FAILURE = 'hardware_failure'
end

class GojiWifiSecurity < GojiConstants
  OPEN = 'open'
  WEP = 'wep'
  WPA_PERSONAL = 'wpa'
end

class LockCommState < GojiConstants
  LOCK_COMM_DOWN = 'down'
  LOCK_COMM_UP = 'up'
end

class PowerState < GojiConstants
  PWR_STATE_UNKNOWN = 'unknown'
  PWR_STATE_OFF = 'off'
  PWR_STATE_SLEEP = 'sleep'
  PWR_STATE_AWAKE = 'awake'
end

class ErrorEventCode < GojiConstants
  ERR_EV_CODE_UNDEFINED = 0
  ERR_EV_CODE_LOCK_REJECT_CREDENTIAL = 1
  ERR_EV_CODE_INTERNAL_OTA_FAILURE = 2
  ERR_EV_CODE_EXTERNAL_OTA_FAILURE = 3
end

class StringLength < GojiConstants
  STRLIM_GENERAL = '47'
  STRLIM_OTA_URL = '79'
  STRLIM_WIFI_SSID = '31'
  STRLIM_WIFI_PASSWORD = '62'
  RSA_KEY_SIZE = '1024'
  RSA_SIGN_DIGEST = 'SHA1'
  RSA_CRYPTO_PADDING = 'PKCS1v1.5'
  STRLIM_DB = '255'
end

class GojiCryptoParam < StringLength
end
