# Lava Lizard on slopes and steps

Body 206 retains the Third Dawn Lava Lizard, recovered atlas and 29-joint rig. The rounded mesh refines the original 258 triangles to 4,128. It retains the seven source motions and the earlier authored feeding bend. The stock fire-breath packet starts an authored windup on the recovered neck and head. The projectile leaves the original `cp_emit_mouth` socket in both client profiles. The server controls when the projectile launches and when it damages its target.

| Replay | Classic | Enhanced |
| --- | ---: | ---: |
| Living full-skin poses with the breath windup | 2,480 | 2,480 |
| Poses below 2 mm clearance after correction | 0 | 0 |
| Decoded death and corpse handoffs | 72 | 72 |
| Sampled fall poses | 1,224 | 1,224 |
| Isolated native checks | 46 | 46 |

The original Classic renderer missed the 2 mm clearance target in 2,159 of 2,170 poses. The new route keeps the original body, hue and motions on flat ground, slopes and a 22 cm step. It applies whole-skin clearance across the two treads and retains the displayed pose through a native death handoff. The worst adjacent vertical correction was about 217 mm in the attack on the highest tread, so that motion can still lift abruptly there. The fall starts within two micrometres of the displayed joints and settles about 2 mm above the support. The frozen corpse uses graphic 0x2006, body 206 and the server hue.

The disposable server used one stock Lava Lizard with each of two characters per client profile. Both connections received the actual fireball after the native windup. The normal client launched it from the animated mouth and the stock timer damaged a disposable Ogre Lord. Both clients received walk and run movement. The normal client preserved a rolled source hue and a controlled partial hue through the matching visible corpses. Native human carving yielded 14 spined hides and the corpses held the stock sulfurous ash. The fixture selected the fire-breath target, movement and hue. Autonomous combat, taming and metal or gold feeding were outside this trial.

The prior asset provenance stays in the local accepted index. The staged renderer, step and death replays, and native receipts are under work/creatures/native-form-audit/enhanced-source-gaps/common-forms-enhanced/lava-lizard-living-source. The release includes the owned renderer and shared fireball socket dispatch.
