class CreateCampaigns < ActiveRecord::Migration[8.0]
  def change
    create_table :campaigns do |t|
      t.string :name
      t.string :play_kit_id
      t.jsonb :active_overlays

      t.timestamps
    end
  end
end
