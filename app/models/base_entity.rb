class BaseEntity < ApplicationRecord
  validates :entity_id, presence: true, uniqueness: true
  validates :entity_type, presence: true
  validates :name, presence: true
end
