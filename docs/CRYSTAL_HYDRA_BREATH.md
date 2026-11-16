# Crystal Hydra cold breath

The configured Crystal Hydra uses the retained Hydra rig (body 265) and its server hue `0x47E`. Its stock forward five-frame group 12 cue selects the centre-head breath. Classic keeps the new centre-neck and jaw motion, and Enhanced keeps the existing fitted breath. All projectiles for the same cast leave that animated mouth and retain the effect hue sent by the server.

The World replay passed 12 checks in each client mode. It sends both melee packet types during the windup, decodes three separate `0xC0` effect packets and checks the origin and colour of each bolt. An interrupted breath still yields the matching static corpse. Run it with Godot `--headless --path Viewer --script res://../scripts/test-crystal-hydra-world.gd`. Add `-- --enhanced-creature-actions` for Enhanced.

A disposable ModernUO world used its stock spawner and normal combat AI. The fixture positioned a Crystal Hydra and six frozen Ogre Lords in Trammel, expanded the client preview bounds to include the arena and applied the final lethal hit. Each mode passed 25 checks. The AI chose cold breath and the caster had 30 less mana at release. Each cast hit the primary target and four additional targets, leaving the sixth unharmed. All ten projectiles left the animated mouth 1,302–1,306 ms after windup and dealt 114–131 damage. The normal client animated the native death and displayed a skeleton-free corpse with the original hue. The test paused further AI actions after release to measure the delayed damage. Natural Ter Mur encounters and peerless progression remain open.

The server extension and earlier spawn, loot and restart evidence are documented under [Crystal Hydra](LATER_NATIVE_CREATURES.md#crystal-hydra).
