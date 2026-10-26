# Britain mappings and district joins — 2026-10-26

## Result and scope

Explore-Britain.cmd now displays the city with joined source-backed architecture, the existing CC0 nature assets and nearby detailed districts. The city contains 136,662 static records / 1,597 graphic IDs. Every city ID now has a rendering rule or explicit nonvisual-marker handling; no city IDs remain unmapped. Twenty-five native light/no-draw helper records deliberately have no replacement mesh. The Town Cryer graphic was inspected locally and is rendered as a printed news sheet, not hidden as a marker.

This is complete **mapping coverage**, not 1,597 exact bespoke asset matches. The added models are modern semantic substitutes. Some rare props use shared family geometry, and newly encountered wall orientation/corners/roof slopes are inferred from source topology. Landmark silhouettes, stylistic proportions and individual prop detail still benefit from art review. Unknown future families remain visible gold diagnostics and fail coverage checks; they are never silently counted as finished models.

The change affects conversion/presentation. Native gameplay, account credentials, saves and the live population/movement boundary are unchanged. It does not implement the next proposed gameplay-expansion step.

## Shared implementation

- RegionalRules extends the existing audited ID catalogue from the owned tiledata metadata, preserving explicit rules. It covers masonry, paving, flat/thatched/slate roofs, stairs, dock planks, rugs, plants and furniture/prop families. CityProps supplies original procedural models including storage, display cases, fountains, cannons, instruments, lamps, food, tools and shop items. Native invisible helpers are accounted explicitly. Wall/corner connectivity, material families and flat roof handling are source-constrained. Stone/brick walls no longer acquire timber framing.
- The standard Reconstruction index uses those same rules, so the existing conversion/bake scripts and subsequent conversions inherit them. No house-specific edits are applied to generated scenes. Source XYZ, elevation, IDs and hues remain immutable.
- RegionalContext plans the complete city once, including four source-neighbor cells around its outer boundary. Facades, roof components, furniture assemblies, floor repairs, ceiling liners, terrain smoothing and the shore field no longer stop at a 64-tile draw boundary.
- Nine nearby draw chunks are retained. Crossing a boundary reuses the six overlapping chunks and replaces only the outgoing column/row. Terrain meshes meet on the same boundary vertices and normals; roof edge/corner heights and normals come from the shared component. Floor slabs keep native storey heights. Grouped furniture and multi-tile props have one stable source owner. Disposable height/report caches are bounded.
- A local architecture bake uses that same reconstruction for 67,587 source records, combined into 29 material batches. The city overview uses those joined meshes rather than building boxes. Distant forest instances use the pinned Quaternius CommonTree_3 mesh and its materials, with normal mesh LOD; nearby nature retains the existing detailed asset/wind treatment.
- Far/near replacement follows the **canonical source chunk**, encoded in UV2 for baked architecture and instance data for distant trees. A roof's overhang cannot cause half of its model to be removed, and both representations cannot own the same model at once. Terrain uses exclusive spatial masks. World-space texture/water phases use a single coordinate origin.

## Reproduce

1. Run scripts/prepare-britain.ps1. It converts the 88 visible chunks plus 42 neighboring context chunks, then bakes joined architecture. All generated geography, caches and scenes remain in ignored outputs/britain.
2. Double-click Explore-Britain.cmd. The launcher checks the bake fingerprint against source metadata and presentation code, rebuilding only when needed. Zoom close or choose Britain district to load detailed neighbors.
3. Run scripts/verify.ps1 for fixture/parser/presentation regressions.
4. Run scripts/test-britain.ps1 for all-city mapping/unique ownership and independent byte/record comparison against the owned UO files. No game login or character mutation occurs.
5. For rendered transition checks: run the local Godot executable with --path Viewer --script res://Presentation/RegionalVisualCheck.gd. These are offline rendering tests, not multiplayer.

The first detailed city plan takes about 20 seconds on the current machine. It is retained for subsequent district changes. Initial conversion/baking also takes time; the cached city overview avoids rebuilding architecture on every launch. This remains an exploration prototype rather than production streaming performance.

## Evidence

- Every one of 360,448 city terrain samples and 136,662 statics matches the owned base+diff inputs. All 42 context chunks also match independently: 172,032 terrain samples and 34,409 statics. Reports: britain-parity.local.json and britain-assets.local.json. The reviewable per-ID asset/model/confidence registry is britain-id-mapping.local.json; it remains local source-derived data.
- All 1,597 representative source graphic IDs were exercised through the shared renderer. Every city source record has exactly one draw-chunk assignment; native duplicates remain source records with shared visual owners where appropriate.
- Seventeen new seam regressions plus future-unknown-family and missing-tiledata guards, including safe fixture movement indexing cover terrain geometry/normals, roofs, reload stability, floors, corners, source ownership/overhangs, materials and coordinate phase. The full verification suite passes 357 checks. The original synthetic 48x48 IR also loads without tiledata or script errors.
- The full-city overview also renders under OpenGL compatibility. Forward+ rendering demonstrates nine joined districts, six retained on crossing the boundary, exact terrain rebuild after eviction and zero unmapped city records. Screenshots: britain-seam-west.png, britain-seam-east.png and britain-city-complete-mappings.png in local outputs/validation.

No new external assets were downloaded. Existing Quaternius, Kenney and Poly Haven sources, hashes and license notices remain authoritative in their manifests. New procedural geometry/rules are original project code under GPL-3.0-or-later. Local reference contact sheets were used to inspect unnamed/marker graphics; they and all proprietary/derived map/art outputs remain excluded from Git.
