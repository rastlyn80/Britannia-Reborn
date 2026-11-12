# Original Eagle body 5

The later Age of Shadows 3D client model table contains two identical mappings from body 5 to `birds_eagle`. The static cabinet extraction recovered the exact mesh, its two TGA files, and eight distinct motions. The `death1` and `die1` members are byte-identical. The archive scan used static file reads and the shared Granny parser.

| Source | Verified value |
| --- | --- |
| Geometry member | `Animals/birds_eagle_lod2.grn` |
| Geometry SHA-256 | `d95c9c4075db7faee369c8515cb701fe6be49213c2ebb7dd37d220b96b3a3e73` |
| Geometry | 46 points, 84 triangles and 31 joints |
| Driven rig | 29 retained animated joints in each recovered clip |
| Texture | `Maps/birds_eagle.tga`, 128×128, 32-bit, variable opacity |
| Cabinet references | `models/client7.cab`, `models/animals/client8.cab`, `models/maps/client10.cab` |

The refined cage has 1,344 triangles. The uniform scale was chosen to fit the Eagle already used by the client. The refined candidate measures roughly 0.52–0.58 m tall on the perch and spans up to 2.08 m in normal flight. The original UVs, source atlas, joints and eight motion tracks are preserved. The modern surface uses the original atlas opacity, a small texture-based relief effect and the client hue palette. The second map has zero opacity throughout and RGB values 0–2. Its original interpretation remains open.

The source Run supplied the wing cycle for the new sustained flight. The candidate adds takeoff, landing, airborne attacks, hit and death, two perched gestures and both wingbeat variants. These ten motions are derived adaptations. The flat-ground audit checked 1,830 full-skin poses and 15 transition endpoints across three mesh treatments. Minimum normal-flight clearance was 16.9 cm. The lowest sampled airborne dive cleared the plane by 5.2 cm.

The World replays passed 92 Classic and 94 Enhanced checks. The uneven-ground review covered 4,340 posed skins on flat ground, a slope and a 22 cm step, with about 3 mm minimum clearance. Wing adjustments lowered the largest model shift in the Enhanced airborne wingbeat from 97 mm to 4 mm. The widest original attack can still lift the model about 166 mm at the sharp step. Decoded death, removal and corpse packets passed 40 handoffs and 680 fall samples. The first-pose difference was under one micrometre.

The isolated native trials passed 84 checks in each profile across Eagle, Phoenix and Enraged Eagle and both player sexes. They covered constructor hue and rules, movement, wrestling, landing, ground and air deaths, and matching native corpse hues. Flight height follows the client presentation. Stock Eagle and Phoenix report flight ability and 36 feathers. Stock Enraged Eagle uses melee AI with zero feathers and no flight ability flag. Idle or feeding packets no longer interrupt ongoing native movement.

## Reproduction

Run `python -B scripts/prepare-original-eagle.py --models PATH --install` with the local Age of Shadows `Models` folder. The recipe checks each recovered input against `scripts/original-eagle-inputs.json`, rebuilds the three mesh treatments and runs the posed-skin tests before writing the ignored local assets. Two independent bakes agreed on the atlas, skinned geometry, skeleton and all 486 animation tracks per treatment. The serialized scene hashes can differ across bakes.

Run `scripts/verify.ps1` to exercise the installed assets, terrain and corpse checks. When the local recipe manifest is absent, the world uses the bundled licensed Eagle. Original assets, local derived scenes and review captures remain local.
