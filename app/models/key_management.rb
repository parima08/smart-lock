# This class exists purely to present defeatured Key access in RailsAdmin.
class KeyManagement < Key

  if defined? rails_admin
    rails_admin do
      # Hide this from under Keys in model list.
      # This disables all actions on the list screen!
      # So we have to add them back in rails_admin.rb (Oddly)
      # XXX Also breaks breadcrubmbs below the list screen.
      visible false

      # Clone of key.rb (not inherited!), and strongly defeatured, we
      # will add stuff back as it's proven needed by customer support or
      # other 3rd party users.
      list do
        field :id
        field :name
        field :lock do
          sortable :name
          searchable "locks.name"
        end
        # See lock.rb
        field :user do
          label "Key owner"
          sortable false
          searchable false
        end
        field :user_account do
          visible false
          label "Key owner name/email"
          searchable ["user_accounts.email", "user_accounts.full_name"]
        end
        field :time_constraints
        field :created_at
        field :revoked do
          visible false
          searchable true
        end
        field :end_date do
          label "Expires"
          visible false
          searchable true
        end
      end
      show do # basic info screen
        field :name
        field :lock
        field :user do
          label "Key owner"
        end
        field :sharer
        field :time_constraints
        field :start_date
        field :end_date
        field :auto_unlock
        field :pending
        field :revoked
        field :events
        field :created_at
        field :id
      end
    end
  end
end
