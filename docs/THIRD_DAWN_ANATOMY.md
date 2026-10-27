# Male chest and face refinement

The owner approved local head/joint rounding and requested a more human chest and less angular face, supplying a side-view screenshot. The current offline review compares that exact previous rounded mesh (left) with this anatomy pass (right), using identical PBR v2 materials and lighting. Prior rounded imports are retained.

## Reproduction and method

`python scripts/prepare-third-dawn-rounded.py --archive work/third-dawn/uotdb.zip --anatomy`

`./scripts/review-third-dawn.ps1 -Human -View bust -Angle profile`

Use `-Angle front` or `-Angle three-quarter`, `-View head` for closer facial review, `-View clothing -Clip Run` for wardrobe, and `-Compatibility` for the alternate renderer. Angle buttons rotate the actors identically. Head/bust use an orthographic camera to remove different perspective angles between comparison subjects; orbit and wheel zoom remain available.

The source-specific recipe raises/reduces the low chest apex through bounded smooth falloffs, lightly fills the cheeks and softens the chin transition. A broader chest support mask and stronger face rounding retain the previously improved scalp/joints. It keeps the same 5,792 triangles / 2,898 geometric vertices as the prior local refinement; this pass changes shape rather than merely adding polygons. The native UV atlas, material and source rig are reused. Original clothing is unchanged and shares the same skeleton with existing garment-specific body masks.

108 source vertices receive smoothing; 75 original source positions remain fixed. Direct cage correction peaks at 29.883 mm; subsequent masked rounding moves at most 33.850 mm relative to its corrected linear reference. Combined upper bound is 63.733 mm; the measured maximum at original source vertices is 45.702 mm. Units are source-space metres, with the existing 1.8 m body scale retained. These conservative stage bounds are not an assertion that every final vertex moves by that amount. Local ignored human-anatomy-provenance.json records exact archive/input/output/code/comparison hashes and parameters. Source ZIP, UO installation, previous imports, original Documents/Codex prototype, saved login and server state are unchanged.

## Evidence and remaining limits

Ten source-free parser/refinement tests pass, including symmetric/local chest/face correction without source mutation or rig/UV changes. Actual imported files retain 34 identical bones, identical inverse binds and all 186 bone animation channels across Idle/Walk/Run, byte-compared with the previous rounded model; only visual floor fitting is recomputed. Evidence is outputs/third-dawn/anatomy-rig-check.json.

Forward+ and Compatibility validation each report zero failures across five actors, three clips and four sampled phases (60 body samples and 24 garment samples per renderer). Checks cover finite skin deformation, stationary roots, grounding and garment bounds. Fresh profile and three-quarter close-ups show the reduced chest wedge and softer face. The running garment capture was inspected; the old robe still has coarse angular folds. These checks do not prove exhaustive clipping freedom or modern facial anatomy. Eyes, lips, ears and muscle detail still rely heavily on the old atlas and generated normal map; no new facial expression rig was added.

Full project verification passes (exit 0), with no script/parser errors in the final log outputs/third-dawn/anatomy-full-verify.log. Its first attempt exposed an unrelated negative bit-shift parse error in Reconstruction.gd; parenthesizing the positive shift before negation fixes the one-line roof sentinel expression without changing its intended value.

All derived meshes, imagery, provenance and captures remain local/ignored. This pass establishes no redistribution rights and does not change the live default Avatar.
