class UserAccountsView < ActiveRecord::Migration
  def up
    # The schema_plus way:
    # u.id as user_id because it's simpler to say a.*
    # Assuming we can't say a.* then overwrite with u.id...
    create_view :user_accounts, "SELECT
                u.time_zone,
                u.id as user_id,
                a.*
             FROM users u
             JOIN accounts a on (u.account_id = a.id)"
=begin
    self.connection.execute %Q( CREATE OR REPLACE VIEW user_accounts AS
          SELECT
                u.time_zone,
                u.id as user_id,
                a.*
             FROM users u
             JOIN accounts a on (u.account_id = a.id)
          )
=end
  end

  def down
    drop_view :user_accounts
=begin
    self.connection.execute "DROP VIEW IF EXISTS user_accounts;"
=end
  end
end
