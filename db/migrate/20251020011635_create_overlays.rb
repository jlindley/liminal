class CreateOverlays < ActiveRecord::Migration[8.0]
  def change
    create_table :overlays do |t|
      t.string :overlay_id
      t.string :name
      t.string :overlay_type
      t.jsonb :mutually_exclusive_with

      t.timestamps
    end
  end
end
