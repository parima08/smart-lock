class Ota < ActiveRecord::Migration
  def change
    add_column :locks, :internal_hw_version, :string  # info only for alpha
    add_column :locks, :external_hw_version, :string  # info only for alpha
  end
end
