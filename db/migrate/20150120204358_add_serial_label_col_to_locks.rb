class AddSerialLabelColToLocks < ActiveRecord::Migration
  def change
    add_column :locks, :serial_label, :string
  end

end