class FixUaToken < ActiveRecord::Migration
  def change
  	rename_column :devices, :apn_token, :ua_token
  end
end
