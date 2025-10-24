# Liminal Project Context

## What This Is

D&D campaign setting platform with dynamic overlay system. Building both the app AND the first setting.

## Core Design Principles

1. **ONE codebase** - Maximum monolith. Rails 8 all the way down.
2. **Guardrails over resolution** - Prevent bad overlay combinations, don't fix them.
3. **Simple deployment** - VPS with Kamal, PostgreSQL co-located.
4. **Files for base content** - Play kit content in markdown/TOML, version controlled, imported to DB.
5. **UI for DM customizations** - DMs use web interface, never touch files.

## Critical Terminology

- **Play Kit**: Campaign setting package (internal ID like "bubble", separate display title)
- **Overlay**: Modification layer with mutual exclusivity rules (major vs flavor types)
- **Campaign**: DM's instance of a play kit with chosen overlays
- **Entity**: Base content unit (NPC, Location, Quest, Item, Adventure)

## Tech Stack

Rails 8, PostgreSQL, Hotwire/Turbo, Tailwind, Kamal to VPS.

## Development Principles

**Logging for Complex Data Interactions:**
- This project has multi-layer data resolution (base → fragments → replacements → overrides → visibility filtering)
- Debug logging is a fundamental requirement, not an afterthought
- Log every decision point in the resolution path
- Make logs developer-friendly: explain WHY something happened, not just WHAT
- Use `Rails.logger.debug` for detailed resolution tracing (disabled in production)
- When data transforms, log before and after states
- Think: "If this breaks at 2am, will the logs tell me why?"

**Data Integrity Principles:**
- **Guardrails over Resolution**: Prevent bad data at entry (validations, constraints), don't try to fix it during resolution
- **Fail Fast**: Invalid data should be rejected immediately with clear error messages
- **Defense in Depth**:
  - Application-level validations for quick feedback during development
  - Database-level constraints for enforcement even if validations bypassed
  - Test both layers independently
- **Referential Integrity**:
  - Validate foreign references at application level (e.g., `replaces` field must reference existing entity_id)
  - Document why database FK constraints aren't used when applicable (e.g., string-based references to entity_id)
  - Use uniqueness constraints for one-to-one relationships (e.g., one entity can only replace one other)
- **Edge Case Handling**: Empty arrays, nil values, duplicates, invalid types - handle them explicitly, don't rely on implicit behavior

See DESIGN.md for full details.
