# Mummy and Pestilent Bandage on slopes and steps

Both stock classes use body 154. The terrain route retains the 33-joint Third Dawn rig, bandage atlas, existing sole solver and source motion curves. It adds whole-skin clearance after the sole solver on uneven ground, including during all three fitted Enhanced actions. The same route retains the corpse body and hue for static graphic 0x2006. The ordinary Mummy and Pestilent Bandage keep their own native stats, colours and packed items.

| Replay | Classic | Enhanced |
| --- | ---: | ---: |
| Living full-skin poses | 1,860 | 2,790 |
| Poses below the 2 mm clearance target before correction | 1,497 | 2,404 |
| Poses below target after correction | 0 | 0 |
| Decoded death and corpse handoffs | 56 | 80 |
| Sampled fall poses | 952 | 1,360 |
| Isolated native checks | 61 | 73 |

The replay used flat ground, slopes and a 22 cm tread. The old skin penetrated the step by about 224 mm in the worst sampled pose. The updated path cleared it and kept the server position. The largest adjacent vertical correction was about 226 mm in the source run, which can still look abrupt on the highest tread. The first fall pose shifted by under two micrometres, including when a native Classic death animation was already underway. The frozen cadaver settled about 2 mm above the terrain.

The isolated trials used both stock classes with both disposable characters and checked the constructor hues, including Pestilent Bandage's 0x515, and a controlled partial hue on both classes. Both clients saw native walk, run and death, and the normal client displayed the matching static corpse. Applying lesser poison to the ordinary Mummy returned the stock immunity result. Pestilent Bandage's native melee damage hook applied lethal poison to a disposable target. The ordinary corpse contained ten bandages and five garlic, and the Pestilent corpse held five bandages. The fixture initiated movement, poison and gestures. Autonomous healing and combat were outside this trial.

The local study and test receipts remain under work/creatures/native-form-audit/enhanced-source-gaps/common-forms-enhanced/mummy-living-source. The original source pins are in scripts/source-mummy-inputs.json. The Mummy keeps its existing texture treatment. Its separate mask atlas remains unresolved.
