class AddTimeZoneToLocks < ActiveRecord::Migration
  def change
    add_column :locks, :time_zone, :string
  end
end
