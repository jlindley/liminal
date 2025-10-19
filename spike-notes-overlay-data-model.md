# Spike: Overlay Data Model

## Goal

Determine the best data modeling approach for a D&D campaign setting system that supports:
- Base content shared across all DM instances (read-only)
- Per-campaign overlay activation (mix-and-match from major and flavor overlays)
- Conditional content fragments within entities
- Complete entity replacement based on overlays
- DM customizations that layer on top of base + overlay content

## Success Criteria

- [ ] Schema handles base content + DM overrides without duplication
- [ ] Query logic correctly resolves "what content to show" given active overlays
- [ ] DM customizations (disable, edit, replace) work predictably with overlays
- [ ] Approach is maintainable and reasonably performant (not pathological)
- [ ] Clear path for extending to support multiple game systems (different stat blocks)

## Constraints

- Must use Rails (modern version, 7+)
- Must use PostgreSQL
- Personal use + alpha testers initially (not internet scale, but not pathological)

## Approaches

### Approach 1: Variant Resolution System

Each entity can have multiple "variants", each tagged with overlay conditions. At read time, resolve which variant to show based on campaign's active overlays.

**Core concept:**
- `BaseEntity` has many `EntityVariant` records
- Each variant has `overlay_conditions` (array of required overlays)
- DMs can add their own `DMVariant` records for customization
- Resolution: fetch all variants (base + DM), filter by active overlays, pick best match

### Approach 2: Compositional Layers

Base content is foundational. DM changes are "layers" that override or extend. Conditional fragments stored as JSON within each layer.

**Core concept:**
- `BaseEntity` with `core_data` (always visible) + `conditional_fragments` (show when overlays match)
- `Campaign` has `active_overlays`
- `DMOverride` records provide per-campaign modifications
- For full swaps: `DMEntity` can replace base entities with `show_when` conditions
- Resolution: load base → merge DM overrides → filter fragments by active overlays

### Approach 3: Graph-based Dependencies

Entities declare overlay dependencies. System resolves dependency graph to determine what's active.

**Core concept:**
- Each entity has `overlay_rules` (JSON) expressing complex conditions
- Rules: `require_all`, `exclude`, `replace_when`, etc.
- Campaign → resolve dependency graph → get active entity set
- Most flexible but most complex

## Test Scenario

Implement the "Forgotten Stag" tavern scenario:

**Base Setting:**
- Location: "The Forgotten Stag" tavern
- Owner: Bran (human bartender, basic stat block)

**Overlay: recently-bubbled**
- Bran gets conditional fragment: skeptical personality note
- Bran gets conditional item: magical mace

**Overlay: 100-years-bubbled**
- Bran is REPLACED entirely by Elena (his granddaughter)

**Overlay: elemental-maelstorm**
- Bran gets conditional fragment: burn scar description
- Bran gets conditional quest hook: recover stolen roof materials from local hoodlums

**Overlay: political-lockdown**
- The Forgotten Stag location is REPLACED by "Former Forgotten Stag" (burned-out shell)

**DM Customizations to Test:**
1. **Disable:** Hide the roof materials quest hook
2. **Edit:** Change Bran's base description
3. **Replace:** Swap the magical mace for a different magical item

**Test Cases:**
- Campaign with no overlays → base Bran + base tavern
- Campaign with `recently-bubbled` → Bran with skepticism + mace
- Campaign with `100-years-bubbled` → Elena instead of Bran
- Campaign with `recently-bubbled` + `elemental-maelstorm` → Bran with skepticism, mace, burn scar, and quest
- Campaign with `100-years-bubbled` + `elemental-maelstorm` → Elena (replacement wins) - what happens to burn scar/quest?
- Campaign with `political-lockdown` → Burned shell, no bartender
- Any of above + DM customizations

## Effort Limit

~3-4 hours per approach to implement the test scenario and validate resolution logic works correctly.

## Evaluation Priorities

- 40% Flexibility (handles future requirements, multiple game systems, new overlay types)
- 40% Developer Experience (easy to reason about, maintainable, clear mental model)
- 20% Performance (not pathological, reasonable query patterns)

## Notes

- All approaches use Rails + PostgreSQL
- Focus on data modeling patterns, not framework differences
- The overlay system is the core complexity - getting this wrong would be painful later
- Multi-game-system support (5e, Pathfinder, Dungeon World) means stat blocks need abstraction
- Export to PDF/Roll20 is future requirement, not spike focus
