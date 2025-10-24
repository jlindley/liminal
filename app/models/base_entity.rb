class BaseEntity < ApplicationRecord
  validates :entity_id, presence: true, uniqueness: true
  validates :entity_type, presence: true
  validates :name, presence: true

  validate :replaces_must_exist, if: -> { replaces.present? }
  validate :cannot_replace_self, if: -> { replaces.present? }

  private

  def replaces_must_exist
    unless BaseEntity.exists?(entity_id: replaces)
      errors.add(:replaces, "must reference an existing entity_id (#{replaces} not found)")
    end
  end

  def cannot_replace_self
    if replaces == entity_id
      errors.add(:replaces, "cannot replace itself")
    end
  end
end
