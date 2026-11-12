# Dog terrain, coat hues and corpses

Dog body 217 uses the original Third Dawn hound scene with its existing Classic clips and optional Enhanced actions. `scripts/prepare-hound-bear-enhanced.py` pins those assets and source frames. Both original idle gestures yield to movement. The renderer reuses the step and fall solver checked on the Cougar, while the Dog keeps its own model, rig and animation selections.

The baseline reached 25 mm of penetration on sampled planes and 312 mm on a 22 cm step. The renderer passed 2,340 Classic and 3,900 Enhanced full-skin poses with at least 2.99 mm of clearance. In 5,070 sequential poses at 60 Hz, whole-body lift peaked at 85 mm and its combined correction moved up to 60 mm in a frame. Both peaks occurred during an idle roll close to the step. Six Forward+ views exercised the terrain renderer at both ends of the native coat range.

The two collapse groups passed 72 Classic and 84 Enhanced handoffs and 3,900 fall poses. The maximum measured first-frame joint movement was 7 micrometres. The settled skin cleared the floor by about 2 mm. Normal World replay passed 12 Classic and 24 Enhanced checks, including both death-packet orders and later corpse dye.

The isolated server passed 58 checks with male and female characters. Both clients received the native coat selected by the server, the movement, melee and recoil, and the final corpse. The two dogs in that trial had initial hues 2304 and 2309, and each passed stock Animal Taming. Fourteen controlled Enhanced selectors exercised the optional client motions.

Run `scripts/verify.ps1` with the existing hound scenes installed, or run the `scripts/test-dog-living-*.gd` scripts through Godot with `--path Viewer`. Pass `--enhanced --enhanced-creature-actions` for the optional profile. The continuous motion test uses the Enhanced profile. Test accounts, original game files, prepared scenes and captures stay local.
