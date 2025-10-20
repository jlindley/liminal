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

### Resolution Rules (Determined by Spike)

- Entity replacement beats modification
- DM customization beats everything
- Merge multiple modifications when compatible
- Clear precedence order (to be validated by spike)

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

## Open Questions (Spike Will Answer)

1. **Data model for overlay resolution** - Which approach balances flexibility, maintainability, and performance?
2. **File format for conditional content** - How do we represent "if overlay X then content Y" in markdown/TOML?
3. **Query patterns** - What's the actual performance of "resolve entity for campaign"?
4. **Validation feasibility** - Can we realistically validate overlay combinations with sampling strategy?

## Future Considerations

- Multiple game systems (5e → Pathfinder → Dungeon World) - stat blocks would need abstraction
- Export pipelines (PDF, Roll20 formats)
- Additional play kits beyond "bubble"
- Player features (notes, bookmarks)
- Character sheet management
- Real-time updates (ActionCable for instant reveals)
