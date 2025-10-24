require "test_helper"

class OverlayTest < ActiveSupport::TestCase
  test "requires overlay_id" do
    overlay = Overlay.new(name: "Recently Bubbled", overlay_type: "major")
    assert_not overlay.valid?
    assert_includes overlay.errors[:overlay_id], "can't be blank"
  end

  test "requires unique overlay_id" do
    Overlay.create!(overlay_id: "recently-bubbled", name: "Recently", overlay_type: "major")
    duplicate = Overlay.new(overlay_id: "recently-bubbled", name: "Other", overlay_type: "major")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:overlay_id], "has already been taken"
  end

  test "validates overlay_type is major or flavor" do
    overlay = Overlay.new(overlay_id: "test", name: "Test", overlay_type: "invalid")
    assert_not overlay.valid?
    assert_includes overlay.errors[:overlay_type], "is not included in the list"
  end

  test "stores array of mutually exclusive overlays" do
    overlay = Overlay.create!(
      overlay_id: "recently-bubbled",
      name: "Recently Bubbled",
      overlay_type: "major",
      mutually_exclusive_with: ["100-years-bubbled"]
    )
    assert_equal ["100-years-bubbled"], overlay.mutually_exclusive_with
  end
end
