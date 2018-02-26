class AddFirmwareTable < ActiveRecord::Migration
  def change
    create_table :firmwares do |t|
      t.string   "version"        # version string, for locks table
      t.string   "description"
      t.boolean  "for_external"    # for external board, else internal
      t.string   "download_url"    # generated
      t.string   "data_file_name"  # firmware image
      t.string   "data_content_type"
      t.integer  "data_file_size"
      t.datetime "data_updated_at"

      t.timestamps
    end

    add_index :firmwares, ["version", "for_external"], name: "index_firmwares", using: :btree, unique: true
  end
end
