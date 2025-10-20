# Spike Findings: Approach 2 - Compositional Layers

## Summary

**Status:** ✅ **Working** - All test scenarios pass

**Approach:** Base entities with `core_data` + `conditional_fragments` that merge based on active overlays. DM customizations layer on top via override records.

## What Works

### ✅ Core Resolution Logic
- Base entity has `core_data` (always present) + `conditional_fragments` (activated by overlays)
- Resolution: `base.core_data → merge matching fragments → apply DM overrides`
- Simple linear merge process - easy to reason about

### ✅ Conditional Content
- Fragments declare `required_overlays` array
- Fragment activates when ALL required overlays are active in campaign
- Multiple fragments can activate together (additive merging)
- Fragments can override base data (description becomes "...with burn scar")

### ✅ Complete Entity Replacement
- DM can create `replace` override that completely swaps entity
- Example: Elena replaces Bran when `100-years-bubbled` is active
- Replacement data contains full entity structure

### ✅ DM Customizations
All three types work:
1. **Disable:** Override with `override_type: 'disable'` - entity returns nil
2. **Edit:** Override with custom data - deep merges over resolved data
3. **Replace:** Override with full replacement - ignores base entirely

### ✅ Mutual Exclusivity
- Overlays have `mutually_exclusive_with` array
- Campaign validates on save - rejects conflicting overlay combinations
- Validation is bi-directional (A excludes B, B excludes A)

### ✅ Field Visibility
- Each field in entity has visibility rule in `visibility_rules` hash
- Three levels: `public_when_discovered`, `dm_controlled`, `dm_only`
- `resolve_entity(id, viewer_role: :player)` filters based on rules
- Fields without rules are hidden by default (safe)

## Test Results

All test scenarios from spike definition work:

```
✅ Campaign with no overlays → base Bran
✅ Campaign with recently-bubbled → Bran + skepticism + mace
✅ Campaign with recently-bubbled + elemental-maelstorm → all fragments merge
✅ Campaign with 100-years-bubbled → Elena replaces Bran
✅ DM edit → removes quest hook
✅ Location replacement → burned tavern shell
✅ Mutual exclusivity validation → rejects conflicting overlays
✅ Field visibility → players see only public fields, DMs see everything
```

## Schema Design

### Tables

**campaigns**
- `name`, `play_kit_id`
- `active_overlays` (jsonb array) - e.g. `['recently-bubbled', 'elemental-maelstorm']`
- Validates mutual exclusivity on save

**overlays**
- `overlay_id` (human-readable, e.g. 'recently-bubbled')
- `name`, `overlay_type` ('major' or 'flavor')
- `mutually_exclusive_with` (jsonb array)

**base_entities**
- `entity_id` (human-readable, e.g. 'npc-bran')
- `entity_type` (npc, location, quest, item, adventure)
- `name`
- `core_data` (jsonb) - always-present fields
- `conditional_fragments` (jsonb) - array of `{required_overlays: [...], data: {...}}`
- `visibility_rules` (jsonb) - maps field names to visibility levels

**dm_overrides**
- `campaign_id`, `base_entity_id`
- `override_type` ('disable', 'edit', 'replace')
- `override_data` (jsonb) - custom data or full replacement

## Proposed File Format (TOML)

```toml
# entities/npcs/npc-bran.toml

entity_id = "npc-bran"
entity_type = "npc"
name = "Bran"

[core_data]
name = "Bran"
race = "Human"
role = "Bartender"
description = "A weathered bartender with kind eyes"

[core_data.stats]
ac = 10
hp = 8

[[conditional_fragments]]
required_overlays = ["recently-bubbled"]
[conditional_fragments.data]
personality = "Skeptical of outsiders"
items = ["magical-mace"]

[[conditional_fragments]]
required_overlays = ["elemental-maelstorm"]
[conditional_fragments.data]
description = "A weathered bartender with kind eyes and a burn scar on his left cheek"
quest_hooks = ["recover-roof-materials"]

[visibility_rules]
name = "public_when_discovered"
description = "public_when_discovered"
personality = "dm_controlled"
stats = "dm_only"
quest_hooks = "dm_only"
```

### Overlays File

```toml
# overlays/overlays.toml

[[overlay]]
overlay_id = "recently-bubbled"
name = "Recently Bubbled"
overlay_type = "major"
mutually_exclusive_with = ["100-years-bubbled"]

[[overlay]]
overlay_id = "100-years-bubbled"
name = "100 Years Bubbled"
overlay_type = "major"
mutually_exclusive_with = ["recently-bubbled"]

[[overlay]]
overlay_id = "elemental-maelstorm"
name = "Elemental Maelstorm"
overlay_type = "flavor"
mutually_exclusive_with = []
```

### For Complete Replacements

Complete replacements (like Elena) would either:
1. Be their own entity file with a conditional that hides Bran, OR
2. Be modeled as extremely heavy conditional fragments

Option 1 is cleaner:

```toml
# entities/npcs/npc-elena.toml
entity_id = "npc-elena"
entity_type = "npc"
name = "Elena"
replaces = "npc-bran"  # Special field
show_when = ["100-years-bubbled"]

[core_data]
name = "Elena"
race = "Human"
role = "Bartender"
description = "Bran's granddaughter, young and energetic"
# ... etc
```

