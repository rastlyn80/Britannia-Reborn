# Bone Knight on slopes and steps

Body 57 retains its original Third Dawn skeleton, recovered scimitar and wooden shield, both original falls and the fitted Classic gestures. The terrain renderer measures the complete skinned body and both weapons. The fall retains the displayed pose and freezes all three parts under static corpse graphic 0x2006 with the server's body and hue.

| Replay | Classic | Enhanced |
| --- | ---: | ---: |
| Living full-skin poses | 3,720 | 3,720 |
| Poses below the 2 mm target before correction in Classic | 3,671 | |
| Poses below target after correction | 0 | 0 |
| Decoded death and corpse handoffs | 112 | 112 |
| Sampled fall poses | 1,904 | 1,904 |
| Isolated native checks | 44 | 44 |

The replays use flat ground, slopes and a 22 cm step. Both death groups retain the sword and shield. The initial joint shift stays below one micrometre and the frozen body and weapons settle about 2 mm above their support. The largest adjacent living correction was about 224 mm during running on the highest step. That can still look abrupt.

Two disposable characters exercised the stock constructor and both observed native movement and death. The stock Bone Knight has bleed immunity and treats a Pixie as an enemy. The corpse retains native scimitar, wooden shield and plate loot. Controlled Classic gesture packets select the side cut, duck and blade salute. The tests use the Bone Knight class and body 57.

The exact logs and receipts remain in work/creatures/native-form-audit/enhanced-source-gaps/common-forms-enhanced/bone-knight-living-source. Existing Third Dawn source and mesh provenance remain with the source entries.
