# Owner-reported Britain defects (queued after the catalogue matching) — 27 October 2026

From the owner's in-game screenshots; fix with shared rules, then verify in captures:
1. Wall caps 102/108 (stone wall pieces whose later tiledata names are "ornate elven bookshelf"/"ethereal voyage scroll") render as a bookcase/book on wall corners (14 + 2 in Britain). Wall-flagged graphics must stay masonry.
2. Castle entrance just after the wooden drawbridge: the main gateway (between two arched side doors) is walkable in the source/server but is drawn as a solid wall; it must be rendered as an open passage. Find the passable gate cells under the wall run and open them. Compare rendered walls/collision with passable source arch cells (208/209/111/113/320 are passable, 206/207 piers impassable).
3. Stone arches (206-227, 110-113, 317/320) use the Quaternius wooden Wall_Arch frame; build them in masonry of the wall family.
4. Gatehouse: stacked "stone post" 204 render as thin detached poles above the roof, mixed wood/stone. Render posts as square masonry piers matching the walls, and check what the top-level pieces really are.
5. Floating pieces on towers above crenellations; gaps between walls and roofs; an unexplained opening in a building.
6. Clunky "York" houses: over-dense studs; dark plank houses with white plaster bands around windows.
7. Road signs: two boards on one post have broken geometry; street names must be shown on the boards permanently, not only on click.
8. White plaster panels over doorways and openings in brick (and other masonry) walls; lintel/infill pieces must take the wall's own family.
9. Britain castle: roof fragments out of place on towers and wall tops (timber roof slabs hanging off battlements, white dashed lines along wall faces).

Approach: every fix is a shared rule plus an automated whole-map audit (floating pieces with nothing beneath, roofs not resting on walls, wrong-family infill, rendered walls on passable cells and open cells on impassable ones), so the same defects are found and prevented automatically as the map expands, not fixed building by building.

# Next after the item catalogue — 27 October 2026

Use the catalogue ranking to choose replacement families. Next: model naming rule (`Art/Modern/<category>/<family>.glb`) with automatic registration, isometric silhouette fitting/flagging against the original art, picture-similarity and mirror grouping, and a family override file. Then equipment appearance on the shared Quaternius skeleton (skinned garments with body-region hiding and hue masks; socketed weapons and shields).

# Next after character sheet/skills — 27 October 2026

Character sheet, skills and vitals HUD are live on native packets. Next gameplay presentation: an equipment paperdoll in the sheet (worn layers, drag to equip), skill-gain/stat-gain notices, war mode and a combat target/health bar for the selected mobile, then spellbook/casting. Keep the starting-up cost and the ~135 ms first-frame stall in view.

# Next after the free visual upgrade — 26 October 2026

Free shader/lighting work has reached diminishing returns. Next: an art-kit comparison page (same Britain street, 2–3 candidate kits with exact prices/licences) for an owner decision, then building geometry depth (roof eaves thickness/overhang, recessed windows, door surrounds) through the shared facade/roof rules, and replacement trees with LODs. Keep paid assets out of the public repository.

# Next after bridge/contact checkpoint — 26 October 2026

Bridge parapets/piers, generic masonry window names and wall-hung attachments are fixed through shared rules (see PROGRESS.md). Next: re-run the context-aware contact audit and resolve bar/shelf support heights; profile and reduce district-loading stalls with same-route before/after measurements; then a lighting/material upgrade and an owner-approved art-kit comparison before broader artistic work.

# Art-first next gates — 26 October 2026

The first shared replacement pass is implemented and inspected; see ART_CATALOGUE_PASS.md. Next: (1) resolve rendered bridge approaches, hanging attachments, remaining unsupported candidates and simplified architecture/materials through targeted captures; (2) extend reviewed per-graphic choices across Britain, prioritizing frequently visible exterior/interior items; (3) reduce district loading/upload stalls before further expansion. Keep catalogue status honest: 108 explicit choices / 88 reviewed does not mean all 1,597 static IDs are artistically approved. Source-level warnings are inspection candidates, not automatic repairs.

Live Britain checkpoint (2026-10-26): Launch.cmd now connects native gameplay to the converted 704×512 city, with nine physical districts, shared source-relative coordinates, full-city movement prediction, native movement packets and far scenery. A graphical development-account test completed 62 server-accepted run steps across x=1600 and beyond the former y=1568 boundary, reconciled exact XYZ (1599,1567,20), then returned home through the native recovery command. District retention/eviction and physical terrain checks are automated. Population/commerce remains concentrated in the original patch; combat, skills and city-wide native population are not claimed. See LIVE_BRITAIN.md.

