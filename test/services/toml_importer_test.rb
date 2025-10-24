require "test_helper"

class TomlImporterTest < ActiveSupport::TestCase
  def setup
    @fixture_path = Rails.root.join("playkits/bubble/entities/npcs/npc-bran.toml")
  end

  test "creates BaseEntity from TOML file" do
    assert_difference "BaseEntity.count", 1 do
      TomlImporter.import_file(@fixture_path)
    end

    entity = BaseEntity.find_by(entity_id: "npc-bran")
    assert_equal "Bran", entity.name
    assert_equal "npc", entity.entity_type
    assert_equal "Bartender", entity.core_data["role"]
    assert_equal 10, entity.core_data["stats"]["ac"]
  end

  test "imports conditional_fragments" do
    TomlImporter.import_file(@fixture_path)
    entity = BaseEntity.find_by(entity_id: "npc-bran")

    assert_equal 2, entity.conditional_fragments.length

    recent_fragment = entity.conditional_fragments.find { |f| f["required_overlays"] == ["recently-bubbled"] }
    assert_equal "Skeptical of outsiders", recent_fragment["data"]["personality"]

    elemental_fragment = entity.conditional_fragments.find { |f| f["required_overlays"] == ["elemental-maelstorm"] }
    assert_equal ["recover-roof-materials"], elemental_fragment["data"]["quest_hooks"]
  end

  test "imports visibility_rules" do
    TomlImporter.import_file(@fixture_path)
    entity = BaseEntity.find_by(entity_id: "npc-bran")

    assert_equal "public_when_discovered", entity.visibility_rules["name"]
    assert_equal "dm_only", entity.visibility_rules["stats"]
  end

  test "updates existing entity on re-import" do
    TomlImporter.import_file(@fixture_path)

    assert_no_difference "BaseEntity.count" do
      TomlImporter.import_file(@fixture_path)
    end
  end
end
