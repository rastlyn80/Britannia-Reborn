# Cougar movement and corpses

Cougar body 63 retains its own Third Dawn mesh, atlas, rig and Classic clips. Its Classic definition uses the Panther's animation reference. Both Panther-linked idle gestures still play, and Classic Alert retains the Cougar's Fidget. The optional profile keeps all seven Enhanced fits. `scripts/prepare-brown-bear-cougar-enhanced.py` records the pinned archive and scene inputs.

The four-paw terrain solver checks the actual weighted skin against each tread. A Cougar turns its hind knees around the planted hocks when a calf catches a riser. The neck, head and tail can clear an adjacent higher tread independently of the torso. Before a low idle roll, the model backs away from a nearby higher tread. Its visual shift is eased and the server coordinates stay authoritative.

The original renderer penetrated by up to 117 mm on the sampled planes and 339 mm on a 22 cm step. The new renderer cleared every surface in 2,600 Classic and 4,420 Enhanced full-skin samples. In a separate 5,100-pose sequential test at 60 Hz, whole-body vertical correction stayed below 64 mm, and its combined horizontal and vertical change stayed below 46 mm per frame. The old terrain prototype could jump by 300 mm in one frame when the idle roll reached the step. Six Forward+ views exercised the final renderer.

The two original collapses retain their displayed pose at native death and settle against the actual step or slope. The terrain checks passed 72 Classic and 84 Enhanced handoffs and 3,900 collapse poses. The largest measured first-frame joint displacement was under one micrometre. The settled skin cleared the floor by about 2 mm. Normal World replay passed 12 Classic and 24 Enhanced checks, including both corpse packet orders and late dye.

The disposable server trial passed 58 checks with male and female players, including native body and hue, movement, wrestling and recoil, successful stock Animal Taming, and the visible static corpse. Fourteen explicitly sent Enhanced selectors exercised optional client playback. The fixture also checked the stock feline pack classification and native hide and meat values.

With the prepared local scenes, run `scripts/verify.ps1` or run the `scripts/test-cougar-living-*.gd` scripts through Godot with `--path Viewer`. Pass `--enhanced --enhanced-creature-actions` for the optional profile. The continuous pose test uses the Enhanced profile. Original game files, derived scenes and captures stay local.
