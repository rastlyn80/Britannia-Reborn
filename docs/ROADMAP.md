# Roadmap

| Milestone | Status | Acceptance / remaining work |
|---|---|---|
| 0 Audit | Completed for imported code/dependency inventory | Baseline tests and architecture documented |
| 1 Authentic conversion | Implemented/tested for small Trammel base+diff crop | 15 parser checks and real viewer load pass; independent in-game comparison outstanding |
| 2 ModernUO integration | Godot entry verified; established-client check pending | Compressed game login, character creation/selection and actual spawn pass; ClassicUO coexistence remains unverified |
| 3 First playable multiplayer | Local proof of concept implemented and tested | Real character entry, ACK/wall rejection, two-client movement observation, backpack opening/contents and actual keyboard-driven scene pass |
| 4 Reconstruction | First art pass implemented/tested | Tiledata metadata, 2,133 mapped pieces, classified ground/water and Quaternius modules; roof/corner/door fidelity, confidence overrides and collision geometry remain |
| 5 Gameplay presentation | Planned | Inventory/equipment, skills, combat, spells, NPCs and containers using server logic |
| 6 Full facets | Planned | Complete streamed Trammel, other facets, deterministic chunks/LOD and seam tests |
| 7 Platforms | Planned | Desktop exports, Android controls/performance, then Apple signing/testing |
| 8 Polish | First art/locomotion pass implemented/tested | CC0 environment, clothed humanoid, idle/walk/jog and confirmed-segment interpolation; equipment, weather/audio and further polish remain |
| 9 Production | Planned | Security, load tests, backup/restore, updates and operations |

Next slice: replace per-step resync overhead with an efficient authoritative elevation strategy, strengthen reconnect/replication tests, improve character presentation and classified geometry/collision visuals, and implement an item pickup/drop path. Numeric facet/file profiles, input bounds/provenance, independent map comparison and ClassicUO coexistence remain explicit debt. See PLAYABLE_POC.md for exact scope.
