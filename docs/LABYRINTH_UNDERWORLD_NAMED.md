# Labyrinth and Underworld named creatures

| Configured spawn | Map | Body | Raw hue |
| --- | --- | ---: | ---: |
| flurry | Malas | 13 | 3 |
| mistral | Malas | 13 | 924 |
| tempest | Malas | 13 | 1175 |
| grim | Malas | 60 or 61 | 1744 |
| GreaterPoisonElemental | Ter Mur | 162 | 667 |

The three named Air Elementals use the existing body 13 vortex and static corpse. Grim inherits the ordinary Drake bodies and Fire Breath, and has Crushing Blow and its own raw hue. The two Drake body choices are inherited from the stock base class. The Greater Poison Elemental uses the existing Third Dawn Poison Elemental route with its own hue, Mage AI, Lethal melee poison and a 3% chance to drop a Lucky Coin. [Official Labyrinth encounter guide](https://uo.com/wiki/ultima-online-wiki/combat/pvm-player-versus-monster/named-creatures-in-mondains-legacy-dungeons/)

The isolated trial imported the shipped Malas and Ter Mur spawns. All five creatures resolved from their configured spawners. Both clients received each living body and hue and received matching graphic 0x2006 corpses on restart. The same mobile and spawner serials persisted. The run sampled Grim body 60. The fixture applied lethal damage and found two Lucky Coins in a sample of 140 Greater Poison Elemental corpses. This confirms a drop path. The trial passed 56 initial and 46 restart checks.

## Approach encounter

After importing the shipped Malas Labyrinth spawns, stand near (347, 1888, 5) and run `PlaceLabyrinthAmbush` as an administrator. It replaces the single configured named-creature spawner at that site. The replacement retains its identifier and a repeated placement leaves the installed encounter in place. Reimporting the original Labyrinth spawner data can restore the ordinary spawner. Run the placement command again after that import.

The official guide describes an intermittent encounter triggered by a traveller, with ordinary air elementals escorting the named elementals and ordinary drakes escorting Grim. Britannia Reborn uses a four-tile approach boundary and a local elevation check, chooses the four named leaders at equal weight, and fills the original four-creature capacity with one leader and up to three matching escorts. The range, elevation allowance, equal weighting and escort count are reconstruction choices. The native cooldown uses the original emulator spawner's five- to ten-minute delay.

The isolated test passed 42 initial and 62 restart checks. It confirmed that normal movement revealed Mistral and three air elementals, hidden movement did not trigger the encounter, and the controller and active wave survived restart. The fixture applied lethal damage and both clients received the four matching corpse body and hue packets. A second approach observed the cooldown. After the fixture advanced the idle deadline, normal movement triggered a new wave with Flurry. A separate preceding run observed Grim accompanied by three drakes and retained that mixed body 60 and 61 wave across restart. An expanded trial passed 42 initial and 215 restart checks. Normal movement selected all five recorded leader and body combinations, including Tempest and both Grim bodies. Two clients saw each distinct leader and its matching escorts, then received the corresponding native corpse packets. The fixture prepared a clear approach, assisted the test character between crossings, advanced the idle deadline and applied lethal damage. The server retained its ordinary weighted selection. The separate live combat and artifact trial is recorded below. The encounter is staged locally. [Official encounter guide](https://uo.com/wiki/ultima-online-wiki/combat/pvm-player-versus-monster/named-creatures-in-mondains-legacy-dungeons/#Labyrinth)

## Client combat and static corpses

The focused World replay passed 77 checks in each client mode. It exercises all three elemental hues, both Grim bodies with hue 1744, and the Greater Poison Elemental's hue 667. All twelve decoded death handoffs per mode kept the selected fall, the original native palette and the frozen geometry. The test exercises corpse arrival on either side of the death packet. Both Grim bodies dispatched their existing DragonBreath motion. The driver uses Classic action and corpse packets in both World profiles. It does not use a live network session or capture rendered pixels. For each mode, run Godot in the Viewer with `--headless --script res://../scripts/test-named-labyrinth-visuals.gd`. Add `-- --enhanced-creature-actions` to select Enhanced presentation.


## Live combat and rewards

An isolated trial placed each opponent in a clear Felucca arena and gave the test player health recovery between observations. The AI chose its target and actions independently. All five damaged the player. Flurry, Mistral and Tempest were observed casting Poison, Feeblemind and Flame Strike respectively in this sample. Both clients received Grim’s group 12 fire-breath action and graphic 0x36D4 moving effect. The target also received Crushing Blow notification 1060091. The trial reduced Grim’s maximum health to cap breath damage and sampled body 60. The Greater Poison Elemental applied level-four lethal poison.

Ordinary creature deaths awarded Quiver of Elements from Flurry, Aegis of Grace from Mistral, Bloodwood Spirit from Tempest and Wildfire Bow from Grim. The fixture applied the lethal damage and counted successful drops after 87, 56, 50 and three kills respectively, then removed the test loot. The rewards came from the existing shared Mondain’s Legacy artifact pool. This sample establishes all four award paths and does not estimate drop odds. The driver recorded 854 initial assertions, including repeated observations, and five after restart to confirm login and receipt retention. The earlier combat session and client replay were separate. A follow-up joined Grim’s live combat and death packets to the full World presenter, as described below.


## Grim's alternate body

A follow-up isolated trial reproduced Grim's native body 61 and hue 1744 through its fall and frozen corpse. It also isolated a breath-windup problem when a melee packet arrives before the projectile. The tested windup change is staged for a separate release alongside fresh evidence for the existing dragon and drake packages.


## Live elemental presentation

The full Classic and Enhanced World client received live attacks from Flurry, Mistral, Tempest and the Greater Poison Elemental. The three named air elementals spawned 3D effect nodes from actual native packets, including a lightning strike in Classic. All four preserved their native body and hue through the first fall to a frozen corpse. The Greater Poison Elemental applied level-four poison, the health bar turned green, and using the normal server cure method restored it.

The disposable trial placed the creatures in a Trammel test arena and expanded the test map bounds to include it. The stock AI chose spells and targets, while the fixture restored health between samples, applied the lethal hit and invoked the player’s normal cure method. The check inspects the live 3D and HUD nodes and does not compare pixels, map-specific staging or the second death angle. After each save and restart the two clients logged in and the test retained its receipt.

[Flurry reference](https://api.github.com/repos/ServUO/ServUO/git/blobs/8b1666816e2b09f62594b6c72bdd31d6efe07e9b) · [Mistral reference](https://api.github.com/repos/ServUO/ServUO/git/blobs/b5116fccbe5d6f0c556c8e1e72e85fd957f69f37) · [Tempest reference](https://api.github.com/repos/ServUO/ServUO/git/blobs/70f2e315d218327905d2b23ff31a93c295b7ff79) · [Grim reference](https://api.github.com/repos/ServUO/ServUO/git/blobs/94456bb841d3f3737d0a6c5bb125f06c9dcbf614) · [Greater Poison Elemental reference](https://api.github.com/repos/ServUO/ServUO/git/blobs/30da2c2bb84d5e24ab1e85425896f04741100b17)
