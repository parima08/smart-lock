# RailsAdmin config file. Generated on January 04, 2013 17:44
# See github.com/sferik/rails_admin for more informations

require Rails.root.join('lib', 'decommission.rb')

if GojiServer::Application.config.admin == "rails"

require "rails_admin/application_controller"
require Rails.root.join('lib', 'rails_admin_view_logs.rb')
# TBD: Finish the task to be able to set start date for
# error count and % wifi downtime
# require Rails.root.join('lib', 'rails_admin_set_start_date.rb')

module RailsAdmin
  class ApplicationController < ::ApplicationController
    force_ssl if: lambda {GojiServer.config.use_ssl_if_possible}
  end
end

RailsAdmin.config do |config|

  ################  Global configuration  ################

  # Set the admin name here (optional second array element will appear in red). For example:
  # A bit clunky, but make it so we can show the server name and git_sha
  instance_name = (ENV['MAILER_URL'] ? ENV['MAILER_URL'].sub('goji-server-','').sub('.herokuapp.com','') : '')
  git_sha = File.read(Rails.root.join('.source_version')).slice(0..6) rescue ENV['GIT_SHA'] || ''
  config.main_app_name = ['Goji Server', instance_name + ' - ' + git_sha]
  # or for a more dynamic name:
  # config.main_app_name = Proc.new { |controller| [Rails.application.engine_name.titleize, controller.params['action'].titleize] }

  config.authenticate_with do
    authenticate_account!
    ensure_admin_account
  end

  # Global settings visible in both rendered JavaScript and controllers.
  config.registry["app_globals"] = {
    password: { 
      entropy: {
        medium: 30,
        good: 40,
        max: 70,
      }
    }
  }

  # XXX Could hack the RailsAdmin application_helper.rb to make these
  # not open a new tab.
  config.navigation_static_links = {
    'Sysadmin Users' => '/admin/sysadmin_users?f%5Badmin%5D%5B81226%5D%5Bv%5D=true',
    'Lock Management' => '/admin/lock_management?f%5Bcommission_date%5D%5B40314%5D%5Bo%5D=_not_null&f%5Bcommission_date%5D%5B40314%5D%5Bv%5D%5B%5D=&f%5Bcommission_date%5D%5B40314%5D%5Bv%5D%5B%5D=&f%5Bcommission_date%5D%5B40314%5D%5Bv%5D%5B%5D=&f%5Bdecommission_date%5D%5B40360%5D%5Bo%5D=_null&f%5Bdecommission_date%5D%5B40360%5D%5Bv%5D%5B%5D=&f%5Bdecommission_date%5D%5B40360%5D%5Bv%5D%5B%5D=&f%5Bdecommission_date%5D%5B40360%5D%5Bv%5D%5B%5D=',
    # LP18818003: Need "before now" date filter to filter out expired keys.
    # Rails Admin filter rules are not extensible.  It should allow
    # defining a searchable, not visible field based on a model method
    # rather than building an SQL query, even though it's inefficient.
    # So solve with a db view.
    'Key Management' => '/admin/key_management?f%5Brevoked%5D%5B83591%5D%5Bo%5D=_null&f%5Brevoked%5D%5B83591%5D%5Bv%5D%5B%5D=&f%5Brevoked%5D%5B83591%5D%5Bv%5D%5B%5D=&f%5Brevoked%5D%5B83591%5D%5Bv%5D%5B%5D=',
    'Device Management' => '/admin/device_management',
  }

  # RailsAdmin may need a way to know who the current user is]
  config.current_user_method { current_account } # auto-generated

  # If you want to track changes on your models:
  config.audit_with :history, 'Key'
  config.audit_with :history, 'Account'
  config.audit_with :history, 'Device'
  config.audit_with :history, 'Event'
  config.audit_with :history, 'Firmware'
  config.audit_with :history, 'Lock'
  config.audit_with :history, 'LocksUser'
  config.audit_with :history, 'LogData'
  config.audit_with :history, 'Log'
  config.audit_with :history, 'Notification'
  config.audit_with :history, 'Picture'
  config.audit_with :history, 'TimeConstraint'
  config.audit_with :history, 'User'

  # Or with a PaperTrail: (you need to install it first)
  # config.audit_with :paper_trail, 'Account'

  # Display empty fields in show views:
  config.compact_show_view = false

  # Number of default rows per-page:
  config.default_items_per_page = 30

  # Exclude specific models (keep the others):
  # Totally excludes generation of the view, not just removing from navigation.
  # config.excluded_models = ['LockManagement']

  # Include specific models (exclude the others):
  # config.included_models = ['Account', 'Key', 'Lock', 'Notification', 'NotificationTemplate', 'User']

  # Label methods for model instances:
  # Default is [:name, :title]
  # Match Active Admin.
  config.label_methods = [ :display_name, :full_name, :name, :username, :login, :title, :email, :to_s ]


  def is_management(bindings)
    bindings[:abstract_model].model == SysadminUsers ||
    is_lock_management(bindings) || is_device_management(bindings)
  end
  def is_lock_key_management(bindings)
    is_key_management(bindings) ||
    is_lock_management(bindings) || 
    is_device_management(bindings)
  end
  def is_key_management(bindings)
    bindings[:abstract_model].model == KeyManagement
  end
  def is_lock_management(bindings)
    bindings[:abstract_model].model == LockManagement
  end
  def is_device_management(bindings)
    bindings[:abstract_model].model == DeviceManagement
  end

  config.actions do
    # Default except removing show_in_app which is useless.
    # root actions
    dashboard                     # mandatory
    # collection actions
    index do
      visible do
        !is_management(bindings)
      end
    end                        # mandatory
    collection(:index_management, :index) do
      visible do
        is_management(bindings)
      end
    end
    new do
      visible do
        !is_lock_key_management(bindings)
      end
    end
    # Oddly, these don't show up in is_management case if model is
    # marked not visible, without this hack:
    export do
      visible do
        true
      end
    end
    history_index do
      visible do
        true
      end
    end
    bulk_delete do
      visible do
        !is_lock_key_management(bindings)
      end
    end
    # member actions
    # Relabel show for Management actions
    show do
      visible do
        !is_lock_key_management(bindings)
      end
    end
    member(:show_management, :show) do
      visible do
        is_lock_key_management(bindings)
      end
    end
    edit do
      visible do
        !is_key_management(bindings)
      end
    end
    decommission do
      visible do
        is_lock_management(bindings) ||
        bindings[:abstract_model].model == Lock
      end
    end
    delete do
      visible do
        !is_lock_key_management(bindings)
      end
    end
    history_show do
      visible do
        true
      end
    end
    # TBD: Add custom action for start_date
    # start_date do
    #   visible do
    #     true
    #   end
    # end
    # member :view_logs do
    #   link_icon 'icon-eye-open'
    # end
    view_logs
  end

  ################  Model configuration  ################

  # Each model configuration can alternatively:
  #   - stay here in a `config.model 'ModelName' do ... end` block
  #   - go in the model definition file in a `rails_admin do ... end` block

  # This is your choice to make:
  #   - This initializer is loaded once at startup (modifications will show up when restarting the application) but all RailsAdmin configuration would stay in one place.
  #   - Models are reloaded at each request in development mode (when modified), which may smooth your RailsAdmin development workflow.


  # Now you probably need to tour the wiki a bit: https://github.com/sferik/rails_admin/wiki
  # Anyway, here is how RailsAdmin saw your application's models when you ran the initializer:



  ###  Account  ###

  # config.model 'Account' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your account.rb model definition

  #   # Found associations:

  #     configure :user, :has_one_association

  #   # Found columns:

  #     configure :id, :integer
  #     configure :admin, :boolean
  #     configure :authentication_token, :string
  #     configure :email, :string
  #     configure :password, :password         # Hidden
  #     configure :password_confirmation, :password         # Hidden
  #     configure :reset_password_token, :string         # Hidden
  #     configure :reset_password_sent_at, :datetime
  #     configure :remember_created_at, :datetime
  #     configure :sign_in_count, :integer
  #     configure :current_sign_in_at, :datetime
  #     configure :last_sign_in_at, :datetime
  #     configure :current_sign_in_ip, :string
  #     configure :last_sign_in_ip, :string
  #     configure :first_name, :string
  #     configure :last_name, :string
  #     configure :full_name, :string
  #     configure :created_at, :datetime
  #     configure :updated_at, :datetime

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end


  ###  Key  ###

  # config.model 'Key' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your key.rb model definition

  #   # Found associations:

  #     configure :lock, :belongs_to_association
  #     configure :notifications, :has_many_association

  #   # Found columns:

  #     configure :id, :integer
  #     configure :lock_id, :integer         # Hidden
  #     configure :created_at, :datetime
  #     configure :updated_at, :datetime

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end


  ###  Lock  ###

  # config.model 'Lock' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your lock.rb model definition

  #   # Found associations:

  #     configure :user, :belongs_to_association
  #     configure :keys, :has_many_association
  #     configure :notifications, :has_many_association

  #   # Found columns:

  #     configure :id, :integer
  #     configure :user_id, :integer         # Hidden
  #     configure :name, :string
  #     configure :commission_date, :datetime
  #     configure :created_at, :datetime
  #     configure :updated_at, :datetime

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end


  ###  Notification  ###

  # config.model 'Notification' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your notification.rb model definition

  #   # Found associations:

  #     configure :lock, :belongs_to_association
  #     configure :key, :belongs_to_association

  #   # Found columns:

  #     configure :id, :integer
  #     configure :sender_id, :integer
  #     configure :recipient_id, :integer
  #     configure :lock_id, :integer         # Hidden
  #     configure :key_id, :integer         # Hidden
  #     configure :notification_template_id, :integer
  #     configure :read, :boolean
  #     configure :read_date, :datetime
  #     configure :created_at, :datetime
  #     configure :updated_at, :datetime

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end


  ###  NotificationTemplate  ###

  # config.model 'NotificationTemplate' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your notification_template.rb model definition

  #   # Found associations:

  #     configure :locks, :has_many_association
  #     configure :keys, :has_many_association
  #     configure :notifications, :has_many_association

  #   # Found columns:

  #     configure :id, :integer
  #     configure :code, :string
  #     configure :message, :string
  #     configure :description, :string

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end


  ###  User  ###

  # config.model 'User' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your user.rb model definition

  #   # Found associations:

  #     configure :account, :belongs_to_association
  #     configure :locks, :has_many_association
  #     configure :keys, :has_many_association
  #     configure :notifications, :has_many_association

  #   # Found columns:

  #     configure :id, :integer
  #     configure :account_id, :integer         # Hidden
  #     configure :email, :string
  #     configure :first_name, :string
  #     configure :last_name, :string
  #     configure :full_name, :string
  #     configure :created_at, :datetime
  #     configure :updated_at, :datetime

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end

end
end

class RailsAdmin::Config::Fields::Types::Uuid < RailsAdmin::Config::Fields::Base
  RailsAdmin::Config::Fields::Types::register(self)
end
