# Progress — 25 October 2026

Imported the working prototype into UltimaClone, preserving the original; corrected build/launch/setup/capture tool paths. Rebuilt converter: zero warnings/errors, all 15 checks pass. Godot loads the real Britain IR (2,304 samples, 1,616 statics).

Audited/pinned ModernUO ab59efea86fd9e399d261bed9d188ab4d95ad4c2 and ClassicUO ee79d7ebc1cc0e53ff84fe6cae17d389e2737f93. Server code unchanged; ClassicUO reference-only. Installed local SDK 10.0.201; server build has zero warnings/errors. Added NuGet locks, setup/build/start/configure wrappers and separate local runtime.

Godot now has direct login transport and a local connection panel. Eight packet tests pass. Live Godot → ModernUO authenticated, received one-server list and game relay. Tests print no password/token. A normal Player account was created through ModernUO and persisted via the server save command.

Runtime binds TCP 127.0.0.1:2593 and UDP loopback ping 12000. Provisional profile: upstream default Endless Journey with Trammel selected; not a final era decision. No game-file edits, purchases or publication.

Resume: read MASTER_PLAN, ROADMAP, DECISIONS and MODERNUO_INTEGRATION. Run scripts/verify.ps1; Start-Server.cmd; scripts/test-login.ps1. Credentials remain in ignored Server/credentials.local.json. Next: compressed game session, character selection/spawn and server-authoritative movement. No playable multiplayer claim yet.

Known issue: pinned upstream shutdown threw when pingServer was disabled. No patch/report; development enables loopback ping. Empty-account first boot needs a console (answered n); current runtime has a saved account. Sandbox sockets required approved execution; do not misdiagnose those timeouts as protocol incompatibility. Full upstream suite and established-client verification pending. Evidence: outputs/validation.

End-of-session state: test server saved its account and shut down cleanly with ping enabled. Launch it using Start-Server.cmd before live tests. Original converter and local-world IR match the imported originals by SHA-256. The source repository excludes the separate runtime and proprietary data.
