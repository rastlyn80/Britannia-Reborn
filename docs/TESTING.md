# Bridge/attachment/contact checkpoint — 26 October 2026

`scripts/verify.ps1`: **447 offline checks**, no errors/warnings. ArtFidelityTests adds 26 checks: bridge deck/pier/parapet detection at two translated origins, plaster/off-bridge exclusions, barred slit without timber casement, canonical source immutability, inspected window/battlement families, wall-torch attachment and west-face mounting, unmounted torch preservation, unreviewed-table, rug and barrel-stack contact, and an unresolved support case. `PreparedAudit.gd` parity passes (360,448 / 136,662 / 88 districts). `scripts/test-city-render.ps1` and `-Compatibility` pass 262 GPU matrices and 25,200 ownership pixels. `ArtBlockCapture.gd` now accepts `--view=name:x,y,z:tx,ty,tz` for targeted local inspection. The refreshed full-city ContactAudit, native object/traversal tests and streaming measurements were not re-run in this checkpoint.

# Reviewed art checkpoint — 26 October 2026

`scripts/verify.ps1`: **420 offline checks**, no errors/warnings. Includes 22 art-fidelity/contact checks and 34 world-item checks. Props: 35 models / 84 source files checked against pinned SHA-256; surfaces: 27 maps verified. Prepared parity: all 360,448 terrain samples and 136,662 statics across 88 chunks. Both GPU renderers pass all 262 first/last instance matrices and near/far ownership (25,200 unchanged wall pixels).

`scripts/test-world-items.ps1` passes native doors, repeat population, containers/books, sign name, dice, bulletin board and server Help gumps. `-Visual -Compatibility` also passes actual mouse clicks and records local screenshots. Initial runs encountered stale/consumed development fixtures and open-door targeting; after the existing population refresh and fresh run, the complete sequence passes. No user credentials, account, saved-login vault or server code were changed.

`scripts/test-live-city.ps1 -Visual` and `-Visual -Compatibility`: native entry, door use, 62 accepted run steps, exact reconciliation, minimap and recovery pass. Isolated Forward+ walking p95 **17.224 ms**, maximum **1,169.394 ms**; OpenGL p95 **17.058 ms**, maximum **1,202.135 ms**. An earlier concurrent/stale-test run had ~1 s p95 and is excluded from the isolated comparison, not represented as a successful performance result.

`scripts/test-streaming.ps1` repeated 14-destination journeys retain nine source/physical districts and bounded far scenery, with a memory plateau:

| Renderer | Prepared startup | End memory, lap 1 / lap 2 | Nodes | Frame p95 / p99 / max | Max activation |
|---|---:|---:|---:|---:|---:|
| OpenGL | 3.343 s | 317.15 / 317.17 MiB | 2,947 | 54.797 / 177.138 / 445.642 ms | 116.745 ms |
| Forward+ | 3.334 s | 434.57 / 434.59 MiB | 2,947 | 56.850 / 169.859 / 1,755.064 ms | 102.118 ms |

These are Godot engine allocation monitors, not OS working set or total GPU memory. Peak allocations were ~396 / 516 MiB. Rapid destination jumps intentionally stress loading; they are not steady walking FPS. Against the previous prepared checkpoint (~311 MB OpenGL / ~430 MB Forward+ retained), richer art increases resources modestly while bounded retention survives. Significant loading hitches remain.

`Review-Art.cmd` generates ignored local source/model references and captures. Eight fixed reference views were compared with baseline `2598368`; riverbank and bridge views extend current inspection. This offline snapshot rendering is separate from native multiplayer checks. See ART_CATALOGUE_PASS.md for review coverage and explicit visual limits.

Live Britain streaming: `scripts/test-live-city.ps1` checks physical district installation, retention/eviction, an actual development-character route, native door use, exact position reconciliation and recovery. `-Visual` adds a local screenshot; `-Visual -Compatibility` uses OpenGL. Fourteen readiness/protocol/batching checks are included in `scripts/verify.ps1` (371 checks total). The existing login test still verifies only the login relay; the city test enters the real native world. A separate `scripts/test-city-render.ps1` / `-Compatibility` checks 25,200 daylight wall pixels for far/near overlap; it opens no native session. See LIVE_BRITAIN.md for scope and evidence.

# Testing

