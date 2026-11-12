# Ratman Archer

ModernUO constructs body 142 with a Bow in the two-handed slot. The client uses the original Third Dawn Ratman rig and displays the original bow for either native graphic, `0x13b1` or `0x13b2`. The body keeps the server hue. The bow has its own item hue.

Stock ranged combat sends a moving effect with graphic `0x0f42`. The client uses that packet to turn the shoulders, bring the right hand onto the string, release the arrow from the nock and recover into the active gait. The four-tenths-of-a-second pose leaves the original foot motion in place. The server still decides targets, damage and timing.

The native corpse uses graphic `0x2006`, amount 142, and the server hue. ModernUO removes the worn bow on stock monster death. If a death notification arrives with the bow still visibly equipped, the falling pose and its frozen snapshot retain the bow. A later body dye leaves the captured bow material intact.

## Original sources

The Third Dawn table names `rat_race_ratman` for body 142. Its later cabinet mesh has 221 original points, 434 triangles and 45 joints. The recovered mesh SHA-256 is `c7c164d6ab3b13a670d7ad383e16f0ff1e11ef75425fa0ad9fa759644e22b906`. Body 142 has no exact named sequence in the pinned Enhanced index. The draw and release were authored on the recovered rig.

The early Third Dawn table names `Weapon_Bow` as model 649. The original bow mesh has 92 triangles. The inspected member `uotdb/uotd/Models/Others/Weapon_Bow_LOD2.grn` has SHA-256 `6bc7068bdfae66dfc7362ada9e96473c2563015b03f625fec6d10fd69bd27b9e`. The fitted bow uses the exact mesh and atlas with a scale of 0.60 on the Ratman. The bow string deforms between its recovered anchors. The arrow model by Teslov uses CC BY 4.0 with attribution in the [art manifest](../Viewer/Art/Objaverse/manifest.json).

## Reproduction

Use the accepted local `rat_race_ratman` source body and run `python -B scripts/prepare-centaur-bow.py` with the pinned local Third Dawn archive. Keep the original assets and derived scene files local. Run `scripts/verify.ps1` to exercise both client profiles. The focused replay runs `res://../scripts/test-ratman-archer.gd` at 120 frames per second from the Viewer project.

The normal World replay passed 45 checks in each profile. It includes nine idle, walk and run aim cases, worn-item and body dyes, a shot interrupted by death, and the frozen corpse. Two isolated clients passed 31 native checks in each profile, using both player body sexes as targets. The test fixture positioned the combatants and invoked the equipped stock Bow's ranged attack. The server produced the arrow, worn-item removal and corpse. Six Forward+ renders show the carry, draw and follow-through.
