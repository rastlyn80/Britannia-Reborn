# Underworld Lucky Coins and Font of Fortune

Lucky Coins use the original client label 1113366 and targeting dialogue. Coin art 0x0EED is a provisional generic coin graphic. The server treats these coins as a separate item type from ordinary gold.

| Native corpse | Coin chance |
| --- | ---: |
| Green Goblin | 1% |
| Green Goblin Alchemist | 2% |
| Green Goblin Scout | 1% |
| Iron Beetle, while uncontrolled | 3% |
| Wolf Spider, while uncontrolled | 1% |
| Bloodworm | 2% |
| Tangling Roots | 2% |

The rates come from the corresponding pinned ServUO creature definitions. The original Font component arrangement and Ter Mur coordinates `1121, 957, -42` come from its fountain definition and Underworld generator. `[PlaceUnderworldFont` is an administrator command that places a single copy when run near the site. [Original mechanics](https://uo.com/wiki/ultima-online-wiki/gameplay/npc-commercial-transactions/font-of-fortune/) · [Reference fountain](https://api.github.com/repos/ServUO/ServUO/git/blobs/8bd51ebd945ae3d4e13c089ac42eb69bb757faaf) · [Reference placement](https://api.github.com/repos/ServUO/ServUO/git/blobs/c93e35e373242e066b245b2d4d5f503b44757f5c)

A backpack stack can be targeted at the Font. One fortune is awarded per coin up to two. Excess coins in the submitted stack are consumed. A subsequent toss during the twelve-hour cooldown is refused and leaves its coins in the backpack. Implemented outcomes are thirty minutes of +10 to one stat, thirty minutes of protection from bloodworm, rotworm and tangling roots special attacks, and a one-hour extension when an existing Font stat blessing is eligible. The stat and protection hooks use the native creature and player APIs.

Clicking the Font heals an injured player to full health. A ghost receives the native resurrection dialog on approach or by clicking the Font. Acceptance checks proximity again and uses normal ModernUO resurrection. Successful healing or resurrection starts a shared ten-minute service cooldown for that character. The official notes establish healing and the resurrection interval. Full healing on click and the shared cooldown are local choices. [Publish 60](https://uo.com/wiki/ultima-online-wiki/technical/previous-publishes/2009-2/publish-60-8th-september-stygian-abyss/) · [Resurrection in Underworld](https://uo.com/wiki/ultima-online-wiki/combat/resurrection-in-underworld-and-the-stygian-abyss/)

The disposable ModernUO and Godot trial passed 100 initial and 24 restart checks. Actual client packets exercised the valid and invalid coin targets, the spare coin, healing, distant and nearby resurrection responses, and restart cooldowns. The saved fountain and spare coin retained their serials. The accepted toss granted +10 Strength and +10 Dexterity, which both reappeared with their original time limits on reconnect after restart. The test used the native stat modifiers and read server state after each client action.

The trial sampled 180 native deaths per creature and found coins from all seven, producing respectively 1, 7, 2, 5, 1, 1 and 9 drops. The fixture applied the lethal damage. This sample demonstrates each loot path. Maintain follow-ups for exact coin art and hue, the luck bonus, balm extension, treasure and reward weights, and direct observation of stat expiry. The source and its private evidence are staged for later integration.

A focused trial passed 21 initial and 21 restart checks. A normal coin toss granted the thirty-minute protection. Controlled native creature callbacks confirmed that it blocked Bloodworm drain, Rotworm disease and the Tangling Roots hold before and after a save and restart. The fixture shortened the isolated deadline to test expiry. After expiry, all three abilities took effect again and the client received the disease and hold messages.
