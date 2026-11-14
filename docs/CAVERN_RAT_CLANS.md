# Cavern of the Discarded ratmen

The six ordinary ratmen now resolve by their original configured names in the pinned ModernUO Ter Mur Abyss spawn file. They share the existing ratman and ratman archer appearance, motion and corpse paths.

| Configured spawn | Official encounter tier | Local body and combat role | Stock spawner |
| --- | ---: | --- | --- |
| ClanChitterAssistant | 1 | 142, archer | Ter Mur 982, 491, −12 |
| ClanChitterTinkerer | 2 | 142, archer | Ter Mur 982, 491, −12 |
| ClanRibbonSupplicant | 1 | 42, melee with 20% cold damage | Ter Mur 919, 502, −12 |
| ClanRibbonCourtier | 2 | 42, melee | Ter Mur 919, 502, −12 |
| ClanScratchScrounger | 1 | 42, melee | Ter Mur 949, 555, −14 |
| ClanScratchHenchrat | 2 | 42, melee | Ter Mur 949, 555, −14 |

The official guide identifies the clan progression and its Renowned leaders. The three stock spawners contain the existing mixed entries. Their observed membership does not establish staged mini-champion wave transitions. The named bodies, hue zero, AI, equipment and loot baselines are local reconstructions using the stock ratman families. The original client's exact per-name body and hue packets are still needed. [Official mini-champion guide](https://uo.com/wiki/ultima-online-wiki/combat/pvm-player-versus-monster/stygian-abyss-mini-champion-spawns/)

The verified spawn file is `Data/Spawns/post-uoml/termur/Abyss.json`, SHA-256 `72aa411a81cb6f2f39a65b814175a226c29a4eea0b23b808d3d6d68ba9eccd7d`. The disposable server imported that file under the stock identities, and the trial queried each of the three pinned GUIDs. Both clients received all six living creatures. The same serials, spawner membership, archer bows, AI and sampled hit point profiles survived restart. The fixture then dealt lethal damage and both clients received matching static corpse graphic 0x2006 with the original body field and hue from the living packet. The trial passed 36 initial and 52 restart checks.

A focused combat trial passed 258 initial and 52 restart checks. All six ratmen were created by the shipped spawners. Each found the target independently and landed damage. Both Clan Chitter archers fired real arrows at five tiles. The Ribbon and Scratch ratmen attacked in melee at one tile. The fixture moved the six rats to a clear arena, constrained their positions and raised their combat skill for the trial. It returned them to their original spawners before saving. Both clients received the six matching corpses after restart.

The normal Godot World script instantiated all six native bodies in the isolated Classic and Enhanced trials. After save and restart, each defeat played an animated death and revealed a skeleton-free static corpse with the same body and hue. The harness staged the encounters in Trammel and ran headless. Classic passed 311 initial and 315 restart checks. Enhanced passed 253 initial and 153 restart checks.

Further work covers exact original hues and body assignments, the Essence of Balance and other region ingredients, and the official stage progression. The extension is staged locally for integration.
