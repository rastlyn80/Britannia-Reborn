# Goat, Grizzly and Grey Wolf terrain

Goat 209, Mountain Goat 88, Grizzly 212 and Grey Wolf 25/27 use the existing source rigs, atlases, packet mappings and optional Enhanced scenes. The native Grizzly and Raging Grizzly share body 212. Both Grey Wolf bodies use the same mesh because the original model table links both to `canines_wolf_grey`. Each body keeps its own server identity and corpse. The inspected Enhanced sequence archive has named entries for 25 and 212. Body 27 uses its existing Classic motions.

The shared renderer uses four weighted feet, independent terrain samples across ledges, and small head and neck adjustments when the head mesh reaches the upper tread. Running cancels a feeding or idle pose. The renderer closes the walking and running loops and carries the last displayed pose into the native death animation. The corpse is a static snapshot with the server body, raw hue and existing graphic 0x2006.

## Source records

| Bodies | Original mesh member | Mesh SHA-256 | Points / triangles / joints |
| --- | --- | --- | --- |
| 25, 27 | `Animals/canines_wolf_grey_lod2.grn` | `1074e0c43d3ce1a311c718fc3c5179a2a7ea582305d12768c9e17b7999f69079` | 146 / 288 / 32 |
| 212 | `Animals/bruins_bear_grizzly_lod2.grn` | `b2bbc385282ef6afe9b220ff3c395da9e8cf3f4ce423ea52479f2b9c7b34bfe1` | 126 / 249 / 32 |
| 209, 88 | `Animals/ruminants_goat_billy_lod2.grn`, `Animals/ruminants_goat_mountain_lod2.grn` | See the private source audit and existing preparation manifests | Separate rig and atlas for each goat |

The pinned Enhanced sequence members are `0xa75e1b8ab72c15d6` for Grey Wolf 25 and `0x766ee3a4a9fbff28` for Grizzly 212. The original frame pins and fitting recipes are in `scripts/prepare-wolf-grizzly-enhanced.py`, `scripts/prepare-goat-eagle-enhanced.py` and `scripts/prepare-blood-goat-enhanced.py`. The candidate profile verifies all three local scene fingerprints against the registry before selecting a renderer. Original and derived art remains local.

## Evidence

The two modes cleared 22,500 moving full-skin samples and 7,320 Enhanced gesture samples on flat ground, a slope and a 22 cm step. Worst original terrain penetration was 250 mm for Goat, 309 mm for Grizzly and 221 mm for Grey Wolf. The measured minimum clearance after the fix was about 3 mm. Worst loop discontinuity on the step fell from 187 to 17 mm for Goat, 368 to 69 mm for Grizzly and 287 to 34 mm for Grey Wolf. The largest one-sample vertical correction on the step was about 101 mm for Grizzly and 90 mm for Grey Wolf. Those extreme ledge crossings still merit visual improvement.

The client decoded 352 death and removal sequences and sampled 5,984 falling poses. The largest measured first-pose joint displacement was below 7 micrometres. Final frozen geometry reached approximately 2 mm clearance. Normal World replay passed 203 Classic and 215 Enhanced checks with the Goat, Eagle, Blood Elemental, Grizzly and Grey Wolf action sets.

The isolated server trials passed 416 checks for the six stock constructor cases in each client mode and across both disposable characters. The checks cover native walk and run, wrestling, raw hue, death, static corpse and taming through the normal skill target. The Raging Grizzly emits the stock taming refusal and consumes no follower slot. Each ordinary tame consumes one slot. The trial reads stock harvest counts and leaves harvesting behavior to the server.

Run `scripts/verify.ps1` with the prepared local assets. The relevant focused drivers are `scripts/test-quadruped-living-terrain.gd` and `scripts/test-quadruped-living-fall.gd`. Add `--enhanced-creature-actions` to the Godot script arguments for the Enhanced runs. The isolated native trials and exact source receipts are kept under the ignored creature audit folders.
