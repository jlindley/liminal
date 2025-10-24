require "test_helper"

class CampaignTest < ActiveSupport::TestCase
  def setup
    Overlay.create!([
      { overlay_id: "recently-bubbled", name: "Recently Bubbled", overlay_type: "major", mutually_exclusive_with: ["100-years-bubbled"] },
      { overlay_id: "100-years-bubbled", name: "100 Years Bubbled", overlay_type: "major", mutually_exclusive_with: ["recently-bubbled"] },
      { overlay_id: "elemental-maelstorm", name: "Elemental Maelstorm", overlay_type: "flavor", mutually_exclusive_with: [] }
    ])
  end

  test "requires name" do
    campaign = Campaign.new(active_overlays: [])
    assert_not campaign.valid?
    assert_includes campaign.errors[:name], "can't be blank"
  end

  test "validates mutually exclusive overlays" do
    campaign = Campaign.new(
      name: "Test Campaign",
      active_overlays: ["recently-bubbled", "100-years-bubbled"]
    )
    assert_not campaign.valid?
    assert_match /mutually exclusive/, campaign.errors[:active_overlays].first
  end

  test "allows non-conflicting overlays" do
    campaign = Campaign.new(
      name: "Test Campaign",
      active_overlays: ["recently-bubbled", "elemental-maelstorm"]
    )
    assert campaign.valid?
  end

  test "allows empty active_overlays" do
    campaign = Campaign.new(name: "Test Campaign", active_overlays: [])
    assert campaign.valid?
  end
end
