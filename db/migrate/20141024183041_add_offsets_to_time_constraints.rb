class AddOffsetsToTimeConstraints < ActiveRecord::Migration

  # These will store signed minutes since start of day in UTC time
  def change
    add_column :time_constraints, :start_offset, :integer
    add_column :time_constraints, :end_offset, :integer
  end
end