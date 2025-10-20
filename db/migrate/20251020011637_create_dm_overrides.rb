class CreateDmOverrides < ActiveRecord::Migration[8.0]
  def change
    create_table :dm_overrides do |t|
      t.references :campaign, null: false, foreign_key: true
      t.references :base_entity, null: false, foreign_key: true
      t.string :override_type
      t.jsonb :override_data

      t.timestamps
    end
  end
end
