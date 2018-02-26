class CreateLogs < ActiveRecord::Migration
  def change
    create_table :logs do |t|
      t.string     "source"       # "device", "lock" (default if null)
      t.references :lock, index: true, foreign_key: false
      t.references :device, index: true, foreign_key: false
      t.datetime   "fault_time", null: false # when error occured
      t.string     "fault_type"              # an ID of some kind, if there was a fault triggering the log
      t.references :log_data, foreign_key: false

      t.timestamps
    end
  end
end
