require "test_helper"

class EntitiesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @bran = BaseEntity.create!(
      entity_id: "npc-bran",
      entity_type: "npc",
      name: "Bran",
      core_data: {
        "name" => "Bran",
        "role" => "Bartender",
        "description" => "A weathered bartender"
      },
      conditional_fragments: [
        {
          "required_overlays" => ["recently-bubbled"],
          "data" => { "personality" => "Skeptical of outsiders" }
        }
      ]
    )

    # Create the overlay that the campaign will reference
    Overlay.create!(
      overlay_id: "recently-bubbled",
      name: "Recently Bubbled",
      overlay_type: "major",
      mutually_exclusive_with: []
    )
  end

  test "displays resolved entity data based on campaign overlays" do
    campaign = Campaign.create!(name: "Test Campaign", active_overlays: ["recently-bubbled"])
    get "/campaigns/#{campaign.id}/entities/npc-bran"

    assert_response :success
    assert_select "body", /Bran/
    assert_select "body", /Skeptical of outsiders/
  end

  test "returns 404 for missing entity" do
    campaign = Campaign.create!(name: "Test Campaign", active_overlays: [])
    get "/campaigns/#{campaign.id}/entities/npc-missing"
    assert_response :not_found
  end

  test "returns 404 for missing campaign" do
    get "/campaigns/999999/entities/npc-bran"
    assert_response :not_found
    assert_match /Campaign not found/, response.body
  end
end
