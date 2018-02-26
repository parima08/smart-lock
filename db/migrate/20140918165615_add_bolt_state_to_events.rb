class AddBoltStateToEvents < ActiveRecord::Migration
  def change
    add_column :events, :bolt_state, :string
  end
end