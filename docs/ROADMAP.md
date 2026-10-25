# Roadmap

| Milestone | Status | Acceptance / remaining work |
|---|---|---|
| 0 Audit | Completed for imported code/dependency inventory | Baseline tests and architecture documented |
| 1 Authentic conversion | Implemented/tested for small Trammel base+diff crop | 15 parser checks and real viewer load pass; independent in-game comparison outstanding |
| 2 ModernUO integration | In progress | Build/start/login/server-list/relay verified; established client and Godot game-session entry required |
| 3 First playable multiplayer | Planned, not playable | Character selection/spawn, server move ACK/rejection, two-client observation, one interaction |
| 4 Reconstruction | Planned | Tiledata, mapping confidence, modular buildings, water, doors/stairs and collision |
| 5 Gameplay presentation | Planned | Inventory/equipment, skills, combat, spells, NPCs and containers using server logic |
| 6 Full facets | Planned | Complete streamed Trammel, other facets, deterministic chunks/LOD and seam tests |
| 7 Platforms | Planned | Desktop exports, Android controls/performance, then Apple signing/testing |
| 8 Polish | Planned | Licensed art/animation, lighting, weather/audio and responsive UI |
| 9 Production | Planned | Security, load tests, backup/restore, updates and operations |

Next slice: streaming Huffman and game-login framing, character-list fixtures, then real-server selection/spawn. Login relay is not world entry. Numeric facet/file profiles, source provenance, bounds hardening and independent map comparison remain explicit conversion debt.
