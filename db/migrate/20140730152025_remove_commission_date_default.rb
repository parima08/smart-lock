class RemoveCommissionDateDefault < ActiveRecord::Migration
  def change
    change_column_default :locks, :commission_date, nil
  end
end
