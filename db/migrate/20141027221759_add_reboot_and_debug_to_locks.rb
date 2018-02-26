class AddRebootAndDebugToLocks < ActiveRecord::Migration
  def change
    add_column :locks, :reboot, :boolean, default: false
    add_column :locks, :debug_log, :boolean, default: false
  end
end
