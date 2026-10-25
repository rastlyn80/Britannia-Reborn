# Britain graphics and traversal checkpoint — 25 October 2026

## Delivered

The existing 64×64 Trammel crop now has explicit rules for all 187 used static IDs in Viewer/Presentation/static-catalog.json. All 2,689 source records are accounted for: 2,645 visual owners and 44 grouped contributors (26 canopies, 12 bed parts, six arch parts). No crop IDs fall back to diagnostic cubes. The ignored local-static-coverage.json records every original ordinal, ID, XYZ, target kind/asset, axis, confidence and group owner.

Mapping includes walls and windows with reference-derived axes, corners, posts, trim, beams, floors, connected roof/ridge surfaces, stairs/landings, fences, doors, beds, tables/counters/benches, carpets, painting/sign brackets, logs, mushrooms, rocks, species-dependent trees, flowers, grass and water. All original records remain unchanged. Trunks and crowns form one tree; bed components form one footprint; paired arch components form one opening.

Quaternius remains the primary architecture/nature source. Missing furniture uses the audited free Kenney Furniture Kit under its bundled CC0 notice, with hashes and source URL in Viewer/Art/Kenney/manifest.json. Procedures supply roof surfaces/material detail, stair steps, carpet patterns, painting and sign brackets. Runtime foliage disables wind-weight vertex tint and uses the supplied green palette for red twisted-tree leaves. Water ripples use world coordinates to avoid seams between source tiles. Source art is inspected locally through the C# ArtReference command; resulting images stay ignored and are never game assets.

This is coverage, not a claim of perfect original-art reproduction. Modern style, dimensions, materials and silhouettes are substitutes. The catalogue explicitly records confidence; post 0x1296 remains a metadata-based substitute needing further silhouette review. Floor-border variants, individual gable/hip details, species exactness and certain furniture/shore contours can still improve. Other regions may contain IDs absent from this catalogue and will remain diagnostic until mapped. Source game art and game-derived images are not redistributed.

## Camera and controls

Actual reconstructed solid meshes and terrain generate 91,416 collision triangles in chunked StaticBody3D bodies. A spherical SpringArm sweep retracts the camera before geometry, with margin, smooth distance recovery and a near clip plane suited to interiors. Full yaw, pitch from -1.5 to +0.9 radians and zoom 1.2–22 units are available in character mode. Extremely close camera positions hide the local body/nameplate rather than placing the view inside the head. Foliage and water do not obstruct the camera; solid architecture, furniture and terrain do.

WASD moves relative to the camera; Shift sends real UO running requests. Mouse drag with either button orbits; wheel zooms; Space performs a ceiling-aware animated hop; B opens the backpack. Gamepad sticks, stick-click running and A jumping are wired but have not been hardware-tested.

Character roots use the same tile centres as the static footprints, with canonical server XYZ retained. Queued interpolation stores each walk/run segment duration (410/210 ms) so transitions do not distort earlier segments. Facing, speed-scaled idle/walk/jog/sprint and take-off/air/landing animations blend. Camera tracking follows the rendered character. Classic per-step resync remains for exact server elevation and remains inefficient.

The jump is a local presentation action with gravity, overhead capsule sweep, ceiling clamp, no double-jump and exact return to the current confirmed ground. It does not change server Z, clear server obstacles, affect combat/line of sight, or replicate a jump to other clients. A physical, replicated jump needs an isolated server extension; no server source changes were made in this pass. Walking/running remain eight-direction UO movement with continuous rendering, not arbitrary-angle authoritative physics. Doors are static geometry at this checkpoint; interaction is separate work.

## Verification

- scripts/verify.ps1: 73 checks (19 converter, eight login, 16 game session, 11 presentation, 19 graphics), asset import and real world load pass. Build has no warnings/errors.
- Graphics checks cover every source anchor, grouped-tree ownership, real collision generation, original UO run bytes, duration transitions, roof boundaries, foliage palette, jump lifecycle/ceiling/frame rate, thin-wall camera sweep and recovery.
- scripts/test-play.ps1: real login/entry, wall rejection/correction/recovery and backpack pass after these changes.
- scripts/test-graphics.ps1: actual keyboard running to a known Britain corridor wall, retraction to about 0.697 units, Space jump apex about 0.95 and landing pass. This test assumes the existing test character is in the x1600 corridor and performs ordinary server-approved travel; it does not teleport.
- The earlier production-scene two-character keyboard visual test also passed during this pass. Physical gamepad, sustained latency/stress and cross-platform tests remain pending.

Evidence stays in ignored outputs/validation: graphics-overview.png, camera-wall.png, jump-apex.png, britain-map-comparison.png, local-static-coverage.json and graphics-verification.log. Original references are local-art-reference.json and static-reference-*.png; do not package them. The existing server remains running. An early live camera test failed because the character had moved beyond the chosen wall; the test now walks to a verified solid wall before checking collision.

## Reproduce

Launch.cmd imports assets and opens the normal client. For a fresh art setup, run scripts/fetch-art.ps1, scripts/prepare-art.ps1 and scripts/prepare-furniture.ps1, then scripts/verify.ps1. Archives are pinned by SHA-256. The checked-in catalogue is the runtime mapping source; scripts/update-static-catalog.ps1 is the baseline authoring utility, not a command to overwrite future manual overrides casually.

scripts/test-graphics.ps1 exercises live traversal; scripts/capture-radar.ps1 refreshes the original-colour map comparison. For a local coverage/overview capture, run Godot with --path Viewer -- --hide-ui --screenshot=ABSOLUTE_PNG_PATH --coverage=ABSOLUTE_JSON_PATH. The converter's reference DATA_DIR WORLD_JSON OUTPUT_JSON command and StaticReference.gd provide local-only source tile contact sheets for further mapping review.
