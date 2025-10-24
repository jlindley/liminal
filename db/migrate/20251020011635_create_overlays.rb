class CreateOverlays < ActiveRecord::Migration[8.0]
  def change
    create_table :overlays do |t|
      t.string :overlay_id, null: false, index: { unique: true }
      t.string :name, null: false
      t.string :overlay_type, null: false
      t.jsonb :mutually_exclusive_with, null: false, default: []

      t.timestamps
    end
  end
end
