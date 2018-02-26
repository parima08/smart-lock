class AddPasswordEntropyPercentToAccounts < ActiveRecord::Migration
  def change
    add_column :accounts, :password_entropy_percent, :float
    add_column :accounts, :set_password_from, :boolean, default: true
  end
end
