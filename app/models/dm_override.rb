class DmOverride < ApplicationRecord
  belongs_to :campaign
  belongs_to :base_entity
end
