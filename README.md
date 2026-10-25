# Ultima Online 3D / UO World Studio

Project root: `C:\Coding Projects\UltimaClone`. The original Britannia prototype remains untouched in its previous workspace. This repository continues that implementation.

Double-click **Launch.cmd** for the playable Britain prototype. The starting-region crop has 4,096 terrain samples and 2,689 static placements from local Trammel data. The first Quaternius art pass replaces 2,133 pieces; 556 unresolved pieces have small gold markers. Characters wear a fixed peasant outfit and animate between confirmed server coordinates. Architecture is provisional, particularly roof slopes and corners.

1. Start **Start-Server.cmd**, unless the server is already running. The launcher refuses a duplicate server.
2. Open **Launch.cmd**, click **Use local development account**, choose **Britain Explorer**, then **Enter with selected character**. Alternatively connect with a new local username/password and create a character in Britain.
3. **WASD** walks; drag to orbit, wheel to zoom; **B** opens the backpack; **Tab** toggles unresolved diagnostic markers. Movement waits for ModernUO acceptance and continuously traverses the accepted segments, including elevation. If blocked, try another direction.
4. For multiplayer, open **Launch-Second-Client.cmd**, use its local development account and enter **Britain Companion**. Different accounts are required; entering the same character from another window disconnects its previous session.

Generated credentials remain in ignored `Server/credentials.local.json`; do not share them. Both test characters were created through ModernUO's ordinary character creation. Use `save`, then `shutdown` in the server console; normal autosaves also run. The already-running user server was left running after testing.

```powershell
.\scripts\verify.ps1         # 54 checks: 19 converter, 8 login, 16 game-session, 11 presentation
.\scripts\build-server.ps1   # pinned ModernUO build and locked dependencies
.\scripts\test-login.ps1     # live handshake; start server first
.\scripts\test-play.ps1      # live character entry, walking, wall rejection/recovery and backpack
.\scripts\test-play.ps1 -Multiplayer # two Godot sessions and observed movement
.\scripts\test-play.ps1 -Visual      # actual viewer keyboard input and screenshot
```

Portable SDKs and Godot are in `.tools`. Fresh Windows x64 setup: run `setup.ps1` for the converter/viewer and `scripts/setup-server.ps1` for ModernUO. Sandbox network permission may be required for server builds and loopback tests. SDK archive digests are not pinned yet.

Prepare the playable crop on a fresh setup with `scripts/prepare-play-world.ps1 -DataDir 'YOUR UO FOLDER'`. It writes ignored Viewer/play-world.json around the server's Britain starting city (1602,1591,20), preserving the earlier local-world.json crop. Synthetic IR is Viewer/world.json; `launch.ps1 -Synthetic` selects it. Game inputs are read-only. The scene does not invent geography outside the crop; returning characters must be within this region for a useful visual preview.

Verified against the real server: authentication, compressed game session, character creation/selection/spawn, accepted walking, blocked-wall rejection/recovery, replicated movement seen by a second client, and backpack opening/contents. The visible scene was tested using injected keyboard events. No ModernUO core/gameplay source changes. A full client, combat, item pickup/drop, equipment appearance, streaming, established ClassicUO coexistence and cross-platform exports are not complete. Idle/walk/jog presentation is implemented; the full gameplay animation system remains pending.

The client requests a classic resync after every accepted move to obtain exact elevation. This also resets the movement sequence and resends nearby state: correct for this proof of concept but inefficient. Client pace is capped at one request per 410 ms, just above the upstream default 400 ms foot-walk delay. Upstream speedhack_detection is disabled by its default profile; no production anti-cheat claim. See docs/PLAYABLE_POC.md for scope and evidence.

Selected CC0 art and bundled licenses are in Viewer/Art/Quaternius. To reproduce acquisition, run scripts/fetch-art.ps1 (network required), then scripts/prepare-art.ps1 and scripts/verify.ps1. Archives are SHA-256 pinned; publisher updates require review. Reconvert the local crop with scripts/prepare-play-world.ps1 to include tiledata names/flags/heights. See docs/ART_AND_MOVEMENT.md for scope, provenance and screenshots.

See [audit](docs/REPOSITORY_AUDIT.md), [roadmap](docs/ROADMAP.md), [progress](docs/PROGRESS.md) and [testing](docs/TESTING.md). Logs: outputs/validation. Historical prototype instructions: docs/PROTOTYPE_README.md.
