# This class exists purely to present defeatured Key access in RailsAdmin.
class SysadminUsers < Account

  if defined? rails_admin
    rails_admin do
      # Hide this from model list.
      visible false

      # Clone of account.rb (not inherited!), and strongly defeatured, we
      # will add stuff back as it's proven needed by customer support or
      # other 3rd party users.
      list do
        field :id
        field :full_name
        field :email
        field :sign_in_count
        field :current_sign_in_at do
          label "Last Sysadmin Sign in"
        end
        field :admin do
          visible false
          label "Sysadmin"
          searchable true
        end
      end
      show do # hide lock-related fields
        field :full_name
        field :email
        field :sign_in_count
        field :current_sign_in_at do
          label "Last Sysadmin Sign in"
        end
        field :current_sign_in_ip do
          label "Last Sysadmin Sign in IP Address"
        end
        field :password_entropy_percent  do
          label "Password Score %"
        end
        field :set_password_from
        field :id
        field :created_at
        field :updated_at
      end
      edit do
        field :email
        field :first_name
        field :last_name
        field :password do
          help ''
        end
        field :password_confirmation do
          help ''
        end
        field :password_entropy_percent do
          # Can't make this read-only here, or new JS-set value won't be posted.  Set in JS.
          label "Password Score %"
          help ''
        end
        field :set_password_from do
          read_only true
          help ''
        end
      end
      create do
        # Hack to supply fixed values...
        field :admin do
          label "Sysadmin"
          formatted_value do
            value = true
          end
=begin
          # ...because all of these failed:
          def value do # errors
          end
          default_value do # does nothing, seemingly not called
            #value = true
            true
          end
          # Still fails if either :hidden or visible false
          visible false
=end
        end
        # For now, do not require email confirmation.
        # XXX This prefills the field but not the date picker, probably
        # will require a RA code change to fix.
        # Probably easier to go ahead and implement LP19110902.
        field :confirmed_at do
          label "Email confirmed at (prefilled, required, leave alone)"
          formatted_value do
            value = DateTime.now
          end
        end
      end
    end
  end
end
