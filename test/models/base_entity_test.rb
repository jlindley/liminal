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

  test "can store replaces field" do
    original = BaseEntity.create!(
      entity_id: "npc-elena",
      entity_type: "npc",
      name: "Elena",
      core_data: {}
    )
    replacement = BaseEntity.create!(
      entity_id: "npc-elena-warlock",
      entity_type: "npc",
      name: "Elena (Warlock)",
      core_data: {},
      replaces: "npc-elena"
    )
    assert_equal "npc-elena", replacement.replaces
  end

  test "can store show_when array" do
    entity = BaseEntity.create!(
      entity_id: "npc-bran",
      entity_type: "npc",
      name: "Bran",
      core_data: {},
      show_when: ["overlay-magic", "overlay-combat"]
    )
    assert_equal ["overlay-magic", "overlay-combat"], entity.show_when
  end

  test "show_when defaults to empty array" do
    entity = BaseEntity.create!(
      entity_id: "npc-bran",
      entity_type: "npc",
      name: "Bran",
      core_data: {}
    )
    assert_equal [], entity.show_when
  end

  test "validation fails when replaces references non-existent entity" do
    entity = BaseEntity.new(
      entity_id: "npc-elena-warlock",
      entity_type: "npc",
      name: "Elena (Warlock)",
      core_data: {},
      replaces: "npc-nonexistent"
    )
    assert_not entity.valid?
    assert_includes entity.errors[:replaces], "must reference an existing entity_id (npc-nonexistent not found)"
  end

  test "validation fails when entity tries to replace itself" do
    entity = BaseEntity.new(
      entity_id: "npc-elena",
      entity_type: "npc",
      name: "Elena",
      core_data: {},
      replaces: "npc-elena"
    )
    assert_not entity.valid?
    assert_includes entity.errors[:replaces], "cannot replace itself"
  end

  test "uniqueness constraint prevents duplicate replacements" do
    original = BaseEntity.create!(
      entity_id: "npc-elena",
      entity_type: "npc",
      name: "Elena",
      core_data: {}
    )
    first_replacement = BaseEntity.create!(
      entity_id: "npc-elena-warlock",
      entity_type: "npc",
      name: "Elena (Warlock)",
      core_data: {},
      replaces: "npc-elena"
    )
    second_replacement = BaseEntity.new(
      entity_id: "npc-elena-rogue",
      entity_type: "npc",
      name: "Elena (Rogue)",
      core_data: {},
      replaces: "npc-elena"
    )

    assert_raises(ActiveRecord::RecordNotUnique) do
      second_replacement.save(validate: false)
    end
  end
end