Current suite: 120 offline checks plus converter/isolated recovery-extension builds, import and real crop load. New tests cover source-JSON prediction, turn/ACK/rejection/elevation fallback, 360-degree facing and wrapping, retargeting/leg contact heights/stride cadence, continuous façades, real shared roof edges and roof/wall centring, native Unicode command framing, crop bounds and recovery state. Live scripts/test-locomotion.ps1 confirms before-ACK prediction, exact server XYZ and two-client observation; scripts/recover-character.ps1 confirms the latest saved account is returned by the server. See STREET_MOVEMENT_PASS.md. The older paragraphs below are historical.


Latest suite: 73 checks (19 converter, eight login, 16 game-session, 11 presentation, 19 graphics) plus import and crop smoke pass. Graphics adds complete ID/ordinal/XYZ accounting, grouping, run bytes/timing, roof boundaries, real camera collision/recovery and ceiling-aware jump tests. scripts/test-graphics.ps1 passed actual keyboard running, obstruction against a real Britain wall, jump apex and landing; scripts/test-play.ps1 passed wall rejection/recovery and backpack. See GRAPHICS_PASS.md for limits and evidence. The 54-check paragraph below records the earlier checkpoint.

scripts/verify.ps1 builds the converter, imports art, runs 19 parser, eight login, 16 game-session and 11 presentation tests (54 total), then loads the real world headlessly. Current result: all pass. The playable region contains 4,096 samples and 2,689 statics; the earlier 2,304-sample crop is preserved separately. Added checks cover both tiledata flag layouts, intermediate XYZ, corners, rejection reset, frame-rate independence, source anchors and actual humanoid bone animation. See ART_AND_MOVEMENT.md for the first art pass and current live evidence.

Parser: block/cell ordering, origin, signed elevations, static ID/hue/position, unaligned crop, lookup3 empty input, raw/zlib UOP, MUL/UOP equivalence, incomplete diffs, terrain precedence, duplicate static replacement and truncation. Fixtures share the writer/hash implementation, so production map import is extra evidence, not an exhaustive independent oracle.

Login: seed/credential layout, fragmented independently assembled server-list bytes, relay endpoint/token, malformed lengths, rejection, unknown packets and lossy encoding. Game tests add independent Huffman bit vectors, split/coalesced streams, signed Z, creation packet offsets, version sizes, fragmented spawn, position/sequence resync, rejection correction, remote movement/removal and malformed framing.

scripts/test-play.ps1 verifies live character selection/spawn, real walking, wall rejection/correction/recovery and backpack. -Multiplayer uses two accounts and checks observer coordinates actually change; turning alone does not pass. -Visual loads the production scene, injects a physical W key, confirms actual position change, sees two rendered avatars and captures a screenshot with backpack contents. Creation was exercised against empty accounts and later logins reused those characters. See PLAYABLE_POC.md for assumptions, reconnect caveat and local state changes.

scripts/build-server.ps1 pins source and enforces package locks. Current server build: zero warnings/errors. Full upstream unit tests, established-client coexistence, sustained reconnect/load tests, client geometry collision quality, chunk seams and non-Windows exports remain outstanding. Server wall rejection and two-Godot-client replication now pass; source inventory still does not imply full gameplay validation.

capture.ps1 -Local renders the local map; images remain local. Logs: outputs/validation. Sandbox networking may need approval even for loopback. A timeout/fallback is not a passing integration test.

Contextual interior regression: `scripts/verify.ps1` includes tests for supported versus unsupported upper-level furniture, preservation of source coordinates, wall-supported versus relocated gables, and the actual screenshot's two records when local data is available. Godot `--script res://Presentation/InteriorCapture.gd` recreates the same ground-level view in `outputs/validation/britain-interior.png` for visual inspection. Current aggregate: 127 offline checks.

Current visual checkpoint: 135 offline checks via scripts/verify.ps1, plus three GPU animation checks via scripts/capture-visual-pass.ps1. Corner fixtures cover all orientations and translated locations; implicit joins and arch blockers are checked separately. See VISUAL_PASS_02.md for the current source/collision audit and remaining cross-region/chunk limits.

Current material/shore checkpoint: 150 offline checks, 21 pinned surface-file hash checks and six rendered animation checks. SurfacePolishTests checks source anchors, interpolation range/continuity, adaptive mesh coverage, overlap consistency, gentle support heights, signed shore data and PBR scale/origin. capture-visual-pass.ps1 recreates the GPU evidence and previews; PolishProbe.gd supports repeated fixed-view timing. Both Forward+ and compatibility district scenes were loaded; see VISUAL_PASS_03.md for limitations.

## Native world objects

