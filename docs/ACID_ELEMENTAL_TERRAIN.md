# Acid Elemental terrain and corpse

Acid Elemental body 158 keeps its recovered Third Dawn rig and fluid shader. The optional Enhanced condensation and spatter guard keep their fitted source motions. Native movement can interrupt condensation and restore the original body scale.

The terrain replay sampled flat ground, a slope and a 22 cm tread. The original renderer fell below the clearance target in 1,870 of 2,170 Classic samples and 2,004 of 2,790 Enhanced samples. The new support cleared the target in every sampled pose. Classic Attack and Run can still visibly lift the mesh by about 222 mm between samples on the highest tread.

The decoded death replay passed 56 Classic and 72 Enhanced handoffs, with 952 and 1,224 full-skin samples. The largest first-pose joint displacement was 0.508 mm. The body freezes into graphic `0x2006` and clears the final support by about 2 mm.

The isolated server passed 30 Classic and 36 Enhanced checks across both test owners in each profile. Stock melee applied lethal poison to a disposable target. Both clients saw movement, native hue and the matching corpse. The Enhanced test uses a controlled condensation packet followed by a stock movement update. It verified that running resumes and the root returns to full scale.

The local scripts and receipts are under `work/creatures/native-form-audit/enhanced-source-gaps/common-forms-enhanced/acid-elemental-living-source/`. Run `audit-acid-elemental-terrain.gd` and `test-acid-elemental-falls.gd` via the local `run-stage.gd`, once per profile. The separate native harness uses the disposable server and two accounts.
