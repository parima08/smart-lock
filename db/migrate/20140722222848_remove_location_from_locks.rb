# originally location refered to the device orienation and a deprecated version of lock.name
# Lock.location has been removed and is replaced with Lock.orientation

class RemoveLocationFromLocks < ActiveRecord::Migration
  def change
    remove_column :locks, :location, :string
  end
end
