class AddStatusSyncFieldsToLocks < ActiveRecord::Migration
  def change
    add_column :locks, :internal_version, :string
    add_column :locks, :external_version, :string
    add_column :locks, :required_internal_version, :string
    add_column :locks, :required_external_version, :string
    add_column :locks, :battery_level, :integer
    add_column :locks, :battery_state, :string
  end
end
