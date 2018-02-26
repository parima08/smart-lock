class RenameStatusToBoltState < ActiveRecord::Migration
  def change
    rename_column :locks, :status, :bolt_state
  end
end