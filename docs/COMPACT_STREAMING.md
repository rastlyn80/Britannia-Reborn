# Compact streaming cache — the storage rule (adopted 31 October 2026)

Owner decision, 31 October 2026, when the whole-Trammel bake was estimated at 60–120 GB: the prepared streaming cache stores every model **once** and places it **by reference**, compressed. Merged, uncompressed per-district geometry is no longer an accepted bake output. This applies to every facet: Trammel first, then Felucca, Ilshenar, Malas and Tokuno.

## Why

The facet itself is small. Trammel converts to 138 MB of source data (7,168 districts of 64×64 tiles; 4,164 of them empty ocean or void; 2.95 million statics). The cache was large only because of how the bake stored it.

| Prepared cache (measured 31 October 2026) | Near districts | Near total | Median district | Largest district | Far total |
|---|---:|---:|---:|---:|---:|
| Britain, classic | 88 | 2.33 GB | 22.9 MB | 72 MB | 0.24 GB |
| Britain, modern | 88 | 2.23 GB | 22.3 MB | 72 MB | 0.24 GB |
| Britain to Trinsic, modern | 408 | 15.99 GB | 27.9 MB | 204 MB | 0.92 GB |

On 26 October the same 88 Britain districts took about 299 MB with instancing (see [STREAMING_AND_MINIMAP.md](STREAMING_AND_MINIMAP.md)). Later bakes drifted into storing merged geometry instead. The largest district near Trinsic is a single 204 MB ArrayMesh: every tree, rock and wall copied out vertex by vertex. At that density all of Trammel would need roughly 60–120 GB, and the five facets several times that.

## The rule

1. **Models once, placements by reference.** A district file holds placements (model id, transform, hue/variant) and points at shared model resources stored once for the whole dataset. It must not hold copies of model geometry. Repeated meshes are MultiMesh instances, with their CPU transform arrays exported as before.
2. **Only what is unique is baked per district:** the terrain mesh, merged connected architecture that genuinely differs per place (walls, roofs, floors), and collision.
3. **Collision is compact.** Repeated props use shared shapes placed by reference. Only terrain and unique architecture carry baked triangle collision, still in slices of at most 2,000 faces for the frame budget.
4. **Compressed.** Resources are saved compressed (`ResourceSaver.FLAG_COMPRESS`). Mesh data uses Godot's vertex compression where precision allows.
5. **One cache per graphics mode is optional.** If classic and modern share models, they share the files.
6. **A size budget, enforced:**
   - near district at most 2 MB median and 8 MB maximum;
   - all of Trammel at most 5 GB.
   - The bake reports sizes, and verification fails a cache that breaks the budget.

## Expected size

- Trammel: about 1–3 GB (about 200 MB of placements for 2.95 million statics, about 1 GB of terrain for the about 3,000 land districts, plus shared models and collision).
- Felucca: the same map as Trammel; it can reuse Trammel's models and most of its terrain.
- Malas, Ilshenar, Tokuno: much smaller.
- Whole world: target under about 10 GB.

These are estimates until the first compact bake is measured; the measured figures replace them here.

## Implementation (31 October 2026)

- **No merged copies of placed models.** `DistrictBatch` merges architecture (walls, roofs, floors, stairs, fences and the like) and tiny procedural pieces only. Placed models (rocks, furniture, plants, scanned props; "asset" kinds) above 600 vertices stay placements, and `CompactDistrict` instances them.
- **Shared model library.** `BakeStreaming.shared()` writes every mesh of 300 vertices or more once, to `<prepared>/models/<content hash>.res`, and districts reference it.
  - The hash covers the geometry and the materials by content (materials are rebuilt per district, so their object identity would duplicate models).
  - Every later copy receives the same library object, loaded from disk if needed; taking over a path would strip it from the earlier holder, which then embedded a copy.
  - Writes are atomic (temporary name, then rename) for parallel bakes.
- **Compact collision** (`CollisionBuilder`):
  - solids above 300 triangles collide as an oriented box (client collision only serves the camera and mouse picking);
  - the terrain is a `HeightMapShape3D` of the heights at each tile corner (65 × 65 per district) instead of its subdivided render triangles.
