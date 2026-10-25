# Progress — 25 October 2026

## Login memory and mouse camera correction

Camera look now starts only with an unhandled right-button press, captures the pointer, consumes relative motion, and releases before GUI routing on mouse-up, Escape or window focus loss. Controllers are off until explicitly enabled; their stick deadzone is 0.35. No idle camera recentering is introduced. Login fields retain the latest submitted account/password, seeded from the existing local development account when no saved login exists. Windows CurrentUser DPAPI encrypts the local vault through anonymous pipes; passwords are never passed as process arguments. Remember is enabled initially, with explicit forget/opt-out controls. Non-Windows secure persistence is not implemented and reports failure.

Visual pass: closer default camera, warmer light, softer ground/roof patterns with distance-aware filtering, 4x MSAA, coordinated low-contrast architectural materials using unchanged publisher texture files, smaller in-world instructions and hidden controller settings after entry. This does not resolve remaining architectural proportions, missing gable/hip reconstruction or crop boundaries. Original sources and server remain untouched.

Validation: all 84 offline checks pass, including 11 new encrypted-vault and mouse lifecycle checks. Live login/relay and server run/camera-wall/jump tests pass. New screenshot: outputs/validation/updated-street.png. Final screenshot was captured with scripts/test-graphics.ps1 -PreviewOnly without moving the character. A later full traversal rerun timed out, and its retry found the player at x=1604 rather than the fixture corridor x=1600; the harness now rejects that precondition explicitly instead of asserting a corridor wall at arbitrary positions. Earlier live run/camera/jump passes were at x=1600. Windows vault tests use disposable fixture credentials and remove their vault; no real login secrets are emitted. Re-run scripts/verify.ps1, scripts/test-login.ps1 and scripts/test-graphics.ps1.

## Latest checkpoint: complete crop catalogue, solid camera and run/jump presentation

All 187 used static IDs now have explicit persistent rules. All 2,689 source records retain ordinal/ID/XYZ and are accounted for: 2,645 visual owners and 44 grouped components. No unmapped crop IDs remain. Expanded Quaternius modules/nature plus audited CC0 Kenney furniture cover gaps; procedures supply continuous family-specific roofs, stairs, carpets and small props. Coverage is not exact original-art fidelity; confidence/substitutions are reported, including a post silhouette needing further review. Source artwork references are local-only, never game assets. Added chunked presentation collision (91,416 triangles), spherical camera sweep/recovery/near-body hiding and broad orbit/zoom.

Real Shift run packets and per-segment walk/run timing are implemented, with speed-scaled animation and consistent tile-centre presentation. Space produces a ceiling-aware animated local hop, tested through apex and landing; it does not alter server Z or replicate physical jumping. Server remains unchanged and authoritative. All 73 offline checks pass. Live wall rejection/recovery/backpack and actual run/camera/jump pass; real corridor camera retracts to ~0.697 units, jump peaks ~0.95. Existing server remains running. See GRAPHICS_PASS.md for reproduction, source/asset provenance, screenshots and limitations. Earlier 54-check / 556-unmapped notes below are historical.

Added reproducible original-colour radar comparison: scripts/capture-radar.ps1 renders terrain-only, static-overlay radar and an aligned north-up orthographic 3D view for the exact play crop. Local radarcol.mul/hues.mul supply original colours; highest drawable static base Z selects the overlay. Inspected outputs/validation/britain-map-comparison.png and separate 64×64/enlarged radar PNGs. This is a reconstruction of the static radar data, not an original-client UI screenshot; live mobiles and multis are excluded. Images remain ignored/local.

## Latest checkpoint: Quaternius art and smooth confirmed movement

Imported five free CC0 Quaternius Standard packs with bundled licenses, pinned archive hashes and selected-file manifest. C# tiledata metadata supports 32/64-bit flags and static heights. Current crop replaces 2,133/2,689 static placements; 556 unresolved pieces remain gold markers. Provisional connectivity/slope rules need architectural review; slate uses tinted round-tile geometry over a continuous roof bed. Nature, classified procedural ground and shadows are integrated. Real humanoids wear fixed peasant outfits and animate idle/walk/jog; equipment appearance is not implemented.

Confirmed server endpoints now drive continuous timed XYZ segments with preserved corners, rejection reset and bounded teleport/catch-up behavior; facing blends and camera follows after interpolation. Request cadence is 410 ms versus upstream's default 400 ms foot walk. Server collision and per-step resync remain authoritative; no prediction/continuous-physics claim. Full 54-check verification passes without warnings/errors. Live wall rejection/recovery/backpack and two-character visual keyboard test pass. Inspected playable.png and character-preview.png in ignored outputs/validation. Existing server left running; duplicate launch guard refused a second instance. Details and reproduction: ART_AND_MOVEMENT.md.

