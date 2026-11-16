# Dragon and Drake fire breath

In the normal World client, the stock five-frame fire-breath animation now has at least 1.5 seconds to play. The pinned ModernUO ability sends its fireball 1.3 seconds after the windup packet. Classic melee groups 4–6 and Enhanced melee type 0 can arrive during that gap. Those packets leave the breath pose playing while its animation timer is active. Death can interrupt the pose immediately.

The checked appearances are Dragon bodies 12 and 59, Drake bodies 60 and 61, Ancient Wyrm 46 and Shadow Wyrm 106. The wyrms retain their existing 1.55-second windup. The client keeps the source rigs and launches graphic `0x36D4` from the animated `box15` bone. The exact windup packet is Classic group 12 with five frames, one forward pass, no looping and no packet delay.

Run the packet replay from the Godot project with `--headless --path Viewer --script res://../scripts/test-dragon-breath-world.gd`. Repeat with `-- --enhanced-creature-actions` for Enhanced actions. Both modes passed 332 checks. They exercise the normal World packet and effect routes with a fixed animation clock, verify the muzzle at 1.3 seconds, and check melee after the window and death during it. The unchanged Classic client failed the 1.3-second muzzle assertion on body 12. This regression trial checks scene state and packet handling headlessly.

The server timing and effect graphic come from `Projects/UOContent/Mobiles/Abilities/Fire Breath/FireBreath.cs` in the ModernUO revision pinned by `Server/dependencies.json`.

## Serpentine Dragon

Body 103 uses a different rig and its native constructor also enables Fire Breath. The original local assets include `Models/Monsters/dragons_dragon_asian_attack1.grn` (59,520 bytes, SHA-256 `1f6c78b6dad76201e552b94727735212aeb1e51fbb8e5dc45a72bd7944e630b2`). The client retimes that source motion into a separate 1.55-second breath, with the forward head thrust at 1.30 seconds. The stock packet selects the breath, while the original melee clip keeps its original timing. The muzzle follows a point fitted to the skin over the `box02` bone. Forward+ profile and close-up renders at the release frame show the origin between both jaws, just ahead of the tongue. Review of the full encounter from in-game camera angles remains open.

Each client mode checked 279 breath poses across the original, rounded and modern treatments on flat and two sloped support planes. The smallest sampled skin clearance was 2 mm and the creature's placement stayed fixed. The World replay checked the delayed muzzle, melee resumption and dyed static corpse after death interrupted the breath.

## Isolated ModernUO trial

Classic and Enhanced each passed 46 checks across a Dragon, Greater Dragon, both Drake appearances, Ancient Wyrm, Shadow Wyrm and Serpentine Dragon. The normal World client logged in and received the live packets from the pinned server. The test fixture invokes the creature's stock Fire Breath and emits one competing Classic melee packet about a second later. All fourteen fireballs arrived 1,301–1,305 ms after the windup, from the animated muzzle. The subsequent native damage reduced the target's health in every case.

A separate trial passed 53 checks in each client mode for the same seven cases with the creatures' normal combat AI running. The fixture placed a frozen Ogre Lord as the target and registered its aggression. The stock AI chose Fire Breath and the server applied its own timers and damage. The first verified projectile launched 1,301–1,309 ms after the cue across all fourteen cases. A Drake in each mode sent an ordinary melee packet during that windup. The target's health fell in every case. The trial establishes ability selection in a controlled encounter. Wild spawn placement and target choice outside the arena remain open.
