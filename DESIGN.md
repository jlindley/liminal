# Liminal - Design Document

## Project Overview

**Liminal** is a D&D campaign setting platform that enables dynamic, customizable content through an overlay system. It's both a software application and a specific campaign setting ("bubble" - working display title: "Bubble City").

**Core concept:** A city plucked from its world into a bubble, with various "overlays" that modify the setting's narrative, challenges, and content.

## Design Principles

1. **ONE codebase** - Maximum monolith. No microservices, no separate frontend, everything in Rails.
2. **Guardrails over conflict resolution** - Prevent bad overlay combinations rather than resolving conflicts.
3. **Simple deployment** - VPS with Kamal, PostgreSQL on same server, old school simplicity.
4. **Field-level visibility** - Control what players see at the attribute level, not just entity level.
5. **Non-pathological performance** - Not internet scale, but not broken either.

## Architecture

### Two-Tier Namespace Model

```
Play Kit (internal_id: "bubble", title: "Bubble City")
  ├─ Base Content (version controlled, imported)
  ├─ Overlay Definitions (mutually exclusive rules)
  │
  ├─ Campaign 1 (DM instance)
  │   ├─ Active overlays
  │   ├─ DM customizations
  │   └─ Player access
  │
  └─ Campaign 2 (Different DM instance)
      ├─ Different overlays
      ├─ Different customizations
      └─ Different players
```

**Note:** Play kits have short internal identifiers (e.g., "bubble") used in code/URLs, and separate display titles shown to users.

### Core Models

- **PlayKit**: Container for a setting (internal_id, title, description, overlay definitions)
- **Overlay**: Modification layer (major vs flavor, mutual exclusivity rules)
- **Entity**: Polymorphic base content (NPC, Location, Quest, Item, Adventure, etc.)
- **Campaign**: DM's instance of a play kit (selected overlays, active state)
- **User**: DMs and Players with role-based permissions
- **CampaignMembership**: Links players to campaigns with discovery tracking

## Dual Authoring System

### Path 1: Play Kit Content (Files → Database)

Base content lives in version control:

```
liminal/
  playkit-bubble/
    playkit.toml              # Metadata (internal_id: "bubble", title, overlays)
    content-ids.toml          # ID counters (npc, loc, quest, etc.)
    overlays/
      elemental-maelstorm.toml
      recently-bubbled.toml
      100-years-bubbled.toml
      political-lockdown.toml
    npcs/
      bran.md                 # Frontmatter: id: npc-43
      elena.md
    locations/
      forgotten-stag.md
      former-forgotten-stag.md
    quests/
      roof-materials.md
    adventures/
      ...
```

**Helper tooling:**
- `./new-content npc bran` - Creates file with next ID, updates content-ids.toml
- Import rake task - Parses files, loads into database
- Pre-commit validation - Tests overlay combinations, checks references

**ID Strategy:**
- Human-readable IDs: `npc-1`, `loc-42`, `quest-5`
- Tracked in content-ids.toml
- Stable across file renames
- Solo authoring only (not safe for concurrent ID generation)

**File Format Examples:**

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

**For complete entity replacements:**

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
# ... full entity data
```

**Overlay definitions:**

```toml
# overlays/overlays.toml

[[overlay]]
overlay_id = "recently-bubbled"
name = "Recently Bubbled"
overlay_type = "major"
mutually_exclusive_with = ["100-years-bubbled"]

