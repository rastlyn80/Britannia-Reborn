# Giant Serpent terrain and Enhanced playback

The original Third Dawn body 21 keeps its 118 points, 237 triangles, 18 joints and original `serpents_snake_giant_v03.tga` atlas. The member `Monsters/serpents_snake_giant_lod2.grn` has SHA-256 `2062d9180e57ac32eac9a910f204065dc9da71e59b587e1ae7fff80015aaeadb`. The exact named Enhanced sequence is `0x7239e9944db1c3b3`. Its [frame evidence and preparation](GIANT_SERPENT_ENHANCED.md) remain in the earlier report.

The client keeps the server tile and body hue. Local neck and tail rotations clear sloped ground and two treads. The original submerged phase still starts below ground. A death during the rise blends from the displayed pose to the native body's static corpse. On the highest tested step the Pillage action can still shift the model upward by about 210 mm in one sampled interval.

| Trial | Classic | Enhanced |
| --- | ---: | ---: |
| Full-skin terrain poses | 5,208 | 8,246 |
| Decoded death handoffs | 64 | 96 |
| Isolated native checks | 105 | 136 |

The two clients exercised stock Giant Serpent, Death Adder and serpent-shaped Plague Spawn on the disposable server. The Death Adder came from the stock summon API. An explicit Enhanced action packet selected the rise. Stock Kill while the serpent was still under the ground produced the real body-21 corpse and retained its partial dye. The stock server controlled the deaths and loot. The largest measured first-pose transfer was about 1.02 micrometres.

## Playback clock

A scan of 794 unique scenes registered by the installed Enhanced profile found 13 packed with the baker's manual animation clock. The affected scenes were Giant Serpent 21, Silver Serpent 92, Sea Serpent 150, Ordinary Rat 238 and Bog Thing 780. The legacy prepared files now use the client scene clock through their specific renderers. The four serpent and rat bakers restore the idle callback before packing. The Classic scan found one affected packed Bog Thing scene among 769 unique registered scenes. Bog Thing corrects its animation clock when the verified scene loads in World. Both profiles now advance their prepared scenes. All fourteen affected installed scenes passed the client clock check, and ten fresh serpent and rat bakes recorded the correct callback.

With the prepared assets, run `scripts/verify.ps1`. Its focused tests are `test-source-giant-serpent-terrain.gd`, `test-source-giant-serpent-falls.gd`, `test-source-occurrence-world.gd` and `test-source-creature-clock.gd`. Run the clock check in both modes. Add `--enhanced-creature-actions` after the Godot user-argument separator to check the optional profile. Prepared scenes and isolated server receipts remain local.
