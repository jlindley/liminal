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

  def self.import_overlays(file_path)
    unless File.exist?(file_path)
      Rails.logger.error "TomlImporter: Overlays file not found: #{file_path}"
      raise ArgumentError, "Overlays TOML file not found: #{file_path}"
    end

    Rails.logger.debug "TomlImporter: Loading overlays file #{file_path}"
    data = TomlRB.load_file(file_path)

    unless data["overlay"].present?
      Rails.logger.error "TomlImporter: Missing 'overlay' array in #{file_path}"
      raise ArgumentError, "TOML file missing required field: overlay"
    end

    Rails.logger.debug "TomlImporter: Found #{data["overlay"].length} overlays to import"

    data["overlay"].each do |overlay_data|
      overlay_id = overlay_data["overlay_id"]
      unless overlay_id.present?
        Rails.logger.error "TomlImporter: Missing overlay_id in one of the overlays"
        raise ArgumentError, "Overlay missing required field: overlay_id"
      end

      Rails.logger.debug "TomlImporter: Importing overlay_id=#{overlay_id}"

      Overlay.find_or_initialize_by(overlay_id: overlay_id).tap do |overlay|
        overlay.name = overlay_data["name"]
        overlay.overlay_type = overlay_data["overlay_type"]
        overlay.mutually_exclusive_with = overlay_data["mutually_exclusive_with"] || []
        overlay.save!
        Rails.logger.debug "TomlImporter: Successfully imported overlay_id=#{overlay_id}"
      end
    end

    Rails.logger.debug "TomlImporter: Successfully imported all overlays from #{file_path}"
  rescue TomlRB::ParseError => e
    Rails.logger.error "TomlImporter: Failed to parse overlays TOML file #{file_path}: #{e.message}"
    raise
  end
end
