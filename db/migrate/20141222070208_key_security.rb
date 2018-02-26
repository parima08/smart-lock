class KeySecurity < ActiveRecord::Migration
  def change
    add_column :locks, :new_credentials, :boolean, default: true
    add_column :keys, :replaced_at, :datetime
  end
end
