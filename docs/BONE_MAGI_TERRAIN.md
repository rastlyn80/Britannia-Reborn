# Bone Magi terrain and staff

Body 148 retains its Third Dawn rig, staff, two Classic falls and five fitted Enhanced actions. The staff and body share the terrain support calculation. During staff gestures, the renderer supports the complete pose without the leg correction used for walking and running. This keeps the baked staff gestures stable across treads.

| Replay | Classic | Enhanced |
| --- | ---: | ---: |
| Living skin poses | 3,410 | 4,960 |
| Poses below clearance before correction | 3,120 | 4,229 |
| Poses below clearance after correction | 0 | 0 |
| Decoded death and corpse handoffs | 104 | 144 |
| Sampled fall poses | 1,768 | 2,448 |
| Isolated native checks | 46 | 52 |

The largest sampled adjacent correction was about 218 mm in the Enhanced rise on the high tread. The static corpse retains the staff and settles about 2 mm above sampled support.

Native tests verified regular poison and bleed immunity, Fey opposition, Lightning damage and packed bone and necromancy reagents. The stock creature's Lightning used the real spell and target cursor. The pinned server's spell timer reserves Classic group 12 for player-controlled monster bodies.

Local evidence is under work/creatures/native-form-audit/enhanced-source-gaps/common-forms-enhanced/bone-magi-living-source.
