# Britain street, locomotion and recovery — 25 October 2026

## Launch and recover

Restart the viewer with Launch.cmd. Hold right mouse to look, use WASD to move, Shift to run, Space to hop, and B for the backpack. F6 or **Return to Britain** requests a real server teleport to Trammel (1602,1591,20). Regular input is constrained to the rendered terrain crop, including its available edge quads. An out-of-region character can still use recovery.

The latest saved account's character was recovered and the server confirmed the destination. The world was explicitly saved before a graceful restart, backed up in ignored work/server-backups, and reloaded successfully. The server remains running. Saved login details remain encrypted and unchanged.

**Server commands** opens the text panel. `[PreviewWhere` reports actual server coordinates/access; `[PreviewCommands` lists the preview commands. Native `[Where` and `[Go x y z]` are relayed to ModernUO and require its Counselor-or-higher permission. No accounts were promoted. Server gumps/targeting are not supported by this panel. The isolated PreviewTools extension is disabled by default unless its local configuration is enabled, and checks loopback connections. It does not patch ModernUO core or existing gameplay code.

## Movement

The old client spent a full 410 ms walking interval on a direction-only turn and requested a position resync after every accepted movement. Animation tracks also assumed matching rest poses, although the source rig's pelvis/legs differ from the equipped character. These combined into pauses, gait changes and awkward leg poses.

Turns now have a 20 ms client rate guard, consistent with the pinned server's zero-cost turn behavior. Known flat/gentle terrain and same-level floor surfaces start bounded, one-step render prediction immediately. Matching ACKs commit XY and inferred source-backed Z without another round trip; idle/12-step reconciliation obtains the exact server state. Ambiguous elevation, steep terrain and uncertain supports use the resync fallback. Rejections clear the predicted endpoint and reset presentation to server XYZ. TCP no-delay is enabled. No movement speed or collision rule was changed on the server.

Visible facing uses continuous camera-relative intent and shortest-arc smoothing, retaining the heading on release. The network still uses UO's eight directions; this is not arbitrary-angle server physics. Motion retains exact endpoints and does not extrapolate beyond a pending step. Animation tracks are converted from source to target rest pose, with equipped skeleton proportions retained. Native pace estimates from retargeted foot travel are approximately Walk 1.02, Jog 2.66 and Sprint 3.50 m/s; short packet gaps no longer restart the gait. A CC0 ranger hood from the already downloaded Standard pack improves the presentation. Full foot IK, equipment customization, latency/stress testing and replicated physical jumping remain future work.

## Buildings and ground

Continuous façade runs share a structural post rhythm rather than stretching a complete detailed kit wall into every one-metre source cell. Metre-sized window openings, frames and stone/plaster/wood surfaces retain source anchors and orientations. Original kit textures remain byte-for-byte unchanged and materials apply at runtime. Arch openings use a human-scale lower arch and an upper wall fill.

Roof components share all edge/corner/midpoint heights. Exposed edges receive fascia, gable closure and ridge trim; original source elevations remain canonical. Roof triangles now face daylight. Source roof art is anchored one coordinate east/south of the corresponding wall footprint in both inspected buildings. Persistent `anchorOffset: [-1,-1]` rules correct the visual mesh, including trim/collision, without rewriting source XYZ. Tests check the slate building's roof/wall centre and shared mesh samples. Modern gables/corner transitions are inferred geometry, not exact source-art replicas.

Thirty-five records are roof-only rows clipped at the crop boundary. They stay in source/coverage metadata and the north-up map view, but are suppressed in perspective to avoid unsupported floating roof fragments. Gables are not invented at cut map boundaries. Perspective accounting is 2,470 visible owners, 184 grouped contributors and 35 boundary fragments, covering all 2,689 records. All 187 IDs remain classified; this is not a claim of exact original-art fidelity.

Terrain triangulation follows the gentler source diagonal used for its centre elevation. Shared vertex material weights blend grass/dirt/paving; kit surface detail, normal mapping and distance filtering replace harsh uniform checks. Colour handling and ambient fill were corrected. Collision is generated from the resulting geometry, 72,356 triangles in the current perspective crop. Original coordinates, source files and the original imported prototype are preserved.

## Reproduce and evidence

- `scripts/verify.ps1`: 120 offline checks, asset import, real crop load and isolated extension build; zero build warnings/errors.
- `scripts/test-locomotion.ps1`: production scene, six predictions queued before ACK, walk/run, second real client observing movement, exact XYZ after idle reconciliation, return to original position. Warm local first visible motion measured 16–17 ms. This is loopback evidence, not an internet-latency guarantee.
- `scripts/recover-character.ps1`: uses the latest encrypted saved login without printing secrets, verifies server teleport and a server position reply. `-DevelopmentAccount` selects the fixture account instead.
- `scripts/test-login.ps1`: real server list and game relay pass.
- `scripts/capture-radar.ps1`: updated original-palette 2D/static radar and aligned north-up 3D comparison.
- Godot `--script res://Presentation/GaitCapture.gd`: reproducible walk/jog phase contact sheet.

Ignored local evidence: outputs/validation/street-locomotion.png, street-overview.png, gait-contact-sheet.png, britain-map-comparison.png and local-static-coverage.json. These source-derived world images are not packaged or redistributed. Art source/archive/file hashes and licenses are recorded in Viewer/Art/Quaternius/manifest.json. No paid assets or upstream publication.
