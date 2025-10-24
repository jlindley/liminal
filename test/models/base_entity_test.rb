require "test_helper"

class BaseEntityTest < ActiveSupport::TestCase
  test "requires entity_id" do
    entity = BaseEntity.new(entity_type: "npc", name: "Bran", core_data: {})
    assert_not entity.valid?
    assert_includes entity.errors[:entity_id], "can't be blank"
  end

  test "requires entity_type" do
    entity = BaseEntity.new(entity_id: "npc-bran", name: "Bran", core_data: {})
    assert_not entity.valid?
    assert_includes entity.errors[:entity_type], "can't be blank"
  end

  test "requires unique entity_id" do
    BaseEntity.create!(entity_id: "npc-bran", entity_type: "npc", name: "Bran", core_data: {})
    duplicate = BaseEntity.new(entity_id: "npc-bran", entity_type: "npc", name: "Other", core_data: {})
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:entity_id], "has already been taken"
  end

  test "stores arbitrary JSON data in core_data" do
    entity = BaseEntity.create!(
      entity_id: "npc-bran",
      entity_type: "npc",
      name: "Bran",
      core_data: { role: "Bartender", race: "Human" }
    )
    assert_equal "Bartender", entity.core_data["role"]
  end
end
