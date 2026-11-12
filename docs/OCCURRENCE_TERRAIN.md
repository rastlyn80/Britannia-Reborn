# Common creature terrain and Wandering Healer

The client keeps the original creature identities, prepared source rigs and registered animation categories. ModernUO remains authoritative for bodies, hues, movement, casting, damage, corpse IDs and loot. The supported scenes come from the existing private asset preparation. This update publishes project source, tests and provenance.

| Body | Third Dawn member | Original geometry | Enhanced evidence |
| --- | --- | --- | --- |
| 1 | `Monsters/ogres_ogre_lod2.grn` | 229 points, 452 triangles, 37 joints | Named sequence `0xed8b51b30f6757f0`, five existing fits |
| 8 | `Monsters/flails_corpser_lod2.grn` | 124 points, 250 triangles, 32 joints | Named sequence `0xdb0512bf7d99f66a`, six existing fits, including the native emergence route |
| 30 | `Monsters/harpies_harpy_lod2.grn` | 190 points, 358 triangles, 34 joints | Named sequence `0x7f2ae668064083b2`, five existing fits |
| 39 | `Monsters/mongbats_mongbat_lod2.grn` | 214 points, 439 triangles, 58 joints | Named sequence `0x72b4c98ca368b039`, five existing fits |
| 47 | `Monsters/flails_reaper_lod2.grn` | 120 points, 250 triangles, 35 joints | The audited cached sequence and definition archives and member index returned no direct record. Both client modes use the retained Classic Reaper routes. |
| 3 | `Monsters/walking_dead_zombie_lod2.grn` | 180 points, 352 triangles, 34 joints | Named sequence `0x4ab788270184b486`, six existing fits |

The Corpser member digest is `a9f50e10ef0aa981f29c2e7ed7f7ec56b1f0d65beb68d067a259c33cb85c8810`. The Mongbat member digest is `ab5c2f086a1dee90ef6f458712417b8edfb05680b73d5798b997bc261c1f4f27`. The Reaper member digest is `f2afd8be8d8e99e087e8a7e840fe09409eb73756f8506f319302d5f22ae28315`. The earlier Zombie archive and member pins are in [Zombie body 3](ZOMBIES.md). A separate later archive contains a Zombie member with digest `a720c1da066a3a0eb0257628c89597d341d0ab325a01e60f59ccce875a886603`. The prepared Zombie scenes retain the earlier accepted rig.

## Terrain and native corpses

| Body | Poses in Classic and Enhanced | Decoded corpse handoffs | Isolated native checks |
| --- | ---: | ---: | ---: |
| Ogre | 5,208 and 7,378 | 56 and 80 | 36 and 36 |
| Corpser | 3,472 and 6,076 | 64 and 80 | 35 and 35 |
| Harpy | 6,076 and 8,246 | 56 and 88 | 39 and 39 |
| Mongbat | 6,944 and 9,114 | 40 and 64 | 117 and 117 |
| Reaper | 4,340 and 4,340 | 56 and 56 | 40 and 40 |
| Zombie | 5,208 and 7,812 | 56 and 80 | 32 and 33 |

Mongbat's original wing bones can turn locally to clear a slope during takeoff. At the hardest sampled slope the largest one-sample whole-body lift fell from 249 to 107 mm. High steps can still require up to about 246 mm of abrupt lift in ordinary gait. The isolated checks covered Mongbat, Greater Mongbat and Strong Mongbat with stock movement, wrestling, taming and harvested meat or hides. The airborne tests request a real stock animation packet explicitly. Ordinary Mongbat is the only one of the three with the native flight flag.

Reaper aligns its roots to the sampled support, and remains fixed at the server tile. Its lowest earlier attack pose penetrated the test slope by about 491 mm. The measured clearance after correction stayed around 3 mm. A real Reaper started a stock Lightning cast and damaged the target through the stock spell cursor. The harness stopped its AI timer for that spell test. Both clients saw the lightning and the actual corpse with ten logs and five mandrake.

Zombie keeps its short source gait and its authored emergence from below the ground. On a step, an interrupted emergence blends from the actual buried pose into a supported fall. Ordinary gaits, actions and completed falls clear the test surfaces. The live Enhanced test also exercised the native packet that selects the emergence before death.

Ogre retains its original gait, wrestling animation and separate stock Club loot. The same two-legged support clears the test step without adding a weapon to the living model.

Corpser stays at its native tile and retains the original start of emergence below the soil. Both randomly selected native wood variants and three mandrake were checked on real corpses. The highest step still causes visible model lift during its hit reaction.

Harpy anticipates nearby treads with the original toe and leg rig. The worst measured fidget shift fell from about 316 mm to about 1 mm. The high-step attack can still lift the full model by about 206 mm in one sampled interval. Both native death routes began at the displayed pose. Stock carving yielded four raw birds and fifty feathers.

All 776 decoded handoffs retained the body and hue and finished at a frozen corpse. The worst first-pose difference across the six forms was about 6.7 micrometres.

## Wandering Healer

The two stock human bodies wore the server's robe with its exact hue and held the staff on the existing human rig. The normal client displayed the server resurrection window and sent its accept response. The isolated server verified eligible and negative-karma resurrection, criminal and murderer refusals, and healing an injured young player in 49 checks. The shared client effect fix tracks its light and particles through their respective lifetimes and disconnects when the particles leave the scene.

## Reproduction

With the existing prepared source scenes, run the three `test-source-occurrence-*.gd` scripts via the headless Viewer. Supply a body option from 1, 3, 8, 30, 39 and 47, for example `-- --body=30`. Add `--enhanced-creature-actions` after the separator for the optional Enhanced profile. The main verifier runs these tests for available local scenes. The isolated server runs use disposable test accounts and saves on loopback port 2594.
