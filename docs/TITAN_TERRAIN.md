# Titan on slopes and steps

Body 76 retains the Third Dawn Titan rig, source attack clips, earlier fitted Classic actions and five existing Enhanced fits. The renderer uses the whole skinned mesh to clear flat ground, slopes and a 22 cm step. It keeps the displayed pose through the native death packet and produces static corpse graphic 0x2006 with the same body and hue.

| Replay | Classic | Enhanced |
| --- | ---: | ---: |
| Living full-skin poses | 2,790 | 4,340 |
| Poses below the 2 mm clearance target before correction | 2,619 | 3,156 |
| Poses below target after correction | 0 | 0 |
| Decoded death and corpse handoffs | 80 | 120 |
| Sampled fall poses | 1,360 | 2,040 |
| Isolated native checks | 38 | 44 |

The first fall pose stayed within three micrometres of the displayed joints. The frozen corpse settled about 2 mm above its support. The largest adjacent vertical correction was about 224 mm during the hit reaction on the highest tread. That lift can still look abrupt.

The isolated tests used a stock Titan with each of two disposable characters. Both connections received real movement and death. The normal client displayed the native body and hue, including a partial-hue update, and the matching frozen corpse. The stock Lightning spell damaged a disposable Ogre, regular poison returned the native immunity result, and stock human carving yielded four ribs. The test read treasure map level 5 from the native definition. Autonomous spell selection and treasure-map drops were outside the test.

The staged source, replays and native receipts are in work/creatures/native-form-audit/enhanced-source-gaps/common-forms-enhanced/titan-living-source. Existing asset provenance and local-only art exclusions apply.
