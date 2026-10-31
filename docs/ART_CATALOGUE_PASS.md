# Reviewed art and source contact checkpoint â€” 26 October 2026

This pass implements replacements in the shared reconstruction pipeline, rather than editing a particular house. The reference scenes cover the Salty Dog tavern, its basement and bedrooms, the neighboring inn and street context. Eight fixed-camera views were inspected against the same views rendered from commit `2598368`. These are local diagnostic renders using a saved native-decoration snapshot, not multiplayer evidence. Native interaction and city traversal checks are separate.

## Catalogue and actual rendering

`Viewer/Presentation/reviewed-catalog.json` contains 108 explicit per-graphic choices: 88 reviewed and 20 provisional. Of these, 55 select imported models; the rest document shared or original procedural construction. Not every imported library model is selected, and not every catalogue choice occurs in the current snapshot. The local inventory distinguishes actual imported rendering, procedural rendering, provisional substitutes and unresolved references. It currently inventories 1,597 static IDs / 136,662 placements, plus native decorations; native totals can change with server state.

Reviewed choices include table/bench assemblies, chair orientations, twin and canopy beds, empty/filled bookcases, drawer cabinets, crates, chests, barrels, bottles, books and small tabletop objects. Canopy beds retain original post/drape construction around imported beds. Wardrobes use original two-door timber geometry and iron fittings. Wooden tankards were rejected for pewter/skull mug source IDs: those retain their type-specific procedural models. Gameboards and pieces also retain their original distinct construction. Thus imported assets and code-generated assets both remain intentional parts of the project.

The existing Medieval Village library now supplies detailed window frames and door leaves. Native door facing, linked double pairs, source anchors, hinge animation and header planning remain authoritative; opposite leaves mirror the model so handles face the opening. The original projecting signs and locally extracted sign faces remain in use. Dressed stone and brick use appropriate additional PBR surfaces, with source/world-aligned physical texture scale.

Each choice records category, dimensions, pivot/orientation, attachment, assembly ownership, collision/LOD policy, confidence and provenance. Asset manifests provide the exact original files and hashes. A `reviewed` label records this limited source/model/context inspection; it does not certify every placement across Britain or establish a finished art direction.

## New redistributable inputs

- Quaternius **Fantasy Props MegaKit Standard**, CC0-1.0: 35 selected library models / 84 original source files. The bundled Standard licence was inspected. Archive SHA-256: `8b6f7e806d222e585478f0e1bdc6b271bbc7bc6f84dd6af8ca703a7c64f0cb1e`. Source: https://quaternius.itch.io/fantasy-props-megakit and https://quaternius.com/packs/fantasypropsmegakit.html . No paid edition was used.
- Four details from the already pinned Medieval Village MegaKit: door, window, open shutters and vine. Door/window are used; shutters/vine remain candidates.
- Poly Haven `medieval_blocks_03` and `medieval_red_brick`, CC0-1.0: six original 1K JPEG maps (albedo, OpenGL normal, roughness). Exact URLs, authors, physical dimensions, provider MD5 and SHA-256 are in `Viewer/Art/Surfaces/manifest.json`.

Model turntables exposed lost vertex colours in the imported props. The shared material preparation now enables their original vertex colours, preserves UVs and limits exaggerated metallic reflections. A cached runtime bottle-body colour variant preserves the cork. Downloaded model files remain unmodified.

## Contact and ownership

`SupportPlan.gd` identifies source-backed terrain/floor/furniture/small-object relationships. Native tile height identifies the contact; the reviewed model's dimensions determine its visible height. Same-cell support must match within one native elevation unit, or two for the known table/counter placement convention. Same-height gameboard/piece layering uses explicit ranks. Recursion is bounded and follows increasing height/rank. Upper-storey floor surfaces are recognized at the same source Z.

The adjustment moves the visual and corresponding pick body, preserving the native item root, XYZ, serial and server interaction. Unsupported candidates remain at their source position. There is no arbitrary cross-storey snapping. Table/bench/bed component groups retain one visual owner. Static baking and native dynamic items use the same choices and support policy. Dynamic changes invalidate contact results once per deferred batch.

The local full-city support scan inspected 1,409 relevant placements: 1,282 already supported, 74 presentation contact adjustments and 53 unsupported candidates. This includes provisional choices and placements that contextual reconstruction may suppress; it is not a count of confirmed visible floaters. The source geometry scan also flags 301 bridge/bank height relationships and six isolated corner candidates. Those require rendered contextual review; they are not proof of mesh defects or permission to move the source.

## Reproduce and inspect

Double-click `Reviews/Review-Art.cmd`. It verifies pinned art, prepares the shared city cache, audits all 88 source chunks, extracts local original-art references, renders 39 model candidate views and ten scene views, and opens a searchable comparison page. It uses the existing owned client-data path, or `scripts/review-art.ps1 -DataDir <your installation>`. Use `-Compatibility` for OpenGL or `-SkipCapture` to refresh the inventory without new captures.

`outputs/art-review/review.html`, its original-art images, source inventory, support findings and before/after images remain ignored local outputs. The report has every used ID, source counts, actual rendering method and choice details. Reference extraction is intentionally limited to reviewed/native IDs; remaining rows explicitly say reference pending. Before images are retained only when generated locally from the older checkout. Do not publish this report or game-derived screenshots.

Use `Launch.cmd` for live gameplay. Art/catalogue changes invalidate the prepared cache and the next preparation rebakes it; corrections are not stored only in generated scenes. `scripts/import-reviewed-art.ps1 -VerifyOnly` verifies the new props; `scripts/prepare-surfaces.ps1 -VerifyOnly` checks all 27 surface maps.

## Evidence and remaining quality gates

The full offline suite passes 420 checks, including 22 new art/contact assertions and 34 world-item assertions. Tests cover source-coordinate preservation, floors/stacks, unsupported cases, chair axes, normalized imported bounds, book orientation, vertex colours, bottle pigment isolation, grouped dimensions and mirrored native door leaves. Prepared source parity covers 360,448 terrain samples and 136,662 statics across all 88 chunks. GPU matrix and near/far ownership checks pass under Forward+ and OpenGL.

Native checks use only the development account. Headless object checks pass linked/single doors, repeat population, populated/empty containers, readable books, dice, bulletin board, Help gumps and return home. City checks pass 62 accepted steps across the district and former crop boundaries, reconciliation, minimap and recovery in both renderers. Initial object runs encountered stale/consumed decoration fixtures and a failed visual open-door target. After the existing population refresh and fresh run, complete headless and OpenGL mouse-input sequences pass; initial failures remain in local logs.

The block is a substantive first replacement pass, not a finished environment. Plaster and rugs remain visually simple, some metal colours and large furniture proportions need further art review, roof and bridge silhouettes remain provisional, and rare objects across Britain still use semantic substitutes. The ten views are not an exhaustive sweep of all rooms, bridges or material intersections. Source-level anomaly detection is conservative and does not yet prove wall/floor closure or arbitrary support intersections. More targeted bridge, hanging-attachment and suspicious-placement review remains necessary before extending artistic approval across the city. Keep this work ahead of region expansion.

Streaming remains bounded to nine nearby source/physical districts with instancing. Richer props increase retained resources modestly; detailed final renderer measurements are recorded in `docs/TESTING.md`. Activation/loading hitches remain and these checks do not establish production performance or full-facet scalability.
