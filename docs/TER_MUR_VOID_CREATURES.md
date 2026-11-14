# Ter Mur Void creatures

The optional ModernUO creature extension supplies Korpre and its three evolution paths. Survival advances a lone creature after a random 30–120 minute deadline. A creature can evolve with at least two eligible neighbors within 12 tiles, and a credited kill can trigger evolution. Once a path is established, later triggers advance that same lineage. Two independent 5% rolls per transformation can produce the passive Ortanord anomaly on nearby walkable terrain.

| Path | Stage 1 | Stage 2 | Stage 3 |
| --- | --- | --- | --- |
| Survival | Anzuanord 74 | Relanord 756 | Vasanord 780 |
| Grouping | Anlorzen 11 | Anlorlem 72 | Anlorvaglem 152 |
| Killing | Betballem 776 | Ballem 304 | Usagralem Ballem 318 |

Korpre uses body 51 and Ortanord uses body 58. The server sends hue 2071 except for Anlorzen and Vasanord, which retain their unhued appearance. All 11 use existing client body routes, including the slime for Korpre, clockwork overseer for Relanord and wisp for Ortanord. The live test established native identity and corpse packets. Decoded World replays passed 46 checks per mode and found a working walk animation and a frozen, hued 3D corpse mesh for every body. Exact Void-specific rig, motion and corpse appearance remain separate source and visual work.

Wild stage 1, 2 and 3 corpses can provide Void Essence at 8%, 10% and 12%. Void Orbs can drop at all four stages. Only stage 3 can drop a Void Core. The essence is the item already used by Clockwork Scorpion assembly and repair.

After loading the optional extension, an administrator can use `[PlaceKorpreGroup` on a walkable Ter Mur tile. It creates one native three-creature spawner and refuses a duplicate within 12 tiles. Evolution preserves each existing spawner slot, home, team and walking range. This is explicit placement. The examined spawn XML did not supply an authoritative active Korpre location or density. The extension uses ModernUO’s closest-target AI with a karma and aggression filter for the reference’s positive-karma targeting behavior.

## Evidence

The disposable ModernUO run passed 188 checks plus 10 after a real save and reload. Two connected clients saw the eleven body and corpse identities with the expected hues. A lone Korpre progressed through all survival stages, stock weapon damage drove all three killing changes, a stock poison tick started the killing branch, and a spawned group progressed through all grouping stages. The fixture shortened the tested evolution deadlines and prepared low-health targets. It exercised 640 native deaths across all four stages and recorded 0, 9, 15 and 23 Void Essence drops by stage, 75 Void Orbs, and 20 Void Cores at stage 3. The restart preserved all three evolved serials, their owner entries and deadlines.

An autonomous spell kill, the probabilistic appearance and response of Ortanord, and live rendered terrain and corpse poses still need direct checks. The separate Classic and Enhanced replays used decoded native identities and the test viewer's existing terrain.

## Agralem and Into the Void

Use `[PlaceAgralem` near the Royal City soulforge. The pinned community spawn record places Agralem at Ter Mur (808, 3425, 0). He offers a one-time hunt for 10 Void creatures. Ortanord counts, following the official quest guide. The reward is the pinned server's Abyss Reaver with the official guide's ten Throwing points and 35% damage increase applied during reward creation.

The isolated trial passed 39 checks before restart and 36 afterwards. Both connections entered the world. The player accepted the quest in the native window, a rabbit gave no credit, Ortanord and nine other encounter forms counted, and five credited kills survived restart. The player returned to the same saved Agralem and claimed the Abyss Reaver through the completion and reward windows. The fixture applied the killing damage under the player's identity.

Agralem's native body 666 still needs its own 3D presentation. The official Enhanced 4.0.117.33 manifests identify 52 frame groups for the male Gargoyle, 55 for the female, 17 for Vollem and 15 for Leather Wolf. A bounded fetch decoded selected local references for all four, covering 2,255 frames across 47 groups. These are 2D references for comparing rigs, poses and surfaces. The earlier 3D bundle and inspected Age of Shadows model filenames contain no named Vollem or Leather Wolf model.

## Sources

- [Official Ter Mur Void creature guide](https://uo.com/wiki/ultima-online-wiki/combat/pvm-player-versus-monster/ter-mur-void-creatures/)
- [Pinned ServUO evolution and individual form references](https://github.com/ServUO/ServUO/tree/d76bf4443cf76d081ddaf8f57c87ff33749256af/Scripts/Mobiles/Void%20Creatures)
- [Pinned reward rules](https://github.com/ServUO/ServUO/blob/d76bf4443cf76d081ddaf8f57c87ff33749256af/Scripts/Services/LootGeneration/Imbuing/ResourceDrops.cs)
- [Pinned Ortanord reference](https://github.com/ServUO/ServUO/blob/d76bf4443cf76d081ddaf8f57c87ff33749256af/Scripts/Mobiles/Normal/Ortanord.cs)
- [Official Agralem quest guide](https://uo.com/wiki/ultima-online-wiki/gameplay/quests/agralem-the-bladeweaver-quest/)
- [Official Abyss Reaver reward properties](https://uo.com/wiki/ultima-online-wiki/items/quest-items-rewards/)
- [Pinned Agralem appearance and quest reference](https://github.com/ServUO/ServUO/blob/d76bf4443cf76d081ddaf8f57c87ff33749256af/Scripts/Mobiles/NPCs/Agralem.cs)
- [Pinned Ter Mur placement reference](https://github.com/ServUO/ServUO/blob/d76bf4443cf76d081ddaf8f57c87ff33749256af/Spawns/termur.xml)
