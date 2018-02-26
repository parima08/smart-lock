# This class exists purely to present defeatured Lock access in RailsAdmin.
# Soon it will be converted to a view to add features.
class LockManagement < Lock
  if defined? rails_admin
    rails_admin do
      # Hide this from under Locks in model list.
      # This disables all actions on the list screen!
      # So we have to add them back in rails_admin.rb (Oddly)
      # XXX Also breaks breadcrubmbs below the list screen.
      visible false

      # Clone of lock.rb (not inherited!), and strongly defeatured, we
      # will add stuff back as it's proven needed by customer support or
      # other 3rd party users.
      list do
        field :id
        field :name do
          formatted_value do
            bindings[:object].display_name
          end
        end
        field :user do
          label "Owner"
          sortable false
          searchable false
          column_width 100
        end
        field :user_account do
          visible false
          label "Owner name/email"
          searchable ["user_accounts.email", "user_accounts.full_name"]
        end
        field :bolt_state do 
          column_width 50
          formatted_value do 
            bindings[:object].format_bolt_state
          end
        end
        field :reported_wifi_status do
          label "Wifi Status"
          column_width 55
          formatted_value do 
            bindings[:object].format_wifi_status
          end
        end
        field :wifi_downtime do
          label "% Wifi down"
          column_width 50
          formatted_value do
            bindings[:object].wifi_downtime
          end
        end
        field :last_sync_time do
          label "Last Sync"
          column_width 70
          formatted_value do
            bindings[:object].format_sync_time
          end
        end
        field :commission_date do
          visible false
          searchable true
        end
        field :decommission_date do
          visible false
          searchable true
        end
        # No battery level from lock yet.
        field :battery_state do 
          column_width 50
          formatted_value do
            bindings[:object].format_battery_state
          end
        end
        field :error_count do 
          column_width 50
          formatted_value do
            bindings[:object].error_count("list")
          end
        end
        field :internal_version do
          formatted_value do 
            bindings[:object].format_software_version(:internal_version)
          end
        end
        field :external_version do
          formatted_value do
            bindings[:object].format_software_version(:external_version)
          end
        end
        #field :keys
        field :created_at
      end
      show do
        field :name do
          formatted_value do
            bindings[:object].display_name
          end
        end
        field :user do
          label "Owner"
        end
        field :administrators
        field :keys
        field :bolt_state
        field :battery_level
        field :battery_state
        field :commission_date
        field :decommission_date
        field :lock_serial
        field :bluetooth_address
        field :auto_unlock_owner
        field :auto_unlock_others
        field :orientation
        field :required_internal_version
        field :internal_version
        field :required_external_version
        field :external_version
        field :internal_hw_version
        field :external_hw_version
        field :reported_wifi_status
        field :reported_wifi_time
        field :last_sync
        field :new_credentials
        field :error_count do 
          pretty_value do
            bindings[:object].error_count("show")
          end
        end
        field :reboot do
          label "Reboot requested"
        end
        field :debug_log do
          label "Log requested"
        end
        field :events
        field :id
        field :created_at
      end
      edit do
        field :name do
          read_only true
          help ''
        end
        field :user do
          label "Owner"
          read_only true
          help ''
        end
        field :required_internal_version, :enum do
          enum do
            FirmwareVersions.firmware_version_dropdown(true)
          end
          help 'Select a version to upgrade the lock'
        end
        field :internal_version do
          label "Current internal firmware version"
          read_only true
          help ''
        end
        field :required_external_version, :enum do
          enum do
            FirmwareVersions.firmware_version_dropdown(true)
          end
          help 'Select a version to upgrade the lock'
        end
        field :external_version do
          label "Current external firmware version"
          read_only true
          help ''
        end
        field :internal_hw_version do
          read_only true
          help ''
        end
        field :external_hw_version do
          read_only true
          help ''
        end
        field :reboot do
          label "Request reboot"
        end
        field :debug_log do
          label "Request log"
        end
      end
    end
  end
end
