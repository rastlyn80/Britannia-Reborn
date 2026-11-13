# Dull Copper Elemental on slopes and steps

Body 110 keeps the original Dull Copper mesh and atlas, its retained Earth Elemental movement link and the three Classic copper gestures. The terrain renderer clears the full skin across both sides of the tread. The displayed fall passes into static corpse graphic 0x2006 with the same native body and hue.

| Replay | Classic | Enhanced |
| --- | ---: | ---: |
| Living full-skin poses | 2,790 | 2,790 |
| Poses below the 2 mm target before correction in Classic | 1,130 | |
| Poses below target after correction | 0 | 0 |
| Decoded death and corpse handoffs | 80 | 80 |
| Sampled fall poses | 1,360 | 1,360 |
| Isolated native checks | 40 | 40 |

The living and fall replays use flat ground, slopes and a 22 cm step. The first falling pose shifts by less than three micrometres and the static corpse settles about 2 mm above the support. The largest adjacent correction was about 238 mm on a high-step walk sample. That correction remains visible.

Both disposable clients received the stock death-explosion graphic 0x36BD and observed the native movement and death. The stock explosion damaged a nearby disposable Ogre. The two corpse tests used the default two-ore constructor and the 25-ore constructor used by the mining branch. Each yielded the requested amount of actual Dull Copper Ore with item graphic 0x19B9. The tests supplied the constructor amount, movement and gesture packets. They read the stock dispel and bleed immunity properties. The mining trigger and dispelling a summoned target were outside this trial.

The exact logs and receipts remain in work/creatures/native-form-audit/enhanced-source-gaps/common-forms-enhanced/dull-copper-living-source. The existing asset records carry the original mesh, atlas and motion provenance.
