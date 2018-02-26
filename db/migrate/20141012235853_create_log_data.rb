class CreateLogData < ActiveRecord::Migration
  def change
    create_table :log_data do |t|
      t.binary :data, null: false
      t.string :data_type        # "text", "binary" (default if null)

      t.timestamps
    end
  end
end
