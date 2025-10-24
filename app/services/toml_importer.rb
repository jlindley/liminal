require "toml-rb"

class TomlImporter
  def self.import_file(file_path)
    data = TomlRB.load_file(file_path)

    BaseEntity.find_or_initialize_by(entity_id: data["entity_id"]).tap do |entity|
      entity.entity_type = data["entity_type"]
      entity.name = data["name"]
      entity.core_data = data["core_data"] || {}
      entity.conditional_fragments = data["conditional_fragments"] || []
      entity.visibility_rules = data["visibility_rules"] || {}
      entity.save!
    end
  end
end