Current mapping/seam checkpoint (2026-10-26): all 1,597 Britain IDs / 136,662 static records have explicit shared rendering coverage, with honest semantic-substitute confidence. Joined full-region plans feed both a city architecture bake and nine nearby draw chunks. Shared terrain/roof normals, floors, ceilings, UV phase, stable grouped ownership and source-based overhang switching address district seams. New props and stone/thatched/flat-roof families replace missing markers. Source/context parity, 357 offline checks and graphical boundary/reload checks pass. Live gameplay/population is still the original patch. See BRITAIN_MAPPING_AND_SEAMS.md for evidence, first-plan timing and remaining art/production limits.

Latest scope clarification: the requested expansion is the whole **city of Britain**. Explore-Britain.cmd (and the retained Explore-Britannia.cmd alias) now opens the native city bounds including castle/western outskirts, rounded to 704×512 / 88 chunks. All 360,448 terrain and 136,662 static records pass independent source parity. The city overview renders 42,382 simplified architectural/tree features; close-detail art and chunk seams remain unfinished. Live gameplay/population stays in the proven patch. See BRITANNIA_EXPLORER.md.

Latest: saved-world recovery and native commerce now pass headless and graphical checks. Full Britannia geographic conversion/overview is available via Explore-Britannia.cmd; all source records pass independent parity. Next gates: expand 3D mappings beyond the 187-ID reference catalogue, assemble architecture across chunk boundaries, then connect streamed gameplay/population. The full-world explorer is not full-world multiplayer.

Current priorities after the Britain mapping/seam pass:

1. Live city movement/collision is connected and a native boundary route passes. Extend traversal checks to castle, docks and varied elevations; reduce startup and district frame stalls.
2. Expand native doors, signs, containers and vendors in bounded, auditable city batches; retain the existing population limits until that work is explicitly implemented and validated.
3. Extend native gump/action coverage, selling and wardrobe presentation beyond the verified interaction loop.
4. Review rare prop/landmark art, first-detail planning time and neighborhood performance. Semantic mapping coverage is not exact bespoke artwork fidelity.

# Roadmap

Immediate priorities after the prepared streaming/minimap pass (26 October): (1) reviewed exterior AND interior fidelity for one representative Britain block, including floating/misrepresented objects and contextual materials; (2) further reduce measured loading/upload spikes and partition offline world topology; (3) then extend regions and native gameplay. Preserve the shared conversion rules. Directional sign text-on-surface idea is recorded in ART_FIDELITY.md. Source-ID coverage is not visual approval. See STREAMING_AND_MINIMAP.md and CLASSICUOMOSHU_REVIEW.md.

| Milestone | Status | Acceptance / remaining work |
|---|---|---|
| 0 Audit | Completed for imported code/dependency inventory | Baseline tests and architecture documented |
| 1 Authentic conversion | Implemented/tested for small Trammel base+diff crop | 15 parser checks and real viewer load pass; independent in-game comparison outstanding |
| 2 ModernUO integration | Godot and native ClassicUO entry verified locally | Compressed game login, character creation/selection and actual spawn pass; ClassicUO observer and Godot primary both entered the running server |
| 3 First playable multiplayer | Local proof of concept implemented and tested | Real character entry, ACK/wall rejection, two-client movement observation, backpack opening/contents and actual keyboard-driven scene pass |
| 4 Reconstruction | Britain city mapping and seam pass verified | 1,597 IDs / 136,662 records mapped; joined roofs/walls/floors/terrain, source-based ownership and nine detail chunks. Exact art matching and other-region coverage remain |
| 5 Gameplay presentation | Native objects, commerce and inventory verified in reference patch | Gumps, buying/payment, container/ground transfers and equipment pass. Selling, full wardrobe, skills/combat/spells and expanded city population remain |
| 6 Full facets | Britannia geography/overview implemented | Full main-landmass binary chunks and independent source parity pass; live streaming now covers Britain city. Other regions, population and traversal coverage remain |
| 7 Platforms | Planned | Desktop exports, Android controls/performance, then Apple signing/testing |
| 8 Polish | Graphics/traversal pass implemented/tested | CC0 environment/furniture, camera collision, real run, local ceiling-aware jump and animation; physical replicated jump, equipment and further polish remain |
| 9 Production | Planned | Security, load tests, backup/restore, updates and operations |

