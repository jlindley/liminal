class AddReplacementFieldsToBaseEntities < ActiveRecord::Migration[8.0]
  def change
    add_column :base_entities, :replaces, :string
    add_column :base_entities, :show_when, :jsonb, default: []
  end
end
