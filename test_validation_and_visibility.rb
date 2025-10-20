#!/usr/bin/env ruby
require_relative 'config/environment'

# Clean slate - order matters due to foreign keys
DmOverride.destroy_all
Campaign.destroy_all
BaseEntity.destroy_all
Overlay.destroy_all

puts "\n=== Testing Mutual Exclusivity Validation ==="

# Set up overlays
recently = Overlay.create!(
  overlay_id: 'recently-bubbled',
  name: 'Recently Bubbled',
  overlay_type: 'major',
  mutually_exclusive_with: ['100-years-bubbled']
)

hundred_years = Overlay.create!(
  overlay_id: '100-years-bubbled',
  name: '100 Years Bubbled',
  overlay_type: 'major',
  mutually_exclusive_with: ['recently-bubbled']
)

# Try to create campaign with mutually exclusive overlays
campaign = Campaign.new(
  name: 'Invalid Campaign',
  play_kit_id: 'bubble',
  active_overlays: ['recently-bubbled', '100-years-bubbled']
)

if campaign.valid?
  puts "ERROR: Campaign should be invalid but passed validation!"
else
  puts "✓ Validation correctly caught mutually exclusive overlays"
  puts "  Errors: #{campaign.errors.full_messages}"
end

# Valid campaign
valid_campaign = Campaign.create!(
  name: 'Valid Campaign',
  play_kit_id: 'bubble',
  active_overlays: ['recently-bubbled']
)
puts "✓ Valid campaign created successfully"

puts "\n=== Testing Field Visibility ==="

# Create test entity
bran = BaseEntity.create!(
  entity_id: 'npc-bran',
  entity_type: 'npc',
  name: 'Bran',
  core_data: {
    'name' => 'Bran',
    'description' => 'A weathered bartender',
    'personality' => 'Gruff but kind',
    'stats' => { 'ac' => 10, 'hp' => 8 },
    'quest_hooks' => ['find-missing-shipment']
  },
  conditional_fragments: [],
  visibility_rules: {
    'name' => 'public_when_discovered',
    'description' => 'public_when_discovered',
    'personality' => 'dm_controlled',
    'stats' => 'dm_only',
    'quest_hooks' => 'dm_only'
  }
)

# Test DM view
dm_view = valid_campaign.resolve_entity('npc-bran', viewer_role: :dm)
puts "\nDM View:"
puts dm_view.inspect
puts "Should show: name, description, personality, stats, quest_hooks (everything)"

# Test player view
player_view = valid_campaign.resolve_entity('npc-bran', viewer_role: :player)
puts "\nPlayer View:"
puts player_view.inspect
puts "Should show: name, description only (public_when_discovered)"
puts "Should NOT show: personality (dm_controlled), stats (dm_only), quest_hooks (dm_only)"

# Verify
if player_view.keys.sort == ['description', 'name'].sort
  puts "✓ Player visibility filtering works correctly"
else
  puts "ERROR: Player view has wrong fields: #{player_view.keys}"
end

puts "\n=== All validation tests complete ==="