Current slice complete: bounded source-backed prediction, rest-pose retargeting/continuous facing, connected roof/facade construction with corrected roof anchors, source material polish and server recovery tools. Next: strengthen latency/reconnect behavior, add foot IK and equipment presentation, then an item pickup/drop path. Numeric facet/file profiles, input bounds/provenance, independent map comparison and ClassicUO coexistence remain explicit debt. See PLAYABLE_POC.md for exact scope.

Input/login correction: mouse capture/release and focus handling tested; controller input requires opt-in; last Windows login is encrypted and prefilled. Visual material/lighting pass improves readability; faithful architectural silhouettes, roof joins, terrain materials and character art remain explicit presentation work.

Latest evidence: 117 offline checks; live six-step walk/run with exact server reconciliation and a second client observer; saved-account recovery to the Britain start; roof/wall centre and shared-edge tests. See STREET_MOVEMENT_PASS.md.

Visual quality target: polish one complete Britain building plus its street as the reference scene before extending the art treatment. Priorities are joined architectural volumes and supported props; bevels/proportions and higher-quality furniture; coherent surface scale, roughness and material variation; interior/exterior lighting and shadows; natural ground/foliage transitions; then character animation/foot contact and camera polish. The source grid is geographic input, not a requirement for visibly blocky final geometry. Current captures are reconstruction evidence, not a finished-art target.

Shared visual pass implemented: topology-based explicit/implicit corners, narrow storey seams, complete wide arches, unsupported gable suppression, bevelled timber props and bounded wind/water shaders. See VISUAL_PASS_02.md. Larger-map ID coverage and chunk-halo ownership remain unverified; art quality is still in progress.

Material/terrain/lighting pass: Forward+ default plus compatibility launch; verified CC0 PBR surfaces, source-constrained adaptive banks and wet-edge blending, glass/rafters/interior lighting, and verified live-clock wind/water. Reference district improved; larger-region silhouettes, asset mappings and neighbor-halo streaming remain next validation work. See VISUAL_PASS_03.md.

Interior/contact pass: closed source-height floor slabs and conservative void repairs; diagonal corner returns and wall-to-ceiling seams; roof/basement liners; corrected stair direction/bridge blocks and cardinal prediction; bounded post-animation feet, phase-preserving gait blends, camera trunks/recovery/leaf clearance; nearest-storey lamp cables and isolated natural peak filtering. 196 offline checks (final ceiling fixture separately after full run), six GPU animation checks, live development-account entry, both renderers and new captures. Shared rules carry forward for mapped families; native stair parity, larger-region coverage and full foot locking remain unverified. See INTERIOR_CONTACT_PASS.md.

Conversion pipeline and floor stability: end-to-end conversion now bakes the shared reconstruction rules and records rule/source hashes plus repair coverage. Stair supports/decks share the tread PBR material. Separated basement ceiling tops from ground floors and introduced single ownership for coincident terrain/static/duplicate floor surfaces. 201 offline checks and real conversion/bake/reload evidence; see CONVERSION_PIPELINE.md.

Reproduced doorway flicker with moving GPU captures: lower-storey wall caps intersected upper floors. Tall facade caps no longer render through floors; sills/gables retained. Constructed indoor land floors replace blended landscape floors, screen-space leakage disabled, and connected coastal spurs use a two-cell source halo. Visible crop unchanged. 205 offline + four GPU stability checks, full conversion/bake/reload and compatibility pass. See GLITCH_STABILITY_PASS.md.

### Britannia Reborn public checkpoint

Canonical repository: https://github.com/rastlyn80/Britannia-Reborn. Original project code: GPL-3.0-or-later, with retained third-party licenses. Server-driven regional clock/light/weather, improved sky/clouds and sheltered precipitation are implemented; details in SERVER_ENVIRONMENT.md. Next: bounded upstream world population and server-owned item rendering/interactions, then expand and validate conversion seams. No full-world population, full facet conversion or production readiness is claimed.

### Native world-object checkpoint

Whole streamed city now populated (4,489 server root items incl. 377 door leaves and 121 signs; 27 Oct 2026). Original slice: 131 decorations + 12 door leaves + 5 signs; 8 single doors and 2 linked double pairs; 65 native containers. Repeat population preserves open doors and creates zero duplicates. Real mouse interactions and actual building names pass in both renderers; shared doorway proportions and item lifecycle have 30 regression checks. Next: systematic ClassicUO placement/behavior comparison, then a larger region and chunk seams. No map expansion or NPC spawning occurred. See WORLD_OBJECTS.md.