## What's Tricky

### 1. Replacement Semantics
When Elena replaces Bran:
- What happens to Bran's conditional fragments?
- Does Elena inherit burn scar from elemental-maelstorm?
- Decision: Replacement wins, fragments ignored (current implementation)
- Could be confusing - needs clear documentation

### 2. Deep Merge Behavior
- `deep_merge` for overlapping data works but could be surprising
- Example: fragment adds `items: ['mace']`, another adds `items: ['sword']`
- Current: second overwrites first (Hash merge behavior)
- Might want array concatenation instead
- For spike: acceptable, production needs clear rules

### 3. Visibility Rules Scope
- Currently per-field on entity
- What about nested data? (stats.ac, stats.hp individually?)
- Current: treat `stats` as single field
- More granular would need different structure

### 4. Fragment Order Matters
- Fragments merge in array order when multiple match
- Not documented in schema
- Could be source of bugs if content authors aren't aware

## Performance Considerations

### Query Pattern
```ruby
# One query for base entity
base = BaseEntity.find_by(entity_id: 'npc-bran')

# One query for DM overrides (could eager load)
campaign.dm_overrides.where(base_entity_id: base.id)

# In-memory JSON manipulation
# - Deep copy core_data
# - Iterate fragments, filter by active overlays
# - Deep merge matching fragments
# - Apply DM overrides
# - Filter by visibility
```

**Pros:**
- Simple queries (find + filter)
- Most work is in-memory JSON manipulation (fast)
- Easy to cache resolved entities

**Cons:**
- Can't query across resolved data (e.g. "find all NPCs with burn scars")
- All fragments loaded even if not matching (small dataset, not a problem)

### Scalability
- Personal use + alpha: **totally fine**
- 100s of entities, 10s of overlays: **no problem**
- 1000s of entities queried simultaneously: **would need caching**

## Multi-Game-System Support

**Question:** How do different stat blocks work? (D&D 5e vs Pathfinder vs Dungeon World)

**Answer for this approach:**

Stat blocks live in `core_data` as arbitrary JSON. No schema enforcement.

```toml
# For D&D 5e
[core_data.stats]
system = "dnd5e"
ac = 10
hp = 8
str = 12
dex = 10
# ...

# For Dungeon World
[core_data.stats]
system = "dungeon_world"
hp = 8
armor = 1
damage = "d6"
tags = ["Small", "Organized"]
```

**Pros:**
- Maximum flexibility
- No schema changes needed per system
- Content files define their own structure

**Cons:**
- No type safety
- Can't validate stat blocks at DB level
- UI needs to know how to render different systems

**Recommendation:** Acceptable for spike. Production might want `stat_block_schema_id` field to enable validation.

## Maintainability

**Developer Experience: 8/10**

**Good:**
- Mental model is simple: "base + layers"
- Resolution logic is linear and predictable
- Easy to debug (print resolved data at each step)
- File format maps cleanly to schema

**Tricky:**
- Replacement vs fragment semantics need docs
- Deep merge behavior could surprise
- Fragment order matters but isn't obvious

**Code Quality:**
- Spike code is rough (as intended)
- Production would need:
  - Better error handling
  - Caching layer
  - Fragment merge rules (arrays, hashes)
  - Discovery state for visibility
  - Importer for TOML files

## Extensibility

### Easy to Add
- ✅ New overlay types (trivial - just data)
- ✅ New entity types (just set entity_type)
- ✅ New visibility levels (add to case statement)
- ✅ More complex overlay requirements (AND/OR logic in fragment matching)

### Harder to Add
- ❌ Querying resolved data (need materialized view or cache)
- ❌ Entity relationships (NPC has items, quest has locations)
  - Could be entity_id references in data
  - No referential integrity
- ❌ Cross-entity overlays (overlay affects multiple entities)
  - Would need separate table mapping overlays to entity changes
  - Current: all effects encoded in entity files

## Recommendation

**Feasible: YES**

**Confidence: High** - All requirements met, tests pass, clear path forward

**Production Readiness:**
- Core approach is solid
- Needs refinement (merge rules, caching, importer)
- File format works
- ~2-3 more days to production quality

**Compared to Requirements:**
- ✅ Base content + DM overrides without duplication
- ✅ Query logic resolves correctly
- ✅ Mutual exclusivity validated
- ✅ Field visibility works
- ✅ DM customizations work
- ✅ Maintainable and performant
- ✅ Multi-system support via flexible JSON
- ✅ Clear file format

## Next Steps (If Chosen)

1. **Refinement:**
   - Define merge rules for arrays vs objects
   - Add caching layer for resolved entities
   - Handle discovery state for visibility

2. **Importer:**
   - TOML → BaseEntity records
   - Validate overlay references
   - Track content IDs (content-ids.toml)

3. **Replacement Semantics:**
   - Decide: do replacements inherit fragments?
   - Document clearly
   - Add tests for edge cases

4. **Entity Relationships:**
   - How do quests reference NPCs/locations?
   - entity_id strings in data?
   - Separate join table?

5. **Query Layer:**
   - Can't query "NPCs with burn scars" currently
   - Need materialized view or search index?
   - Or acceptable limitation?

## Code Quality Note

This is spike code - messy by design. Working implementation, not production code.
See test files for proof of functionality.
