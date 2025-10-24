class AddUniqueIndexToBaseEntitiesReplaces < ActiveRecord::Migration[8.0]
  def change
    add_index :base_entities, :replaces, unique: true, where: "replaces IS NOT NULL"
  end
end
