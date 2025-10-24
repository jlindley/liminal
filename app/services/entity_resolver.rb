class EntityResolver
  def self.resolve(entity_id:, campaign:)
    Rails.logger.debug "EntityResolver: Starting resolution for entity_id=#{entity_id}, campaign=#{campaign.name} (id=#{campaign.id})"
    Rails.logger.debug "EntityResolver: Active overlays: #{campaign.active_overlays.inspect}"

    entity = BaseEntity.find_by(entity_id: entity_id)
    unless entity
      Rails.logger.debug "EntityResolver: Entity not found for entity_id=#{entity_id}"
      return nil
    end

    Rails.logger.debug "EntityResolver: Found entity: name=#{entity.name}, type=#{entity.entity_type}"

    # Start with core_data
    resolved = entity.core_data.deep_dup
    Rails.logger.debug "EntityResolver: Starting with core_data: #{resolved.keys.inspect}"

    # Merge matching conditional fragments
    matched_count = 0
    entity.conditional_fragments.each_with_index do |fragment, idx|
      required = fragment["required_overlays"] || []

      if required.any? && required.all? { |overlay| campaign.active_overlays.include?(overlay) }
        Rails.logger.debug "EntityResolver: Fragment #{idx} matched: required=#{required.inspect}, data_keys=#{fragment["data"]&.keys.inspect}"
        resolved.deep_merge!(fragment["data"] || {})
        matched_count += 1
      else
        reason = required.empty? ? "empty required_overlays" : "not all overlays active"
        Rails.logger.debug "EntityResolver: Fragment #{idx} skipped: required=#{required.inspect} (#{reason})"
      end
    end

    Rails.logger.debug "EntityResolver: Matched #{matched_count} fragments out of #{entity.conditional_fragments.length}"
    Rails.logger.debug "EntityResolver: Resolution complete. Final data keys: #{resolved.keys.inspect}"

    resolved
  end
end
