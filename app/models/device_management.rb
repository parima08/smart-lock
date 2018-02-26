class DeviceManagement < Device  
  if defined? rails_admin
  rails_admin do
    visible false
    list do
    field :id do
      column_width 60
    end
    field :device_type do
      column_width 100
    end
    field :user_devices do
      label "Users"
      pretty_value do 
        bindings[:object].format_user_devices
      end
      searchable ["user_devices.name", "user_devices.email"]
    end
    field :ua_token do
      label "Push Token"
      column_width 100
    end
    field :endpoint_disabled_at do
      label "Endpoint Disabled"
      column_width 100
    end
    #last access... 
    end
    show do
      field :device_type
      field :ua_token do
        label "Push Token"
      end
      field :user_devices do
        label "Users"
        pretty_value do 
          bindings[:object].format_user_devices("show")
        end
      end    
      field :endpoint_arn do
        label "Amazon SNS id"
      end
      field :endpoint_disabled_at do
        label "Endpoint Disabled"
      end
      field :id
      field :os_version
      field :app_version
      field :device_model
      field :created_at
      field :updated_at
    end
    edit do
      field :device_type
      field :ua_token do
        label "Push Token"
      end
      field :endpoint_arn do
        label "Amazon SNS id"
      end
      field :endpoint_disabled_at do
        label "Endpoint Disabled"
      end
      field :os_version
      field :app_version
      field :device_model
    end
  end
  end
end
