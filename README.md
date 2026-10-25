# Ultima Online 3D / UO World Studio

Project root: `C:\Coding Projects\UltimaClone`. The original Britannia prototype remains untouched in its previous workspace. This repository continues that implementation.

Double-click **Launch.cmd** for the real Britain preview: 2,304 terrain samples and 1,616 static placements from local Trammel data. Drag to orbit, wheel to zoom, WASD to pan, Tab to toggle statics. Buildings use diagnostic boxes, not finished art.

Double-click **Start-Server.cmd** to start ModernUO. The viewer's new local connection panel authenticates and requests a game-server handoff. Generated development credentials are in the ignored `Server/credentials.local.json`; do not share them. Character entry and movement are not implemented. Server console commands: `save`, then `shutdown`.

```powershell
.\scripts\verify.ps1         # 15 converter checks, 8 login checks, real Godot world load
.\scripts\build-server.ps1   # pinned ModernUO build and locked dependencies
.\scripts\test-login.ps1     # live handshake; start server first
```

Portable SDKs and Godot are in `.tools`. Fresh Windows x64 setup: run `setup.ps1` for the converter/viewer and `scripts/setup-server.ps1` for ModernUO. Sandbox network permission may be required for server builds and loopback tests. SDK archive digests are not pinned yet.

Reimport local data read-only with `build.ps1 -DataDir "$env:USERPROFILE\OneDrive\Electronic Arts\Ultima Online Classic"`. Real IR is Viewer/local-world.json; synthetic IR is Viewer/world.json. Use `launch.ps1 -Synthetic` for fixtures. Proprietary inputs, local IR, secrets and saves are excluded from Git.

Verified: converter/viewer, server build/start, Godot authentication/server-list/relay. No ModernUO core/gameplay source changes. Established ClassicUO interoperability and full upstream gameplay tests remain unverified. Next: compressed game-session packets, character entry and authoritative movement.

See [audit](docs/REPOSITORY_AUDIT.md), [roadmap](docs/ROADMAP.md), [progress](docs/PROGRESS.md) and [testing](docs/TESTING.md). Logs: outputs/validation. Historical prototype instructions: docs/PROTOTYPE_README.md.
