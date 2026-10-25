# First art and smooth-movement pass

Implemented and verified on 25 October 2026. Launch.cmd remains the entry point; no server gameplay changes.

## Imported art

Free Standard editions by Quaternius: Medieval Village MegaKit, Stylized Nature MegaKit, Universal Base Characters, Universal Animation Library and Modular Character Outfits – Fantasy. Their archive license files explicitly declare CC0-1.0. Original URLs, archive hashes and selected file hashes are in Viewer/Art/Quaternius/manifest.json; bundled notices remain beside it. No paid editions or Kenney fallback assets were used.

scripts/fetch-art.ps1 acquires only zero-price downloads and verifies pinned archive SHA-256 values. scripts/prepare-art.ps1 copies the selected glTF/GLB files and dependencies. Two missing character normal-map aliases are corrected to existing supplied textures. The runtime masks the full body's lower geometry and attaches the peasant outfit to the shared skeleton. The manifest records these changes. Imported character appearance is fixed for all players; gender, race, hue and server equipment are not represented yet.

## World reconstruction

The C# converter now reads legacy 32-bit and modern 64-bit tiledata flags, names and static heights. Optional landData/staticData dictionaries and a tiledata hash extend the engine-independent JSON without changing canonical terrain/static records. Missing tiledata keeps explicit unknown diagnostics; unsupported layouts fail.

The current 64×64 play crop maps 2,133 of 2,689 placements. This includes floors, water, roofs, walls/windows with inferred axes, grass and supported nature/props. Nature models are instantiated only for matching local classifications; this crop does not imply that every imported tree/rock model is used. Unknown pieces remain 556 small gold markers (Tab toggles them). NODRAW terrain is skipped; other unknown surfaces remain a distinct neutral color. Grass/earth/paving/floor colors are classified, with original procedural paving/plank variation and directional shadows.

Each replacement retains source ID and XYZ metadata. Cell meshes are centred within their tile footprint without changing canonical source records. Wall axes use neighbouring wall/window connectivity; ties remain unresolved. Roof direction follows adjacent source roof elevations, with a minimum preview slope. Slate currently uses tinted round-tile geometry over a generated continuous roof bed: a style approximation, not a verified slate reconstruction. Geometry dimensions, corners, door openings, source orientations, stacked roof layers and independent landmark fidelity still require review. This is not a claim that a complete building is reconstructed faithfully. Do not use these provisional meshes as authoritative collision.

## Movement

The server retains discrete UO coordinates, movement acceptance and collision. The renderer traverses each confirmed segment linearly at every frame, including fractional XYZ and vertical transitions. Queued corners are visited in order. No extrapolation or client collision bypass is used. Teleports and large/bounded-backlog corrections snap; rejection clears pending presentation motion.

410 ms request pacing leaves a small margin above the upstream default 400 ms foot-walk delay. Per-step classic resync remains necessary for exact server elevation and remains inefficient. Timed segments replace exponential easing; the camera follows the updated render position in the same frame. Facing blends smoothly and idle/walk/jog clips crossfade, with animation pace following measured render speed. Animation root motion cannot move the authoritative avatar root.

Limitations: network delay can still create gaps; there is no prediction, arbitrary-angle authoritative movement, free continuous physics, capsule sweep, camera obstruction avoidance, stair foot placement or production anti-cheat validation. Input remains quantised to eight server directions. Further improvements must preserve server acceptance and add a tested height/collision strategy before removing resync.

## Evidence and reproduction

- scripts/verify.ps1: 54 checks pass (19 converter, eight login, 16 game-session, 11 presentation), plus asset import and real crop load; zero build warnings/errors.
- scripts/test-play.ps1: live spawn, accepted move, wall rejection/correction/recovery and backpack pass at 410 ms pacing.
- scripts/test-play.ps1 -Visual: actual viewer keyboard movement, two rendered characters and backpack pass. outputs/validation/playable.png was inspected locally.
- Character preview was visually inspected at outputs/validation/character-preview.png. Reproduce using Godot with --path Viewer --script res://Presentation/CharacterPreview.gd -- --screenshot=ABSOLUTE_PATH.
- The offline crop overview was inspected at outputs/validation/art-overview.png. Reproduce with Godot --path Viewer -- --screenshot=ABSOLUTE_PATH --hide-ui. This overview is a map/art view, not evidence of a network session.
- Presentation checks cover intermediate elevation, exact endpoints, no extrapolation, corner preservation, frame-rate independence, rejection reset, teleport snapping, source anchors, unknown mappings, rig-name compatibility and actual animated bone movement.

All local game-derived JSON/screenshots and downloaded archive caches remain ignored. Existing user server was left running; an attempted duplicate launch was refused before starting another instance. Sandbox loopback restrictions caused the first visual login timeout; the authorized loopback run passed. Set both APPDATA and LOCALAPPDATA to the project-local .godot-user directory for headless editor imports in this restricted environment.
