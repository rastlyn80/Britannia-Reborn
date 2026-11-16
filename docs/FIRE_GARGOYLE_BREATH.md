# Fire Gargoyle breath

The five-frame Classic group 12 cue now selects a separate Fire Gargoyle breath on the retained Third Dawn rig. The Classic motion adds chest, neck and head movement to the original idle, and Enhanced keeps its fitted action. Both modes preserve the pose during intervening melee packets. The mouth socket was corrected against Forward+ close-ups so the projectile starts at the teeth rather than the throat.

The normal World replay passed eight checks per mode. It checked muzzle motion, a fireball at 1.3 seconds, ordinary melee after the windup, and the matching dyed cadaver when death interrupted it. The existing Enhanced World suite also passed its 52 focused checks. Run the new replay with Godot `--headless --path Viewer --script res://../scripts/test-fire-gargoyle-breath-world.gd`. Add `-- --enhanced-creature-actions` for Enhanced.

Stock ModernUO AI selected Fire Breath in both isolated client modes. Each trial passed 11 checks. A separate run used the native ability and deliberately sent a Classic melee packet during the windup. Both projectiles still left the animated mouth about 1.3 seconds after the cue and produced native damage. The fixture staged the encounter. Wild encounters remain open.
