require "test_helper"

class CampaignsControllerTest < ActionDispatch::IntegrationTest
  def setup
    Overlay.create!([
      { overlay_id: "recently-bubbled", name: "Recently Bubbled", overlay_type: "major", mutually_exclusive_with: ["100-years-bubbled"] },
      { overlay_id: "elemental-maelstorm", name: "Elemental Maelstorm", overlay_type: "flavor", mutually_exclusive_with: [] }
    ])
  end

  test "lists all campaigns" do
    Campaign.create!(name: "Test Campaign", active_overlays: [])

    get "/campaigns"
    assert_response :success
    assert_select "body", /Test Campaign/
  end

  test "shows campaign creation form" do
    get "/campaigns/new"
    assert_response :success
    assert_select "body", /New Campaign/
  end

  test "creates a campaign with selected overlays" do
    assert_difference "Campaign.count", 1 do
      post "/campaigns", params: {
        campaign: {
          name: "My Campaign",
          active_overlays: ["recently-bubbled", "elemental-maelstorm"]
        }
      }
    end

    campaign = Campaign.last
    assert_equal "My Campaign", campaign.name
    assert_equal ["elemental-maelstorm", "recently-bubbled"], campaign.active_overlays.sort
  end

  test "rejects mutually exclusive overlays" do
    post "/campaigns", params: {
      campaign: {
        name: "Bad Campaign",
        active_overlays: ["recently-bubbled", "100-years-bubbled"]
      }
    }
    assert_response :unprocessable_entity
  end

  test "shows campaign with overlays and entities" do
    campaign = Campaign.create!(name: "Test Campaign", active_overlays: ["recently-bubbled"])
    BaseEntity.create!(entity_id: "test-npc", name: "Test NPC", entity_type: "npc", core_data: {})

    get "/campaigns/#{campaign.id}"
    assert_response :success
    assert_select "body", /Test Campaign/
    assert_select "body", /Recently Bubbled/
    assert_select "body", /Test NPC/
  end
end