- **Out-of-core facet bake.** `scripts/bake-facet.ps1 -Dataset outputs/<facet> -Modern [-Parallel 4] [-WindowTiles 512]` splits the facet into windows (8 × 8 districts by default) and bakes each in its own process with a one-district ring of context, so joined walls and roofs meet across windows.
  - The planner works in the window's bounds (a 4 × 4 window plans in 0.36 GB instead of 28 GB with full-facet bounds); its geometry is shifted into the dataset frame when saved.
  - Stamps make the bake resumable.
  - `FinalizeFacet.gd` then merges the windows' rule catalogs and writes the regional horizon and the index without planning anything.
- **Size report.** `BakeStreaming.gd -- ... --size-report` prints an estimated breakdown per saved district.
- **Tests.** `CompactStreamingTests` (in `scripts/verify.ps1`) checks:
  - architecture merges but placed models do not;
  - detailed solids get boxes and the terrain a 65 × 65 heightmap;
  - identical meshes become one library file;
  - tiny meshes stay inline.

**Measured on the densest test window** (16 districts of forest and Trinsic's outskirts, the area that held the 204 MB district):

| | Before | Compact |
|---|---:|---:|
| Median district | about 28 MB | 2.5 MB |
| Largest district | 204 MB | 6.3 MB |
| Bake time | | 3 s per district |

The model library for this window is 68 MB (671 models); it grows slowly, since models repeat across the facet. The remaining per-district bulk is the live-editing source data (about 1–1.5 MB) and exact collision for small architecture.

**Tools follow the active cache.** Developer editing and the audits read the cache through `LiveDistricts.prepared_folder()` (Trammel once baked, else Britain), never a fixed path.

## Next compression steps (owner decision 31 October 2026: apply on the next bakes)

The first full Trammel bake keeps the format above, so the map can be tested. It projects to about 6 GB (3,004 land districts at about 1.27 MB, 4,164 empty or ocean districts at about 0.29 MB, and a shared model library of 1–1.5 GB). The next bakes of any facet must add these steps, which together target about 3 GB for Trammel:

1. **Ocean and empty districts: about 1.2 GB down to about 50 MB.** Flat water is one shared piece, with a heightmap only where the seabed matters, instead of full terrain and collision per district.
2. **Live-editing source data: about 1.5 GB less.** The per-static vertex positions used to hide or move objects in game are packed tightly (quantised, delta-coded), or read from the converted source data on demand when editing is enabled, instead of plain vertex lists in every district.
3. **Mesh vertex compression: 30–40% off geometry.** Library models, terrain and architecture are saved with Godot's vertex compression (16-bit positions, compact normals and tangents) where it is visually lossless at game distances.
4. **Tighter model deduplication: the biggest saving, do it first.** Models that differ only in material variants share geometry, with the variant applied as a material, so the library grows less.
   - Measured on the first full Trammel bake: the library reached 6.0 GB with 35,378 entries at 6,027 of 7,168 districts, against 5.6 GB for all the district files. Trammel has nowhere near that many distinct models.
   - Likely cause, to be confirmed: pieces reshaped or recoloured per spot (terrain-fitted, per-placement vertex colour, trimmed to a neighbour) each hash as a new model.
   - The fix: hash the source model and keep per-spot changes as transforms or material parameters. One-off pieces used in a single district stay inline instead of in the library.
   - Target: library well under 1 GB.

The stamp-based bake rebakes only what each step changes. A step is done when its measured saving is recorded here.

## Compression pass for the second bake (31 October 2026)

**Measured first:** what the 14 GB actually is. A sample of 80 districts plus 2,500 library models showed the library was not duplicating models: 93% of its bytes were meshes unique to one district. Projected over Trammel:

| Part | Size |
|---|---:|
| District files | 5.4 GB (in a city district, mostly exact collision triangles) |
| Terrain | 3.9 GB (unindexed triangle lists) |
| Small scanned models merged vertex by vertex into each district | 2.6 GB |
| Instanced and foliage sources | 2.3 GB |
| Sea | 0.1 GB |

**Changes, step by step:**
- **Step 4, deduplication (the real cause):** a model loaded from the art library is always instanced (`DistrictBatch`), however small. Only generated pieces and architecture merge.
- **Step 1, ocean:** sea runs along each row become one quad (an open-sea district goes from 4,096 cells to 64 quads). Flat sea bed is not subdivided.
- **Step 3, vertex compression, applied as indexing:** terrain and sea are indexed, so each grid point is one vertex: about 6× fewer vertices and half the bytes.
  - Godot's attribute compression saved only 12% more. It quantizes positions to each mesh's own bounds, so district edges no longer met exactly (`RegionalSeamTests`), so it is not used.
- **Collision:** solids more detailed than a box (over 12 triangles) collide as their oriented box. Arches, doors, stairs, landings, bridges and fences keep exact triangles up to 300.
- **Step 2, live-edit data: kept exact.** Hiding a static must not read back from the GPU, and undo must restore the exact baked vertices (`DevEditTests`), so the stored positions are not quantized. They shrink anyway, because instanced models no longer need them.
- **Clean-up:** `FinalizeFacet --prune-models` removes library models nothing references after a rebake in place (`scripts/bake-facet.ps1` passes it).

**Measured on sample districts** (district file plus the library models it references):

| District | Before | After |
|---|---:|---:|
| Open sea (1472,1792) | 470 KB | 145 KB |
| Coast (1536,1984) | 4.5 MB | 4.1 MB |
| Britain (1472,1600) | 5.0 MB | 4.0 MB |
| Covetous mountains (2432,896) | 6.2 MB | about 3.8 MB |

**Second full Trammel bake (31 October 22:05 to 1 November 00:33):** with the taller mountains (docs/MOUNTAINS.md) and the invisible entrance blockers. 7,168 districts in 112 windows, two at a time; `FinalizeFacet --prune-models` removed 25,610 unreferenced old models (6.74 GB).

| Part | First bake | Second bake |
|---|---:|---:|
| District files and horizon | 7.13 GB | 3.2 GB |
| Shared model library | 7.3 GB (41,911 entries) | 2.1 GB (24,025 entries) |
| **Total `prepared-modern`** | **14 GB** | **5.3 GB** |

- **Re-stamping:** Codex edited creature, bird, corpse and water-elemental presentation mid-bake, so 7,104 districts were re-stamped with `--accept-unchanged`. None of those files build terrain, statics or architecture.
- **Exit codes:** the driver read Windows PowerShell 5.1's empty exit codes as failures. It now takes each process handle and also accepts a window whose log has its completion line.

## First full Trammel bake (31 October 2026)

All 7,168 districts, the dungeons in the east included, baked with `scripts/bake-facet.ps1` (112 windows, two at a time) and published by `FinalizeFacet.gd`.

| Part | Size |
|---|---:|
| District files (near) | 7.08 GB |
| Middle distance (far) | 0.05 GB |
| Shared model library | 7.3 GB (41,911 entries) |
| **Total** | **14 GB** |

- Old format at the same density: well over 200 GB.
- The library is the remaining problem: see next step 4. Fixing it should bring the total to about 7 GB; with steps 1–3, about 3–5 GB.

**Bake time:** about 3 hours of baking at 35–45 districts a minute. Claude Code stopped the driver twice under memory pressure, so the last run was started as its own process.

**Finalize:** `FinalizeFacet.gd` publishes without planning, so a facet has no district limit. Its `--accept-unchanged` re-stamps districts whose files exist after a code change verified not to touch map geometry. It was used once: Reconstruction.gd gained a corpse branch for dynamic items mid-bake, and 5,632 districts were re-stamped.

**Checks:**
- `scripts/test-streaming.ps1 -Route trinsic` passes on the Trammel cache: 54 district stops with collision and scenery, a memory plateau of about 840 MB, p95 frame 30 ms.
- Renders of Moonglow and the Covetous area are in place.

**Lesson:** a facet bake takes hours, and every district's stamp covers the bake code. Concurrent edits to that code (Reconstruction.gd, BakeStreaming.gd and their dependencies) mark finished districts out of date, so avoid them during a bake.

## Status

- Trammel is converted (`outputs/trammel`), baked (`outputs/trammel/prepared-modern`, 5.3 GB since 1 November) and its server world is populated (`scripts/populate-trammel.ps1`). The client streams it by default.
- The earlier Britain and Britain-to-Trinsic caches (old format) are superseded.