Next: validate roof/wall orientation and pivots against source landmarks, implement explicit corner/door rules and confidence overrides, improve camera obstruction/foot placement, then replace per-step resync with a tested elevation strategy. Earlier notes below are historical and superseded where they describe art as unimported or motion pacing as 450 ms.

User confirmed art sources: Medieval Village MegaKit for architectural statics and Stylized Nature MegaKit for nature, with Kenney only as a gap-filling fallback. Recorded in DECISIONS.md and ASSET_SHORTLIST.md. Import and archive-level license/provenance verification remain pending.

Asset survey: inspected current Britain crop and local tiledata read-only; saved ignored local inventory. Verified publisher CC0 declarations for Quaternius Medieval Village/Stylized Nature MegaKits and Kenney Fantasy Town Kit. ASSET_SHORTLIST.md records edition restrictions and first reconstruction target. No third-party art downloaded/imported or purchased; visual placeholders remain.

## Current checkpoint: playable local proof of concept

Added streaming Huffman and modern packet framing; creation/selection/spawn; server ACK/rejection and exact XYZ resynchronisation; nearby mobile replication; backpack open/content parsing; a character UI, interpolated capsule avatars and third-person WASD controller. Actual ModernUO created two distinct characters in Britain. Live tests verified wall rejection/recovery and a second client observing movement. The real viewer passed injected keyboard movement and captured outputs/validation/playable.png. Offline suite now has 39 checks. Server source remains unchanged; ClassicUO wire tables are adapted under BSD-2-Clause with retained notice.

Launch.cmd opens the primary account; Launch-Second-Client.cmd offers the second account. The 64×64 play-world crop covers Britain starting coordinates (1602,1591,20); the original region remains separate. scripts/prepare-play-world.ps1 regenerates it read-only. The pre-existing server was left running. Do not start another instance on the same runtime; the launcher now probes TCP and holds an exclusive lock.

Read PLAYABLE_POC.md for evidence, temporary resync overhead, fixed creation preset, reconnect caveat and the duplicate-server/save-collision observation. Next: improve session efficiency/reliability, character/geometry presentation and item pickup/drop. The older notes below record the imported baseline and have been superseded where they describe character entry as unimplemented.

Final validation: 39 offline checks pass; real wall rejection/recovery, two-client observation and actual keyboard-driven rendering pass. Game seed/login now batches into one write (TCP still permits fragmentation); a further multiplayer + visual run passed afterward. Existing server save files show continuing autosaves. No other server instance was left running by these tests. Character selection uses the server's existing characters; creation was exercised on empty local test accounts.

Imported the working prototype into UltimaClone, preserving the original; corrected build/launch/setup/capture tool paths. Rebuilt converter: zero warnings/errors, all 15 checks pass. Godot loads the real Britain IR (2,304 samples, 1,616 statics).

Audited/pinned ModernUO ab59efea86fd9e399d261bed9d188ab4d95ad4c2 and ClassicUO ee79d7ebc1cc0e53ff84fe6cae17d389e2737f93. Server code unchanged; ClassicUO reference-only. Installed local SDK 10.0.201; server build has zero warnings/errors. Added NuGet locks, setup/build/start/configure wrappers and separate local runtime.

Godot now has direct login transport and a local connection panel. Eight packet tests pass. Live Godot → ModernUO authenticated, received one-server list and game relay. Tests print no password/token. A normal Player account was created through ModernUO and persisted via the server save command.

Runtime binds TCP 127.0.0.1:2593 and UDP loopback ping 12000. Provisional profile: upstream default Endless Journey with Trammel selected; not a final era decision. No game-file edits, purchases or publication.

Resume: read MASTER_PLAN, ROADMAP, DECISIONS and MODERNUO_INTEGRATION. Run scripts/verify.ps1; Start-Server.cmd; scripts/test-login.ps1. Credentials remain in ignored Server/credentials.local.json. Next: compressed game session, character selection/spawn and server-authoritative movement. No playable multiplayer claim yet.

Known issue: pinned upstream shutdown threw when pingServer was disabled. No patch/report; development enables loopback ping. Empty-account first boot needs a console (answered n); current runtime has a saved account. Sandbox sockets required approved execution; do not misdiagnose those timeouts as protocol incompatibility. Full upstream suite and established-client verification pending. Evidence: outputs/validation.

End-of-session state: test server saved its account and shut down cleanly with ping enabled. Launch it using Start-Server.cmd before live tests. Original converter and local-world IR match the imported originals by SHA-256. The source repository excludes the separate runtime and proprietary data.
