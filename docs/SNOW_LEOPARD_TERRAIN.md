# Snow Leopard actions, terrain and native corpses

The Snow Leopard constructor can return body 64 or 65. Both retain the Third Dawn snow-leopard mesh, its coat and the original 32-joint rig. The stock client definitions redirect both animation bodies to Panther 214. The four fitted motions use the existing Panther reference and the Snow Leopard's own skeleton and skin. Classic groups 6, 8, 9 and 10 select the rear swipe, side fall, stretch and sniff. Group 12 retains the recovered original fall. Each body keeps its own native ID and hue on static corpse graphic 0x2006.

| Replay | Classic | Enhanced |
| --- | ---: | ---: |
| Living skin poses | 5,200 | 5,200 |
| Poses below 2.5 mm clearance | 0 | 0 |
| Decoded fall and corpse handoffs | 176 | 176 |
| Sampled fall poses | 2,992 | 2,992 |
| Isolated native checks | 57 | 57 |

The existing uncorrected motion was below the clearance target on 3,450 of 3,640 Classic samples, with a deepest overlap of about 339 mm. After correction, the lowest measured living clearance was about 3 mm. The highest measured visual lift was about 113 mm. The tested fall transfers moved the first pose by at most 3.5 micrometres and settled each static corpse about 2 mm above the sampled support.

Both native body rolls were constructed by the stock server. The isolated players used the normal taming skill and target packets, and the server assigned each owner and follower slot. Both profiles passed native walking, running, swing and hit packets, full and partial hues, and the frozen corpse. A human carver recovered nine hides with the racial bonus and one rib.

Rebuild the local original, rounded and modern scenes with the project's Godot executable and `--headless --path Viewer --script res://../scripts/bake-snow-leopard-actions.gd`. The recipe uses the existing validated Snow Leopard model and the Panther fitting code. The generated scenes and their receipt remain under the ignored local creature art directory. The two Classic redirects and the Panther reference frame pins are recorded in the existing creature action and field fauna catalogues. Local evidence for this batch is in work/creatures/native-form-audit/enhanced-source-gaps/common-forms-enhanced/snow-leopard-living-source.
