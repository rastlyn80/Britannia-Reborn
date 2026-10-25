# ModernUO integration

Source/license pin: Server/dependencies.json. Runtime: Server/runtime, referencing local game files. Core/content source unchanged. Package locks: Server/dependency-locks.

Godot sends 0xEF (21 bytes: seed + four BE version integers) and 0x80 (62 bytes: two padded 30-byte credential fields + ff). Incrementally receives 0xA8 server list (6+40×count) or 0x82 rejection. Selects server with 0xA0 (3 bytes); receives 0x8C relay (11 bytes: endpoint/token). Length, phase and encoding errors fail explicitly; secrets are not logged.

Reviewed pinned ModernUO UOContent/Network/Packets/IncomingAccountPackets.cs and Server/Network/Packets/OutgoingAccountPackets.cs, plus ClassicUO Network/OutgoingPackets.cs and PacketHandlers.cs. No ClassicUO source is linked/copied into this implementation. Live authentication/server-list/relay passed.

Implemented next connection: seed/auth token, 0x91 game login, streaming Huffman, version-calibrated framing, 0xA9 characters/cities, 0xF8 creation and 0x5D selection. Spawn/facet packets, 0x20 position, 0x22 ACK, 0x21 rejection, 0x78/0x77 mobile replication, 0x1D removal, equipment/backpack detection, 0x24 container open and 0x3C inventory are handled. Live character entry, accepted/blocked movement, second-client observation and backpack contents pass. Avatar interpolation follows exact server positions.

ACK contains no elevation: the client currently sends classic 0x22 resync after each accepted step, waits for 0x20 XYZ, and resets sequence to zero to match the server's resync behavior. This resends nearby state and is inefficient; it is a proof-of-concept strategy, not the final movement protocol implementation. Requests are spaced by at least 450 ms. Session timeout/errors surface to the user. Character creation is a fixed human custom profession starting in the server-advertised Britain city. See PLAYABLE_POC.md.

Fresh setup: scripts/setup-server.ps1. Start: Start-Server.cmd. A brand-new empty server asks about an owner account; answering n allows normal login creation. Current runtime already has a saved Player account. Console: save, then shutdown. Development ping remains loopback/enabled to avoid an observed upstream disabled-ping shutdown exception; no code patch.

Established-client verification is pending. Reference ClassicUO uses .NET 10 with FNA/FileEmbed submodules and was not built/launched. Two-client coexistence and full gameplay/content coverage must be demonstrated. Server-specific patch-profile alignment also remains pending.
