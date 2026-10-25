# ModernUO integration

Source/license pin: Server/dependencies.json. Runtime: Server/runtime, referencing local game files. Core/content source unchanged. Package locks: Server/dependency-locks.

Godot sends 0xEF (21 bytes: seed + four BE version integers) and 0x80 (62 bytes: two padded 30-byte credential fields + ff). Incrementally receives 0xA8 server list (6+40×count) or 0x82 rejection. Selects server with 0xA0 (3 bytes); receives 0x8C relay (11 bytes: endpoint/token). Length, phase and encoding errors fail explicitly; secrets are not logged.

Reviewed pinned ModernUO UOContent/Network/Packets/IncomingAccountPackets.cs and Server/Network/Packets/OutgoingAccountPackets.cs, plus ClassicUO Network/OutgoingPackets.cs and PacketHandlers.cs. No ClassicUO source is linked/copied into this implementation. Live authentication/server-list/relay passed.

Next connection: seed/auth token, 0x91 game login, streaming Huffman decode, fixed/variable packet framing, version/features, 0xA9 characters and character selection. Then spawn/facet packets, move ACK/rejection and entity replication before avatar interpolation. Current relay is not world entry.

Fresh setup: scripts/setup-server.ps1. Start: Start-Server.cmd. A brand-new empty server asks about an owner account; answering n allows normal login creation. Current runtime already has a saved Player account. Console: save, then shutdown. Development ping remains loopback/enabled to avoid an observed upstream disabled-ping shutdown exception; no code patch.

Established-client verification is pending. Reference ClassicUO uses .NET 10 with FNA/FileEmbed submodules and was not built/launched. Two-client coexistence and full gameplay/content coverage must be demonstrated. Server-specific patch-profile alignment also remains pending.