Run scripts/verify.ps1 for 248 offline checks, including 30 world-item/doorway/sign regressions. With the local server and development character ready, run Populate-Britain.cmd once (it also checks a second run), then scripts/test-world-items.ps1. Add -Visual for actual mouse event injection and screenshots, or -Visual -Compatibility for the fallback renderer. The interaction test covers native single and double doors, preserves an open door across repeated population, opens populated and empty containers, inspects the actual localized building name and returns the development character home. Test-only PreviewVisit is loopback/bounds restricted; it does not move the user account. Local captures are ignored, not distributable artifacts. Full details and limitations: WORLD_OBJECTS.md.


Native object/gump checkpoint: scripts/verify.ps1 includes 21 converter checks (including synthetic gump RLE bounds/transparency), 18 gump checks, 20 item-response/appearance/target checks, 30 world-item checks and the existing suites: 288 total. Live scripts/test-world-items.ps1 covers the original single/linked doors, idempotent population while open, full/empty containers, native book title/28 pages, dice roll, bulletin-board opening, localized sign name and Help -> description -> Cancel. -Visual injects real mouse input for world objects and gump buttons; -Compatibility repeats using OpenGL. Screenshots remain ignored local outputs. scripts/test-play.ps1 verifies actual closed-door movement rejection and recovery in the populated world, returning the development character home. Login/relay validation remains scripts/test-login.ps1. No user account password is changed by these tests.

The native bulletin board is currently empty. Its non-empty message payloads and native target response bytes have synthetic coverage; posting, drinking/filling effects, item transfer and arbitrary gumps are not claimed live-validated. Local GumpArt decoding supports MUL and ordinary UOP/zlib, rejecting other compression modes. Exact font/hue parity is not claimed.


## 2026-10-26 interaction and full-landmass explorer

scripts/verify.ps1 passes 333 offline checks (including 7 binary-atlas, 22 commerce, 13 production UI and 33 world-item checks), with zero build warnings/errors. Live login relay passes. scripts/test-commerce.ps1 and -Visual pass native purchases/debits, ground/owned-container transfers, equipment and rejection paths. scripts/test-world-items.ps1 -Visual passes real mouse door/container/sign use, native dice/board scripts and Help/text-entry gump replies; The Salty Dog name remains clickable on the projecting sign.

The separate development ClassicUO profile entered the live street; single-click sign reply was The Wayfarer's Inn. This establishes recognizable placement/name comparison, not exhaustive native/client behavior parity.

scripts/audit-atlas.py independently compares all 20,971,520 terrain samples and 2,376,103 statics in the 5,120 exported chunks: pass. Whole-landmass overview and new district detail render in Forward+ on the local RTX 2070 SUPER. That district contains 2,596 static records, of which 581 still require art mappings and appear as gold markers. Full-world gameplay, new-ID art coverage and architecture chunk seams remain explicit gaps. Local evidence is excluded from Git; see BRITANNIA_EXPLORER.md.


City scope correction (2026-10-26): scripts/prepare-britain.ps1 derives bounds from the unique native Trammel Britain TownRegion. Independent all-record comparison passes for 360,448 terrain and 136,662 statics (88 chunks). Forward+ city overview renders 42,382 simplified architectural/tree features. Four additional distant-massing classification/elevation tests join the atlas regression suite. No live gameplay or native population scope changed.


Britain mapping/seams: scripts/verify.ps1 passes 357 checks, including 20 new seam/unknown-family regressions. scripts/test-britain.ps1 verifies 1,597 graphic IDs and 136,662 unique city source assignments plus exact all-record source parity for 88 visible and 42 context chunks. RegionalVisualCheck exercises nine joined chunks, six retained neighbors after crossing, exact terrain reload and zero unmapped records under Forward+. These are offline source/rendering checks, not expanded multiplayer. Evidence and reproduction: BRITAIN_MAPPING_AND_SEAMS.md.


## Prepared streaming and original radar — 26 October 2026

The current suite passes 397 offline checks, with zero build/runtime warnings or errors. It includes packed native source, headless instance roundtrip, transitive rule-cache invalidation and original-radar palette/Z/hue/zoom regressions. scripts/test-streaming.ps1 (also -Compatibility) exercises 14 prepared destinations, bounded residency and repeated-route memory plateau, recording actual wall-clock frame tails rather than clamped game delta. PreparedAudit.gd compares every native city record and incremental/complete scene placement. CityRenderCheck checks actual GPU matrices and 25,200 near/far ownership pixels. LiveCityCheck enters the real server and checks native door use, 62 accepted steps, exact server XYZ, actual GUI-wheel radar zoom with unchanged camera, map textures/coordinates and F6 recovery. Run both renderers; see STREAMING_AND_MINIMAP.md for evidence and remaining hitches.
