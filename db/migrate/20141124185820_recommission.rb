class Recommission < ActiveRecord::Migration
  def change
    # Can't have this index: can have multiple lock_index records, e.g.
    # commissioning after an orphaned partial commission (commission_date = nil for both).
    # Otherwise, could add comissioned_date to index to allow recommissioning by another owner.
    remove_index :locks, :lock_serial
  end
end
