class DropKeyDisplayName < ActiveRecord::Migration
  def change
    remove_column :keys, :display_name
  end
end
