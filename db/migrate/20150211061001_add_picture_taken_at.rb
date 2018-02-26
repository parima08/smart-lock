class AddPictureTakenAt < ActiveRecord::Migration
  def change
    add_column :pictures, :taken_at, :datetime
    add_column :pictures, :lock_id, :integer, index: false, foreign_key: { deferrable: :initially_deferred }
    add_index  :pictures, ["taken_at", "lock_id"], name: "index_pictures_on_taken_at", using: :btree, unique: true
  end
end
