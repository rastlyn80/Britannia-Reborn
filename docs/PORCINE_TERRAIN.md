# Pig and Boar on uneven ground

Native Pig body 203 and Boar body 290 keep their separate original cages and textures. Each original cage contains 154 points, 264 triangles and 35 joints. Boar keeps its six prepared Enhanced motions. Pig uses its existing Classic motion in both profiles.

| Body | Original member | SHA-256 |
| --- | --- | --- |
| 203 | `Animals/porcines_pig_lod2.grn` | `3d35a516e2df77067b13ec2da2359ff84735bcac379e3d64c6039bf410215039` |
| 290 | `Animals/porcines_boar_lod2.grn` | `a88d767ccb150d4041a20a072d86fab25347f9afb09a8a4d5e7dfe7e4c83e9d2` |

Boar uses the exact named Enhanced sequence member `0xbeec0771a0369d8a`. The source frame pins and existing pose fit recipe are in `scripts/prepare-corpser-boar-enhanced.py`.

The leg adjustment works in each joint's parent space so it preserves the original scale and translations. Nearby higher treads lift a walking hoof in advance. Across 9,000 gait poses and 2,928 Enhanced gestures, the skin cleared the sampled terrain by about 3 mm. The largest measured gait seam on the 22 cm ledge fell from 147 mm to 64 mm. The largest remaining one-sample whole-model lift was about 67 mm.

The client passed 136 decoded fall transfers and 2,312 posed skins. The largest first-frame joint displacement was under 4 micrometres. Both stock constructors passed 74 isolated checks in each mode, including movement, wrestling, dye, actual Animal Taming and exact corpse bodies and hues. Pig returns one meat and Boar two in their stock properties. Each tame uses one follower slot.

The shared regression runs through `scripts/verify.ps1` with the prepared local art. It includes `test-quadruped-living-terrain.gd` and `test-quadruped-living-fall.gd` in both profiles. Original inputs and derived art remain local.
