# Testing

scripts/verify.ps1 builds the converter, runs 15 parser tests and eight Godot login tests, and loads the real world headlessly. Current result: all pass, zero converter warnings/errors; 2,304 samples and 1,616 statics load.

Parser: block/cell ordering, origin, signed elevations, static ID/hue/position, unaligned crop, lookup3 empty input, raw/zlib UOP, MUL/UOP equivalence, incomplete diffs, terrain precedence, duplicate static replacement and truncation. Fixtures share the writer/hash implementation, so production map import is extra evidence, not an exhaustive independent oracle.

Login: seed/credential layout, byte-fragmented independently assembled server-list bytes, relay endpoint/token, malformed lengths, rejection, unknown packets and lossy encoding. scripts/test-login.ps1 runs production GDScript against actual ModernUO. Verified authentication/server-list/relay, not compressed game traffic/spawn.

scripts/build-server.ps1 pins source and enforces package locks. Current build: zero warnings/errors. Full upstream unit tests, established-client verification, two-player replication, move rejection, interactions, seams/collision and non-Windows exports remain outstanding. Source inventory is not gameplay validation.

capture.ps1 -Local renders the local map; images remain local. Logs: outputs/validation. Sandbox networking may need approval even for loopback. A timeout/fallback is not a passing integration test.
