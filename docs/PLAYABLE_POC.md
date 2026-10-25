# First playable proof of concept — 25 October 2026

Update: the first Quaternius environment/clothed-character pass and continuous confirmed-segment movement are now implemented and verified. The latest suite has 54 checks; cadence is 410 ms. See ART_AND_MOVEMENT.md for current presentation scope. The capsule/diagnostic-art descriptions below record the earlier playable baseline.

## Verified acceptance

| Requirement | Evidence |
|---|---|
| Account login and game session | Real UO 0xEF/0x80/0xA8/0xA0/0x8C then 0x91 with streaming Huffman |
| Create/select character | Britain Explorer and Britain Companion created normally with 0xF8; subsequent sessions select with 0x5D |
| Correct spawn/facet | Server returned Trammel (1602,1591,20); coordinates remain canonical |
| Third-person movement | Actual World scene's injected W keyboard event changed server position and rendered interpolated avatar |
| Movement validation | Real ACK plus authoritative XYZ; source-data wall at x1599/y1589 rejected a westward step from x1600; correction and recovery ACK observed |
| Two clients | Distinct accounts concurrently in ModernUO; observer received changed coordinates for the first character |
| Interaction | Double-click backpack request, server open confirmation and eight server-supplied inventory entries displayed |

The playable crop is Trammel x1576–1639/y1568–1631 (4,096 samples, 2,689 statics). The earlier crop is preserved. Both are local game-derived files excluded from Git. Avatars are capsule placeholders; static geometry and materials remain diagnostic.

## Boundaries

No server simulation was reimplemented. ModernUO owns character creation, collision, position, items and visibility. The client permits at most one outstanding movement, at a minimum 450 ms interval. It does not predict position ahead of acceptance. ACK lacks elevation, so classic 0x22 resync obtains exact 0x20 XYZ after each accepted move. The resync resets server sequence to zero; the client follows that reset. This is bandwidth-heavy and can resend many nearby entities, so it must be replaced/refined before larger multiplayer tests.

The upstream profile defaults speedhack_detection to false; wall rejection is verified, production speed/anti-cheat hardening is not. The first attempt to use an invalid sequence as a rejection oracle was unsuitable for that profile. Actual wall collision was used instead. An exploratory northward probe crossed the preview boundary; the character was walked back through normal server requests before final tests. Normal tests now probe west toward the nearby source-data wall.

Two server instances were briefly started before detecting an already-running user instance; a save-path collision was logged. The added TCP probe and exclusive runtime lock prevent this in the project launcher. The extra instances were shut down; the pre-existing server was left running, with no source changes or save-file deletions. It has continued to autosave. Do not launch ModernUO directly in parallel against the same runtime.

One rapid repeated multiplayer connection attempt disconnected; rerunning succeeded. Manual reconnect is supported. Sustained reconnect/load testing remains pending; no automatic retry obscures failures in the tests.

Other unimplemented areas: combat/spells, pickup/drop, equipment visuals, character animation/art, NPC interactions, world streaming, full facet support, configurable client versions, custom login cities/other expansions, established ClassicUO coexistence and non-Windows exports. Creating characters exposes a fixed human custom-skill preset; broader character customisation is future work. No polished-game or production-readiness claim.

## Reproduce

Start-Server.cmd, then Launch.cmd. Use local development account → Britain Explorer → Enter. Launch-Second-Client.cmd uses the second account. A new username/password auto-creates an account on this local development server; choose a name and Create character in Britain. B opens the backpack. Raw item IDs stand in for item names/art.

scripts/verify.ps1 runs 39 offline checks and the real-data viewer load. scripts/test-play.ps1 runs real spawn, movement, wall rejection/recovery and backpack. -Multiplayer verifies two sessions; -Visual drives the actual scene keyboard controller and writes outputs/validation/playable.png. These tests mutate only local development account/world state. The wall probe assumes the Britain starting corridor; it is not a generic test for arbitrary returning characters.

Evidence: outputs/validation/play.log, multiplayer.log, visual-play.log, verification.log and playable.png. Real-data evidence remains excluded from source control. Development server code is unchanged at the pinned revision.
