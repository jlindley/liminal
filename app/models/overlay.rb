class Overlay < ApplicationRecord
  validates :overlay_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :overlay_type, presence: true, inclusion: { in: %w[major flavor] }
end
