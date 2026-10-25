# Ultima Online 3D / UO World Studio

Project root: `C:\Coding Projects\UltimaClone`. The original Britannia prototype remains untouched in its previous workspace. This repository continues that implementation.

Double-click **Launch.cmd** for the playable Britain prototype. The crop contains 4,096 terrain samples and 2,689 static records. All 187 used static IDs have explicit mappings; all records are represented by models/procedural substitutes or grouped components, with no unmapped crop IDs. Characters wear fixed peasant outfits; the camera avoids solid geometry, movement blends between confirmed coordinates, and running/jump presentation is available. See docs/GRAPHICS_PASS.md for coverage, confidence and remaining fidelity limits.

1. Start **Start-Server.cmd**, unless the server is already running. The launcher refuses a duplicate server.
2. Open **Launch.cmd**, click **Use local development account**, choose **Britain Explorer**, then **Enter with selected character**. Alternatively connect with a new local username/password and create a character in Britain.
3. **WASD** moves; **Shift** runs; **Space** performs a ceiling-aware animated hop; drag with either mouse button to orbit, wheel to zoom; **B** opens the backpack. Movement waits for ModernUO acceptance and traverses accepted segments continuously. The camera retracts before solid geometry. The hop is currently local presentation: it cannot clear server walls or change the server's elevation.
4. For multiplayer, open **Launch-Second-Client.cmd**, use its local development account and enter **Britain Companion**. Different accounts are required; entering the same character from another window disconnects its previous session.

Generated credentials remain in ignored `Server/credentials.local.json`; do not share them. Both test characters were created through ModernUO's ordinary character creation. Use `save`, then `shutdown` in the server console; normal autosaves also run. The already-running user server was left running after testing.

```powershell
.\scripts\verify.ps1         # 73 checks, including static coverage, camera collision and jumping
.\scripts\build-server.ps1   # pinned ModernUO build and locked dependencies
.\scripts\test-login.ps1     # live handshake; start server first
.\scripts\test-play.ps1      # live character entry, walking, wall rejection/recovery and backpack
.\scripts\test-play.ps1 -Multiplayer # two Godot sessions and observed movement
.\scripts\test-play.ps1 -Visual      # actual viewer keyboard input and screenshot
.\scripts\test-graphics.ps1          # real running, corridor camera collision, keyboard jump/landing
```

Portable SDKs and Godot are in `.tools`. Fresh Windows x64 setup: run `setup.ps1` for the converter/viewer and `scripts/setup-server.ps1` for ModernUO. Sandbox network permission may be required for server builds and loopback tests. SDK archive digests are not pinned yet.

Prepare the playable crop on a fresh setup with `scripts/prepare-play-world.ps1 -DataDir 'YOUR UO FOLDER'`. It writes ignored Viewer/play-world.json around the server's Britain starting city (1602,1591,20), preserving the earlier local-world.json crop. Synthetic IR is Viewer/world.json; `launch.ps1 -Synthetic` selects it. Game inputs are read-only. The scene does not invent geography outside the crop; returning characters must be within this region for a useful visual preview.

Verified against the real server: authentication, compressed game session, character creation/selection/spawn, accepted walking, blocked-wall rejection/recovery, replicated movement seen by a second client, and backpack opening/contents. The visible scene was tested using injected keyboard events. No ModernUO core/gameplay source changes. A full client, combat, item pickup/drop, equipment appearance, streaming, established ClassicUO coexistence and cross-platform exports are not complete. Idle/walk/jog presentation is implemented; the full gameplay animation system remains pending.

Movement now predicts source-backed flat/gentle steps immediately, with server ACK/rejection and idle/periodic exact-position reconciliation. Ambiguous elevations retain the resync fallback. Pacing is 405 ms walking / 205 ms running; direction-only turns use a short 20 ms guard instead of a walking delay. Upstream speedhack_detection is disabled by its default profile; no production anti-cheat claim. See docs/GRAPHICS_PASS.md and docs/PLAYABLE_POC.md for scope.

Selected CC0 art and bundled notices/hashes are in Viewer/Art/Quaternius and Viewer/Art/Kenney. Reproduce with scripts/fetch-art.ps1, scripts/prepare-art.ps1, scripts/prepare-furniture.ps1 and scripts/verify.ps1. Archives are SHA-256 pinned; publisher updates require review. Reconvert the crop with scripts/prepare-play-world.ps1 to include tiledata metadata. See docs/GRAPHICS_PASS.md for current scope and evidence; docs/ART_AND_MOVEMENT.md records the earlier baseline.

See [audit](docs/REPOSITORY_AUDIT.md), [roadmap](docs/ROADMAP.md), [progress](docs/PROGRESS.md) and [testing](docs/TESTING.md). Logs: outputs/validation. Historical prototype instructions: docs/PROTOTYPE_README.md.

### Camera and remembered login

Hold the **right mouse button** and move the mouse to look around; release to use the interface. The wheel zooms. Escape while looking or switching windows releases the pointer. Gamepads are disabled until enabled on the login screen.

The latest submitted username/password are restored automatically on Windows. The password stays masked and is encrypted for the current Windows user in the ignored local Godot user-data directory. Use **Forget saved login** to remove it, or untick **Remember login**. With no saved login, the launcher prefills the existing development account. Secure remembered credentials are currently Windows-only. Restart the viewer after updating.

### Return to the preview and server commands

Press **F6** or click **Return to Britain** to return to Trammel (1602,1591,20). Regular movement stops at the converted area edge. Open **Server commands** for `[PreviewWhere`, `[PreviewCommands`, and native ModernUO text commands; staff commands retain their server permissions. The local recovery extension works for ordinary Player accounts. See docs/STREET_MOVEMENT_PASS.md for the current movement, roof-anchor correction, test evidence and limits.

## Original 2D comparison

Double-click `Play-Classic-2D.cmd`, or `Play-Classic-2D-Observer.cmd` for a separate character alongside Godot. Both connect to the existing ModernUO server. See docs/CLASSIC_COMPARISON.md for controls, credentials and the pinned BSD client dependency.
