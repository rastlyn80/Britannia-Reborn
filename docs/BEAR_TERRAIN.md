# Black and Brown Bear terrain and corpse support

Bodies 211 and 167 use their own Third Dawn meshes, coats and rigs. The existing Classic definitions link Brown Bear to Black Bear for the Classic animation references. The optional Enhanced profile keeps each bear's seven previously fitted motions, including the separate wake and rise motions. The exact archive and scene pins remain in `scripts/prepare-hound-bear-enhanced.py` and `scripts/prepare-brown-bear-cougar-enhanced.py`.

The terrain renderer measures the weighted front paws and forearms, and the hind paws and hocks, against their own support surfaces. Near a riser it aligns the body using the four paw contacts. If the chest or head is low enough to touch the upper surface, a bounded lean gives it clearance before the paw solve. The visual adjustment leaves server movement coordinates authoritative.

The baseline had up to 102.43 mm of penetration on the sampled planes and 365.18 mm on a 22 cm step. The candidate passed 5,200 Classic and 8,840 Enhanced full-skin poses. Minimum measured clearance was 2.99 mm. Whole-body lift reached 19.46 mm in a Classic attack and 36.98 mm in the Brown Bear's Enhanced wake and rise. Six Forward+ views exercised the actual step support.

Normal World replay passed 24 Classic and 48 Enhanced checks. Both original idle gestures yield to movement. The frozen corpse keeps the bear body and geometry through both death-packet orders and later server dye. The isolated server trial passed 105 checks across Black Bear, Brown Bear, Grobu and Enraged Black Bear with both player sexes represented. It checked stock movement, wrestling, recoil, successful native taming for both ordinary bears, Grobu's fur loot and the Enraged Black Bear's native summoner and taming restriction. Twenty-eight controlled Enhanced packets exercised client playback.

With the local art installed, run `scripts/verify.ps1` or run `scripts/test-bear-living-terrain.gd` and `scripts/test-bear-living-world.gd` using Godot with `--path Viewer`. Pass `--enhanced --enhanced-creature-actions` for the optional profile. Test accounts, art and captured frames remain local.
