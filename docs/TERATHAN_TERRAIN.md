# Terathan Drone and Warrior on slopes and steps

Body 71 retains the Third Dawn Drone rig and pincer motions. Body 70 keeps the separate Warrior mesh, rig and movement. Both retain the Classic animation routes, five fitted Enhanced actions per body, and the server's hue. The renderer measures the full skin, including the forelegs and pincers, on the two sides of a step. The displayed fall passes to static corpse graphic 0x2006 with the original body and hue.

| Replay | Classic | Enhanced |
| --- | ---: | ---: |
| Living full-skin poses | 7,440 | 10,540 |
| Clipped poses before correction | 5,022 | 6,206 |
| Clipped poses after correction | 0 | 0 |
| Decoded death and corpse handoffs | 224 | 304 |
| Sampled fall poses | 3,808 | 5,168 |
| Isolated native checks | 61 | 73 |

Tests used flat ground, slopes and a 22 cm tread. Both Classic death groups and all five Enhanced fitted actions per body were included in the decoded handoff. The starting joint shift stayed below two micrometres and the frozen mesh settled about 2 mm above the support. The largest adjacent correction was about 186 mm on the Drone's Classic attack and 188 mm during Enhanced Unfold on the highest tread. The correction can still look abrupt on that tread.

The isolated server used both stock classes with each of two disposable characters. It verified their different constructor stat ranges and the stock hostility check against an Ophidian Warrior and a Terathan ally. Both clients saw the native walk, run and death. The normal client displayed the partial hue and the matching frozen corpse. Stock human carving yielded four ribs per corpse and the Drone kept its two packed spider silks. The fixture chose the walk and run directions and sent the gesture packets. Autonomous group combat was outside this check.

The initial live attempt spawned the creatures beyond the normal client's loaded preview. The client still received the corpse item and retained the completed fall. The accepted run uses the existing walkable Britain arena inside the loaded preview, selected when the creature spawns. The fixture and replay evidence remain under work/creatures/native-form-audit/enhanced-source-gaps/common-forms-enhanced/terathan-living-source. Asset provenance remains in the existing Third Dawn and Enhanced source records.
