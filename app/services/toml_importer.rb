require "toml-rb"

class TomlImporter
  def self.import_file(file_path)
    unless File.exist?(file_path)
      Rails.logger.error "TomlImporter: File not found: #{file_path}"
      raise ArgumentError, "TOML file not found: #{file_path}"
    end

    Rails.logger.debug "TomlImporter: Loading file #{file_path}"
    data = TomlRB.load_file(file_path)

    entity_id = data["entity_id"]
    unless entity_id.present?
      Rails.logger.error "TomlImporter: Missing entity_id in #{file_path}"
      raise ArgumentError, "TOML file missing required field: entity_id"
    end

    Rails.logger.debug "TomlImporter: Importing entity_id=#{entity_id}"

    BaseEntity.find_or_initialize_by(entity_id: entity_id).tap do |entity|
      entity.entity_type = data["entity_type"]
      entity.name = data["name"]
      entity.core_data = data["core_data"] || {}
      entity.conditional_fragments = data["conditional_fragments"] || []
      entity.visibility_rules = data["visibility_rules"] || {}
      entity.save!
      Rails.logger.debug "TomlImporter: Successfully imported entity_id=#{entity_id}"
    end
  rescue TomlRB::ParseError => e
    Rails.logger.error "TomlImporter: Failed to parse TOML file #{file_path}: #{e.message}"
    raise
  end
end
