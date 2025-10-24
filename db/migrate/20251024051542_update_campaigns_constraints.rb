class UpdateCampaignsConstraints < ActiveRecord::Migration[8.0]
  def change
    # Remove play_kit_id column (not needed for this implementation)
    remove_column :campaigns, :play_kit_id, :string

    # Add constraints to existing columns
    change_column_null :campaigns, :name, false
    change_column_null :campaigns, :active_overlays, false
    change_column_default :campaigns, :active_overlays, from: nil, to: []
  end
end
