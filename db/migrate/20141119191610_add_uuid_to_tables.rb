class AddUuidToTables < ActiveRecord::Migration
  AFFECTED_TABLES = [:accounts, :devices, :events, :firmwares, 
            :keys, :locks, :log_data, :locks_users, :logs, 
            :notifications, :pictures, :time_constraints, :users]
  def change
    #enable_extension "uuid-ossp"
    AFFECTED_TABLES.each do |table| 
      add_column table, :uuid, :uuid
      #add_column table, :uuid, :uuid, default: "uuid_generate_v4()"
    end
  end
end
