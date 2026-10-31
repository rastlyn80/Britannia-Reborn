# Mountain relief (31 October 2026)

Owner request: mountains on the surface looked like small hills; they should be much taller.

## Why they were low

The source map gives a mountain about 10–20 m above the ground around it (UO Z × 0.2 m). In 2D, the isometric projection and the art of mountain tiles make that read as a range. In 3D, with 1 m tiles, the same heights are gentle mounds, and the dungeon cave walls only about 3 m.

## What changed

`Converter relief <dataset> [factor] [ramp]` (`Converter/Relief.cs`) writes `relief.u8` and `relief.json` beside the converted chunks:

- **Which corners rise:** every terrain corner surrounded on all four sides by impassable, dry land. That covers mountain rock (flag 0x40), cave walls and the dungeon void; water is excluded.
- **How much:** each such corner rises by (factor − 1) × its height above the nearest walkable corner (a two-pass chamfer distance carries the foot height). The lift eases in over the first `ramp` tiles and is softened over its 3 × 3 neighbours, up to 32 m. Sea cliffs over deep water would otherwise rise 60 m.
- **Format:** one byte per corner, in quarter metres, for the whole facet (29 MB for Trammel).
- **Settings:** factor 2.2 and ramp 7 tiles, chosen from previews at the Covetous range. A 3-tile ramp rose like a curtain wall; 7 tiles gives jagged peaks.
- **Trammel:** 1,757,705 corners lifted, up to +32 m.

**Where the relief is used:**
- `TerrainSurface.z()` adds the relief (`Relief.gd`, read row by row for each window) to the drawn terrain and its collision heightmap.
- `AtlasGeometry` adds it to the regional horizon.

**What does not change:**
- Corners touching walkable land carry no relief, so walkable ground, movement and the server keep their exact heights.
- `RegionalBake.fingerprint` includes `relief.u8`, so a new relief rebakes every district.
- `scripts/bake-facet.ps1` recomputes the relief when the conversion is newer.

## Checks

- `ReliefTests` (in `scripts/verify.ps1`): relief reads, a lifted corner is drawn higher, other corners and datasets without relief are unchanged.
- Preview bakes of six districts at Covetous (`BakeStreaming --preview-output`) rendered before and after.

## Status

The code and Trammel's relief are ready. The baked cache shows the change after the next facet bake, which also rebakes for the dungeon entrance blockers (`docs/DUNGEONS.md`) and, per `docs/COMPACT_STREAMING.md`, applies its next compression steps.
