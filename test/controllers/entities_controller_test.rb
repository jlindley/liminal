require "test_helper"

class EntitiesControllerTest < ActionDispatch::IntegrationTest
  test "displays entity core data" do
    entity = BaseEntity.create!(
      entity_id: "npc-bran",
      entity_type: "npc",
      name: "Bran",
      core_data: {
        "role" => "Bartender",
        "race" => "Human",
        "description" => "A weathered bartender with kind eyes"
      }
    )

    get "/entities/npc-bran"

    assert_response :success
    assert_select "body", /Bran/
    assert_select "body", /Bartender/
    assert_select "body", /A weathered bartender with kind eyes/
  end

  test "returns 404 for missing entity" do
    get "/entities/npc-missing"
    assert_response :not_found
  end
end
