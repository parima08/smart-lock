class Uncommission < ActiveRecord::Migration
  def change
    add_column :locks, :decommission_date, :datetime
  end
end
