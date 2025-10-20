#!/usr/bin/env ruby
require_relative 'config/environment'

# Clean slate
Campaign.destroy_all
BaseEntity.destroy_all
DmOverride.destroy_all
Overlay.destroy_all

puts "\n=== Setting up test data ==="

# Create overlays
overlays = {
  'recently-bubbled' => Overlay.create!(
    overlay_id: 'recently-bubbled',
    name: 'Recently Bubbled',
    overlay_type: 'major',
    mutually_exclusive_with: ['100-years-bubbled']
  ),
  '100-years-bubbled' => Overlay.create!(
    overlay_id: '100-years-bubbled',
    name: '100 Years Bubbled',
    overlay_type: 'major',
    mutually_exclusive_with: ['recently-bubbled']
  ),
  'elemental-maelstorm' => Overlay.create!(
    overlay_id: 'elemental-maelstorm',
    name: 'Elemental Maelstorm',
    overlay_type: 'flavor',
    mutually_exclusive_with: []
  ),
  'political-lockdown' => Overlay.create!(
    overlay_id: 'political-lockdown',
    name: 'Political Lockdown',
    overlay_type: 'flavor',
    mutually_exclusive_with: []
  )
}

puts "Created #{overlays.size} overlays"

# Create Bran (base NPC)
bran = BaseEntity.create!(
  entity_id: 'npc-bran',
  entity_type: 'npc',
  name: 'Bran',
  core_data: {
    'name' => 'Bran',
    'race' => 'Human',
    'role' => 'Bartender',
    'description' => 'A weathered bartender with kind eyes',
    'stats' => { 'ac' => 10, 'hp' => 8 }
  },
  conditional_fragments: [
    {
      'required_overlays' => ['recently-bubbled'],
      'data' => {
        'personality' => 'Skeptical of outsiders',
        'items' => ['magical-mace']
      }
    },
    {
      'required_overlays' => ['elemental-maelstorm'],
      'data' => {
        'description' => 'A weathered bartender with kind eyes and a burn scar on his left cheek',
        'quest_hooks' => ['recover-roof-materials']
      }
    }
  ],
  visibility_rules: {
    'name' => 'public_when_discovered',
    'description' => 'public_when_discovered',
    'personality' => 'dm_controlled',
    'stats' => 'dm_only',
    'quest_hooks' => 'dm_only'
  }
)

puts "Created Bran (base NPC)"

# Create The Forgotten Stag (base location)
tavern = BaseEntity.create!(
  entity_id: 'loc-forgotten-stag',
  entity_type: 'location',
  name: 'The Forgotten Stag',
  core_data: {
    'name' => 'The Forgotten Stag',
    'type' => 'Tavern',
    'description' => 'A cozy tavern with a roaring fireplace'
  },
  conditional_fragments: [],
  visibility_rules: {
    'name' => 'public_when_discovered',
    'description' => 'public_when_discovered'
  }
)

puts "Created The Forgotten Stag (base location)"

# Test Scenario 1: No overlays
puts "\n=== Test 1: Campaign with no overlays ==="
campaign1 = Campaign.create!(name: 'Test Campaign 1', play_kit_id: 'bubble', active_overlays: [])
result = campaign1.resolve_entity('npc-bran')
puts "Bran data: #{result.inspect}"
puts "Should have: base description, no personality, no items"

# Test Scenario 2: Recently bubbled
puts "\n=== Test 2: Campaign with recently-bubbled ==="
campaign2 = Campaign.create!(name: 'Test Campaign 2', play_kit_id: 'bubble', active_overlays: ['recently-bubbled'])
result = campaign2.resolve_entity('npc-bran')
puts "Bran data: #{result.inspect}"
puts "Should have: skeptical personality + magical mace"

# Test Scenario 3: Recently bubbled + Elemental maelstorm
puts "\n=== Test 3: Campaign with recently-bubbled + elemental-maelstorm ==="
campaign3 = Campaign.create!(
  name: 'Test Campaign 3',
  play_kit_id: 'bubble',
  active_overlays: ['recently-bubbled', 'elemental-maelstorm']
)
result = campaign3.resolve_entity('npc-bran')
puts "Bran data: #{result.inspect}"
puts "Should have: skeptical personality + magical mace + burn scar + quest hook"

# Test Scenario 4: 100 years bubbled (complete replacement)
# For this we need to create a replacement entity via DMOverride
puts "\n=== Test 4: Campaign with 100-years-bubbled (Elena replaces Bran) ==="
campaign4 = Campaign.create!(name: 'Test Campaign 4', play_kit_id: 'bubble', active_overlays: ['100-years-bubbled'])

# In this approach, replacements are handled as conditional fragments OR as a separate replacement entity
# Let me model Elena as a replacement
elena_replacement = DmOverride.create!(
  campaign: campaign4,
  base_entity: bran,
  override_type: 'replace',
  override_data: {
    'name' => 'Elena',
    'race' => 'Human',
    'role' => 'Bartender',
    'description' => 'Bran\'s granddaughter, young and energetic',
    'stats' => { 'ac' => 11, 'hp' => 12 }
  }
)

result = campaign4.resolve_entity('npc-bran')
puts "Result: #{result.inspect}"
puts "Should have: Elena instead of Bran"

# Test Scenario 5: DM customization - disable quest hook
puts "\n=== Test 5: DM disables quest hook ==="
campaign5 = Campaign.create!(
  name: 'Test Campaign 5',
  play_kit_id: 'bubble',
  active_overlays: ['elemental-maelstorm']
)

result_before = campaign5.resolve_entity('npc-bran')
puts "Before DM edit: #{result_before.inspect}"

# DM edits to remove quest hook
dm_edit = DmOverride.create!(
  campaign: campaign5,
  base_entity: bran,
  override_type: 'edit',
  override_data: {
    'quest_hooks' => []
  }
)

result_after = campaign5.resolve_entity('npc-bran')
puts "After DM edit: #{result_after.inspect}"
puts "Should have: burn scar but NO quest hooks"

# Test Scenario 6: Political lockdown (location replacement)
puts "\n=== Test 6: Political lockdown (tavern destroyed) ==="
campaign6 = Campaign.create!(
  name: 'Test Campaign 6',
  play_kit_id: 'bubble',
  active_overlays: ['political-lockdown']
)

burned_tavern = DmOverride.create!(
  campaign: campaign6,
  base_entity: tavern,
  override_type: 'replace',
  override_data: {
    'name' => 'Former Forgotten Stag',
    'type' => 'Ruins',
    'description' => 'A burned-out shell of what was once a cozy tavern'
  }
)

result = campaign6.resolve_entity('loc-forgotten-stag')
puts "Result: #{result.inspect}"
puts "Should have: Burned shell instead of cozy tavern"

puts "\n=== All tests complete ==="
