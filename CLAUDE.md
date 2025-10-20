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

See DESIGN.md for full details.
