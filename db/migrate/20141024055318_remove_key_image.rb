class RemoveKeyImage < ActiveRecord::Migration
  def change
    remove_column :keys, :image_content_type
    remove_column :keys, :image_file_name
    remove_column :keys, :image_file_size
    remove_column :keys, :image_updated_at
  end
end
