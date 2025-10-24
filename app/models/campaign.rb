class Campaign < ApplicationRecord
  has_many :dm_overrides

  validates :name, presence: true
  validate :validate_mutually_exclusive_overlays

  private

  def validate_mutually_exclusive_overlays
    return if active_overlays.blank?

    active_overlays.each do |overlay_id|
      overlay = Overlay.find_by(overlay_id: overlay_id)
      next unless overlay

      conflicts = overlay.mutually_exclusive_with & active_overlays
      if conflicts.any?
        errors.add(:active_overlays, "#{overlay_id} is mutually exclusive with #{conflicts.join(', ')}")
      end
    end
  end

  public

  # Resolve an entity for this campaign given active overlays and DM customizations
  def resolve_entity(entity_id, viewer_role: :dm)
    base = BaseEntity.find_by(entity_id: entity_id)
    return nil unless base

    # Check if DM has completely replaced this entity
    replacement = dm_overrides.find_by(base_entity_id: base.id, override_type: 'replace')
    if replacement
      # Return replacement entity if exists
      return build_resolved_entity(replacement.override_data, viewer_role)
    end

    # Check if DM disabled this entity
    disabled = dm_overrides.find_by(base_entity_id: base.id, override_type: 'disable')
    return nil if disabled

    # Start with core data
    resolved_data = base.core_data.deep_dup

    # Add conditional fragments that match active overlays
    if base.conditional_fragments.present?
      base.conditional_fragments.each do |fragment|
        required = fragment['required_overlays'] || []
        if required.all? { |overlay| (active_overlays || []).include?(overlay) }
          resolved_data.deep_merge!(fragment['data'] || {})
        end
      end
    end

    # Apply DM edits
    edit = dm_overrides.find_by(base_entity_id: base.id, override_type: 'edit')
    if edit
      resolved_data.deep_merge!(edit.override_data)
    end

    # Filter by visibility rules
    filter_by_visibility(resolved_data, base.visibility_rules, viewer_role)
  end

  private

  def build_resolved_entity(data, viewer_role)
    # For replacements, data contains full entity
    data
  end

  def filter_by_visibility(data, visibility_rules, viewer_role)
    return data if viewer_role == :dm

    filtered = {}
    visibility_rules ||= {}

    data.each do |key, value|
      rule = visibility_rules[key]
      case rule
      when 'public_when_discovered'
        # For now, assume discovered - real version would check discovery state
        filtered[key] = value
      when 'dm_controlled'
        # Skip - DM hasn't revealed this
      when 'dm_only'
        # Skip - never shown to players
      when nil
        # No rule specified - hide by default for safety
        # Could make this configurable per entity type
      end
    end
    filtered
  end
end
