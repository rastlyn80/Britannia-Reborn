# Testing

scripts/verify.ps1 builds the converter, runs 15 parser, eight login and 16 game-session tests (39 total), then loads the real world headlessly. Current result: all pass. The playable region contains 4,096 samples and 2,689 statics; the earlier 2,304-sample crop is preserved separately.

Parser: block/cell ordering, origin, signed elevations, static ID/hue/position, unaligned crop, lookup3 empty input, raw/zlib UOP, MUL/UOP equivalence, incomplete diffs, terrain precedence, duplicate static replacement and truncation. Fixtures share the writer/hash implementation, so production map import is extra evidence, not an exhaustive independent oracle.

Login: seed/credential layout, fragmented independently assembled server-list bytes, relay endpoint/token, malformed lengths, rejection, unknown packets and lossy encoding. Game tests add independent Huffman bit vectors, split/coalesced streams, signed Z, creation packet offsets, version sizes, fragmented spawn, position/sequence resync, rejection correction, remote movement/removal and malformed framing.

scripts/test-play.ps1 verifies live character selection/spawn, real walking, wall rejection/correction/recovery and backpack. -Multiplayer uses two accounts and checks observer coordinates actually change; turning alone does not pass. -Visual loads the production scene, injects a physical W key, confirms actual position change, sees two rendered avatars and captures a screenshot with backpack contents. Creation was exercised against empty accounts and later logins reused those characters. See PLAYABLE_POC.md for assumptions, reconnect caveat and local state changes.

scripts/build-server.ps1 pins source and enforces package locks. Current server build: zero warnings/errors. Full upstream unit tests, established-client coexistence, sustained reconnect/load tests, client geometry collision quality, chunk seams and non-Windows exports remain outstanding. Server wall rejection and two-Godot-client replication now pass; source inventory still does not imply full gameplay validation.

capture.ps1 -Local renders the local map; images remain local. Logs: outputs/validation. Sandbox networking may need approval even for loopback. A timeout/fallback is not a passing integration test.
