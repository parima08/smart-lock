class AddCommissioningFieldsToLocks < ActiveRecord::Migration
  def change
    add_column :locks, :orientation, :string
    add_column :locks, :auto_unlock_others , :boolean
    add_column :locks, :auto_unlock_owner, :boolean
  end
end
