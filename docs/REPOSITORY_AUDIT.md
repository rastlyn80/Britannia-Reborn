# Repository audit — 25 October 2026

Imported the latest working BritanniaPoC and portable tools, preserving the original. Converter/Program.cs is retained; the Godot viewer is extended rather than replaced. Original README is preserved in PROTOTYPE_README.md; root AUDIT.md and IR.md describe the earlier baseline.

| Area | Evidence | Assessment |
|---|---|---|
| Converter | .NET 8 build; 15 passing tests | Useful foundation; CLI, parsing, records and tests are monolithic |
| Formats | MUL, UOP raw/zlib, signed elevation, statics, local diffs | Real map1 UOP imported; production compressed UOP only fixture-tested |
| IR | Engine-independent JSON v1 with source IDs, raw coordinates and explicit scale | Missing classifications, multis, persistent overrides and per-input provenance |
| Godot | Real crop loads: 2,304 samples, 1,616 statics | Orbit/pan/zoom; arbitrary proxy dimensions and ID-modulo diagnostic colors |
| Scripts | Migrated to project-local .tools | Rebuild passes; automation is Windows-only |
| ModernUO | Pinned source, zero-warning/error build, local listener and saved account | Separate runtime; core and gameplay code unchanged |
| Network | Eight packet checks and live Godot authentication/server-list/relay | Direct protocol proven through handoff; no world session yet |

ModernUO source inventory confirms Skills/AnimalTaming, Spells schools, Items/Weapons/BaseWeapon, Mobiles/BaseCreature and PlayerMobile, Engines/Craft/Core/CraftSystem, Multis/Houses/BaseHouse, banking vendors, accounting and persistence. Distribution/Data includes expansion definitions, regions and era/facet spawn packs. Code presence is not comprehensive gameplay coverage, accuracy or play-testing; the runtime is not fully populated.

Smallest adjustments: keep the JSON seam; isolate server/runtime and client network code; extract parser/IR libraries when their API needs are established; add facet/profile parameters, bounded arithmetic, per-source provenance and seam-safe chunks before scaling. Replace one-node-per-static rendering and diagnostic materials after tiledata classification. Build server-validated session/movement before cosmetic client physics.

Observed gaps: independent in-game landmark comparison, established ClassicUO connection, full upstream tests, production compressed UOP, collision, terrain streaming, asset mapping, avatars and all non-Windows exports. Current base+all-local-diffs conversion may differ from a live server's patch/extended-world profile.

Initial empty-account setup requires a console; we answered n, then used normal login account creation and saved it. Disabling the pinned upstream ping service exposed a shutdown exception. No upstream code was patched or external report sent; the development configuration enables its loopback-bound ping listener.
