class EntityResolver
  def self.resolve(entity_id:, campaign:)
    entity = BaseEntity.find_by(entity_id: entity_id)
    return nil unless entity

    # Start with core_data
    resolved = entity.core_data.deep_dup

    # Merge matching conditional fragments
    entity.conditional_fragments.each do |fragment|
      required = fragment["required_overlays"] || []
      next unless required.all? { |overlay| campaign.active_overlays.include?(overlay) }

      resolved.deep_merge!(fragment["data"] || {})
    end

    resolved
  end
end
