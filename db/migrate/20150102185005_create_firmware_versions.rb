class CreateFirmwareVersions < ActiveRecord::Migration
  def change
    create_table :firmware_versions do |t|
      t.string :default_required_external_version
      t.string :default_required_internal_version

      t.timestamps
    end
  end
end
