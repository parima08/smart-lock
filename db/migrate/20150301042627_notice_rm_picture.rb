class NoticeRmPicture < ActiveRecord::Migration
  def change
    remove_column :notifications,  :picture_id, :integer
  end
end
