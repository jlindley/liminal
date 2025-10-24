require "test_helper"

class EntityResolverTest < ActiveSupport::TestCase
  def setup
    # Create overlays needed for testing
    Overlay.create!([
      { overlay_id: "recently-bubbled", name: "Recently Bubbled", overlay_type: "major", mutually_exclusive_with: ["100-years-bubbled"] },
      { overlay_id: "100-years-bubbled", name: "100 Years Bubbled", overlay_type: "major", mutually_exclusive_with: ["recently-bubbled"] },
      { overlay_id: "elemental-maelstorm", name: "Elemental Maelstorm", overlay_type: "flavor", mutually_exclusive_with: [] }
    ])

    @bran = BaseEntity.create!(
      entity_id: "npc-bran",
      entity_type: "npc",
      name: "Bran",
      core_data: {
        "name" => "Bran",
        "role" => "Bartender",
        "description" => "A weathered bartender with kind eyes"
      },
      conditional_fragments: [
        {
          "required_overlays" => ["recently-bubbled"],
          "data" => {
            "personality" => "Skeptical of outsiders",
            "items" => ["magical-mace"]
          }
        },
        {
          "required_overlays" => ["elemental-maelstorm"],
          "data" => {
            "description" => "A weathered bartender with kind eyes and a burn scar on his left cheek",
            "quest_hooks" => ["recover-roof-materials"]
          }
        }
      ]
    )
  end

  test "returns only core_data with no active overlays" do
    campaign = Campaign.create!(name: "Test", active_overlays: [])
    result = EntityResolver.resolve(entity_id: "npc-bran", campaign: campaign)

    assert_equal "Bran", result["name"]
    assert_equal "Bartender", result["role"]
    assert_equal "A weathered bartender with kind eyes", result["description"]
    assert_nil result["personality"]
    assert_nil result["quest_hooks"]
  end

  test "merges matching conditional fragments with one overlay" do
    campaign = Campaign.create!(name: "Test", active_overlays: ["recently-bubbled"])
    result = EntityResolver.resolve(entity_id: "npc-bran", campaign: campaign)

    assert_equal "Bran", result["name"]
    assert_equal "Skeptical of outsiders", result["personality"]
    assert_equal ["magical-mace"], result["items"]
    assert_nil result["quest_hooks"]
  end

  test "merges all matching fragments with multiple overlays" do
    campaign = Campaign.create!(name: "Test", active_overlays: ["recently-bubbled", "elemental-maelstorm"])
    result = EntityResolver.resolve(entity_id: "npc-bran", campaign: campaign)

    assert_equal "Bran", result["name"]
    assert_equal "Skeptical of outsiders", result["personality"]
    assert_equal ["magical-mace"], result["items"]
    assert_equal "A weathered bartender with kind eyes and a burn scar on his left cheek", result["description"]
    assert_equal ["recover-roof-materials"], result["quest_hooks"]
  end

  test "does not merge non-matching fragments" do
    campaign = Campaign.create!(name: "Test", active_overlays: ["100-years-bubbled"])
    result = EntityResolver.resolve(entity_id: "npc-bran", campaign: campaign)

    assert_equal "Bran", result["name"]
    assert_nil result["personality"]
    assert_nil result["items"]
  end

  test "returns nil for missing entity" do
    campaign = Campaign.create!(name: "Test", active_overlays: [])
    result = EntityResolver.resolve(entity_id: "npc-missing", campaign: campaign)
    assert_nil result
  end
end
