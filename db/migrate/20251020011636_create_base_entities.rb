class CreateBaseEntities < ActiveRecord::Migration[8.0]
  def change
    create_table :base_entities do |t|
      t.string :entity_type
      t.string :entity_id
      t.string :name
      t.jsonb :core_data
      t.jsonb :conditional_fragments
      t.jsonb :visibility_rules

      t.timestamps
    end
  end
end
