# Hell Hound fire-breath timing

The Hell Hound keeps its original Third Dawn rig and fitted head and jaw breath pose. When ModernUO sends the five-frame group 12 windup, a later Classic attack group 5 or 6 or Enhanced melee type 0 now leaves the active breath pose playing. The World dispatcher holds only those competing melee actions while the moving mouth is available. Ordinary attacks return after the pose, and death still takes precedence.

The normal World replay passed eight checks in each mode. It covered the animated muzzle at 1.3 seconds, both melee packet types, the exact delayed projectile origin and a death interruption that produces a static corpse with the same body and dye. The same replay on the previous client lost the muzzle after the intervening attacks. Run the replay with Godot `--headless --path Viewer --script res://../scripts/test-hell-hound-breath-world.gd`, adding `-- --enhanced-creature-actions` for Enhanced.

The isolated ModernUO tests used the stock Hell Hound constructor and the native Fire Breath timers. The fixture-controlled trial inserted a real Classic melee packet during the windup and verified the origins and damage in both modes. A separate stock-AI trial passed 11 checks per mode against a fixture-positioned target. The hound sent ordinary melee packets 993 and 1,014 ms into the two windups and released both native fireballs from its mouth at 1,294 and 1,308 ms. Both targets took damage. The tests use disposable accounts and an isolated world. Wild encounters remain open.

The model, fitted jaw, dyed corpse and earlier terrain evidence are documented in [Hell Hound and Dire Wolf](CANINE_TERRAIN.md).
