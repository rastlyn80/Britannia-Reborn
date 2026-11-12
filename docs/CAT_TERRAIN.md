# Cat, Hell Cat and Diseased Cat on uneven ground

The public Cat keeps the independently licensed Quaternius rig, materials and animations. Its six material surfaces retain eight skin influences per vertex. The optional Enhanced profile adds the same existing frame-referenced gestures. The same terrain renderer handles both profiles.

The terrain renderer measures all visible surfaces, bends each paw within a limited range and uses both treads for stepping and falling. Native position and facing remain authoritative. Classic groups 8 and 12 retain their distinct falls. The exact five-frame Hell Cat fire-breath request still plays Alert, and the server's moving fire effect follows it. The server also supplies the coat and static corpse for all three native identities.

## Verification

- The client sampled 2,600 Classic and 4,160 Enhanced poses across three planes, a 22 cm step and four facings. The minimum clearance was 1.497 mm.
- The continuous check sampled the published walk, run and gallop speeds at 60 Hz. On the 10 cm step, the maximum per-frame vertical visual changes were 35.0 mm walking, 28.3 mm running and 60.6 mm galloping. The 22 cm step still produces up to 120 mm at full gallop and 159 mm during the Enhanced spring gesture at the lip.
- The client checked 156 fall transfers and 3,900 fall samples. The first displayed pose stayed within 0.51 mm of the source pose. The final clearance was within 0.002 mm of its 2 mm target.
- The two normal World replays covered both corpse packet orders, later corpse dye and the stock Hell Cat action signature. The clean public client passed all 556 distribution checks with no original UO assets present.
- Two isolated ModernUO clients passed 172 checks covering Cat, Hell Cat and Diseased Cat. The test used controlled Enhanced packets for selector coverage and observed the Hell Cat's stock combat AI and fire effect.

Run the three `scripts/test-cat-living-*.gd` checks or `scripts/verify.ps1`. Run `python -B scripts/test-cat-distribution.py` to reproduce the clean public build check. The original reference frames and test captures stay local.
