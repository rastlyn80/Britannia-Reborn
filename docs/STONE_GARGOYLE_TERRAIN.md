# Stone Gargoyle terrain and native combat

Body 67 retains its Third Dawn stone rig, grounded gestures and wing motions. Both Classic death packets use the recovered ground fall. The tested handoffs include starts from Fly, TakeOff and Land, as well as grounded and Enhanced gestures. The final display uses static corpse graphic 0x2006.

| Replay | Classic | Enhanced |
| --- | ---: | ---: |
| Living skin poses | 3,720 | 5,270 |
| Poses below clearance before correction | 2,325 | 2,630 |
| Poses below clearance after correction | 0 | 0 |
| Decoded death and corpse handoffs | 112 | 152 |
| Sampled fall poses | 1,904 | 2,584 |
| Isolated native checks | 42 | 54 |

The largest sampled correction between adjacent poses was about 297 mm during the slope landing. The largest first-pose change in the fall was 0.51 mm and the frozen mesh settled about 2 mm above the sampled ground.

Stock Stone Gargoyles walked and ran, dealt physical melee damage and left twelve iron ingots. They remained grounded and untamable in the stock constructor. Both observers received the real corpse packet. The isolated fixture set the native combat flag before sending the Enhanced combat-only feint. The first corpse trial retained a snapshot at a server location outside the loaded client map. Replaying in the loaded Britain arena verified that the same snapshot becomes visible.

Local evidence is under work/creatures/native-form-audit/enhanced-source-gaps/common-forms-enhanced/stone-gargoyle-living-source.
