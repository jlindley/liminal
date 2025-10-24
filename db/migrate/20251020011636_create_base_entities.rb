class CreateBaseEntities < ActiveRecord::Migration[8.0]
  def change
    create_table :base_entities do |t|
      t.string :entity_id, null: false, index: { unique: true }
      t.string :entity_type, null: false
      t.string :name, null: false
      t.jsonb :core_data, null: false, default: {}
      t.jsonb :conditional_fragments, null: false, default: []
      t.jsonb :visibility_rules, null: false, default: {}

      t.timestamps
    end

    add_index :base_entities, :entity_type
  end
end
