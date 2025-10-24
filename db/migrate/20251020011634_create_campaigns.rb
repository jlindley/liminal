class CreateCampaigns < ActiveRecord::Migration[8.0]
  def change
    create_table :campaigns do |t|
      t.string :name, null: false
      t.jsonb :active_overlays, null: false, default: []

      t.timestamps
    end
  end
end
