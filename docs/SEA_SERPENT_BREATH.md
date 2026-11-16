# Sea Serpent fire breath

Sea Serpent and Deep Sea Serpent share body 150 and the retained Third Dawn skeleton. The pinned constructors both enable stock Fire Breath. The client recognizes the five-frame Classic group 12 windup before the Enhanced attack dispatcher. The other group 12 packet shapes keep their existing compatibility action.

The breath adapts the installed 1.23-second Classic `Attack2` clip, whose fitted jaw raises and opens during the lunge. Both client profiles retain that same source clip. The new playback lasts 1.55 seconds and reaches its open-jaw phase at the server's 1.30-second release. The projectile starts just ahead of the teeth, between the animated upper head and lower jaw. Foreground Forward+ captures at release were used to fit the point.

The normal World replay passed nine checks in each mode. It covered the original melee clip, motion and the unchanged waterline anchor during the windup, ordinary melee resumption, delayed fireball placement, death interruption and the dyed static corpse. The existing waterline and action suite passed six Classic and 48 Enhanced checks with the change installed in the test. Run the new replay via Godot with `--headless --path Viewer --script res://../scripts/test-sea-serpent-breath-world.gd`. Add `-- --enhanced-creature-actions` for Enhanced.

A separate local ModernUO run exercised both native classes on verified wet tiles. With ordinary combat AI running against a fixture-positioned frozen target, all four cases across both modes selected Fire Breath and launched from the moving mouth 1,308–1,310 ms after windup. All targets took damage. Classic group 6 and Enhanced type 0 during the breath were covered by the World replay. The fixture controls which mobiles meet. A live ocean spawn encounter and continuous offshore-to-shore motion remain open.

Source provenance for the skeleton and materials is in [Sea Serpent and Deep Sea Serpent](SEA_SERPENTS.md). Server evidence comes from the classes under `Projects/UOContent/Mobiles/Monsters/Reptile/Magic` and the common `FireBreath.cs` in the revision pinned by `Server/dependencies.json`.
