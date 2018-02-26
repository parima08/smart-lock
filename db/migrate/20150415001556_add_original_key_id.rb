class AddOriginalKeyId < ActiveRecord::Migration
  def change
    add_column :keys, :original_key_id, :integer, index: false, foreign_key: { deferrable: :initially_deferred, references: :keys }
    remove_column :keys, :identifier, :integer
  end
end