[[overlay]]
overlay_id = "elemental-maelstorm"
name = "Elemental Maelstorm"
overlay_type = "flavor"
mutually_exclusive_with = []
```

### Path 2: DM Customization (Web UI)

DMs use structured editor:
- Override base content (non-destructive)
- Add custom entities
- Hide/disable content
- Control player visibility

Changes stored in database only, not files.

## Content Visibility Model

### Three Permission Tiers

**1. Always public (when discovered):**
- Name, basic description, appearance
- Flavor text without mechanical relevance

**2. DM-controlled (selectively revealed):**
- Deeper lore/background
- Faction affiliations
- Quest details
- Item properties (case by case)

**3. DM-only (never shared):**
- Stat blocks (AC, HP, saves)
- Quest hooks (DM-facing design notes)
- Adventure structure/secrets

### Player Content Categories

**Reference material (visible on join):**
- Campaign lore/setting overview
- Character backgrounds/options (e.g., "Elemental Warden", "Agriculture Forced Laborer")
- Public maps
- House rules

**Discovered content (revealed during play):**
- NPCs (individually discovered)
- Locations (as visited)
- Quests (DM shares)
- Items (found/identified)

## Overlay System

### Overlay Types

**Major overlays:** Thoroughly affect the world (different villains, core challenges)
- Example: `recently-bubbled` vs `100-years-bubbled` (timeline)
- Mutually exclusive when appropriate

**Flavor overlays:** Limited surface-area changes
- Example: `elemental-maelstorm` (environmental effects)
- Can combine freely with others

### Guardrails

**Mutual exclusivity:**
```toml
# overlays/100-years-bubbled.toml
mutually_exclusive_with = ["recently-bubbled"]
```

**Campaign creation:**
- UI prevents selecting conflicting overlays
- Clear messaging about what overlays represent
- Preview mode to see resolved content

**Content validation:**
- Automated tests check valid overlay combinations (sampling strategy, not exhaustive)
- Flag entities with many overlay dependencies for manual review
- Catch orphaned references
- Validate mutually exclusive rules

**Note on combinatorial explosion:** With 3 major and 6 flavor overlays, naive exhaustive testing = ~192 combinations. Validation strategy: test each overlay individually, test mutual exclusivity enforcement, sample common/recommended combinations, flag high-complexity entities.

### Resolution Rules (Compositional Layers Approach)

**Resolution flow:**
1. Start with base entity's `core_data` (always present fields)
2. Merge matching `conditional_fragments` (where ALL `required_overlays` are active in campaign)
3. Apply DM overrides (disable, edit, or replace)
4. Filter by field visibility rules based on viewer role

**Merge semantics:**
- Multiple matching fragments merge additively in array order
- Later fragments override earlier ones for the same keys (Hash merge behavior)
- DM overrides always win (deep merge over resolved base + fragments)

**Replacement behavior:**
- Entity replacement via `replaces` field + `show_when` conditions
- When replacement is active, original entity and its fragments are hidden
- Replacement entity is treated as entirely separate (doesn't inherit fragments)

**Precedence hierarchy:**
1. DM disable override → entity returns nil
2. DM replace override → use replacement data entirely
3. DM edit override → deep merge over resolved base
4. Conditional fragments → merge where overlays match
5. Base core_data → foundation layer

## User Workflows

### DM Workflow

1. **Campaign creation:**
   - Select play kit ("bubble")
   - Choose overlays (with mutual exclusivity enforced)
   - Name campaign, set info

2. **Campaign management:**
   - Browse content (as resolved for their overlays)
   - Preview mode (toggle overlays on/off)
   - Customize entities (edit/hide/replace/disable)
   - Mark content as discovered for players

3. **Player management:**
   - Invite players
   - Control content visibility
   - Selectively reveal dm-controlled fields

### Player Workflow

1. **Join campaign** via invite link
2. **Access reference material** immediately (lore, backgrounds, maps)
3. **Browse discovered content** (NPCs, locations, quests as revealed by DM)
4. **Read-only experience** with field-level filtering

**Key principle:** Players never see overlay configuration. They see the world as it is, not the authoring mechanics.

**Motivation:** Rich reference material gets players invested before session 1, thinking about characters in context.

## Technology Stack

**Framework:** Rails 8
**Database:** PostgreSQL (JSON columns for flexible data)
**Authentication:** Devise
**Authorization:** Pundit (role-based)
**Frontend:** Hotwire/Turbo (stay in Rails)
**Styling:** Tailwind CSS
**File Processing:** Ruby stdlib for TOML/markdown
**Deployment:** Kamal to VPS (single server, PostgreSQL co-located)

**Not using:** Microservices, GraphQL, separate JS framework, complex infrastructure

## Testing Strategy

**Content validation:**
- Pre-commit hooks validate files
- Sample overlay combinations (not exhaustive)
- Verify references, required fields
- Test mutual exclusivity

**Application tests:**
- Standard Rails test suite
- Integration tests for overlay resolution
- Critical path: campaign creation → overlay selection → entity resolution
- DM customization precedence

**Manual validation:**
- Preview mode during authoring
- Toggle overlays extensively
- Alpha tester campaigns (real-world validation)

## Success Criteria (MVP)

**Personal use + alpha testers:**
- Author "bubble" content in files
- Import into application
- Run own campaign with overlay selection
- 1-2 alpha tester DMs
- Players can join and see discovered content

**Out of scope (MVP):**
- Character management system
- Auto-leveling encounters to party level
- Export to PDF/Roll20
- Multiple play kits
- Multi-system support (Pathfinder, Dungeon World)

## Data Model Details

### Schema

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

### Query Performance

**Pattern:**
- One query for base entity
- One query for DM overrides (can be eager loaded)
- In-memory JSON manipulation for fragment merging and visibility filtering

**Scalability:**
- Personal use + alpha testers: no performance concerns
- Caching layer recommended for production with many concurrent DMs
- Cannot efficiently query across resolved data (e.g. "find all NPCs with burn scars")
  - This is an acceptable limitation for the use case
  - If needed later: materialized views or search index

## Future Considerations

**Multiple game systems:**
- Stat blocks stored as arbitrary JSON in `core_data` - no schema enforcement
- Each entity can specify `system` field (e.g. "dnd5e", "pathfinder", "dungeon_world")
- Maximum flexibility, but no type safety or DB-level validation
- UI layer responsible for rendering different stat block formats
- Future: could add `stat_block_schema_id` for validation if needed

**Other future features:**
- Export pipelines (PDF, Roll20 formats)
- Additional play kits beyond "bubble"
- Player features (notes, bookmarks)
- Character sheet management
- Real-time updates (ActionCable for instant reveals)
- Entity relationships with referential integrity (currently just entity_id strings in data)
- Querying resolved data (requires materialized views or search index)
