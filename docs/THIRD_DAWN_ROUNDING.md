Latest: [chest and face refinement](THIRD_DAWN_ANATOMY.md) retains this rounded variant as its before comparison.

# Local male head and joint rounding

Owner requested a rounder head and softer elbows/articulations while accepting the rest of the body. The private human review now compares the original cage and locally rounded geometry with the same PBR v2 material, rather than changing geometry and materials simultaneously. Head close-up is a new review view.

## Recipe and scope

Run `python scripts/prepare-third-dawn-rounded.py --archive work/third-dawn/uotdb.zip`, then `./scripts/review-third-dawn.ps1 -Human -View head`. Use `-View materials -Clip Run` for the full-body bending comparison, `-View clothing` for garments and `-Compatibility` for the fallback renderer.

The recipe reads the original male LOD2 body and Idle/Walk/Run clips. Bone weights select the head; bounded anatomical falloffs select elbows, knees, shoulders and ankles in this specific male source cage. Nose/mouth receive less smoothing. Two Loop refinement levels interpolate UV islands separately; the entire mesh is tessellated to avoid patch-border T-junctions, but shape changes are masked. The body is 362 to 5,792 triangles / 2,898 geometric vertices. Export duplicates triangle corners as before.

90 of 183 source vertices are selected. The other 93 source positions stay exactly fixed in the undeformed cage, verified during generation and by a synthetic mask test. 1,059 refined vertices outside the mask also remain on the linear source surface. The displacement budget is 40 mm in source coordinates; measured maximum is 32.585 mm (about 34.45 mm at the retained 1.8 m body scale). This is stronger locally than the earlier global 18 mm budget. Normals are regenerated across the mesh, so lighting can change outside the moved regions.

Selected skin weights receive bounded neighbour averaging (0.35 per level), then normalize to at most four influences. Unselected original vertices retain their weights. Skeleton bones, inverse bind transforms and animation tracks are retained; the existing floor-fitting export step is recomputed. Generated body variants use existing garment masks, and the original shirt/robe meshes still bind to the same skeleton. Clothing geometry/materials are unchanged in this pass.

Local ignored `Viewer/local-art/third-dawn/human-rounded-provenance.json` records exact ZIP/input/output/recipe/subdivision hashes, movement evidence and parameters. Outputs are human-rounded.gltf, human-rounded-shirt.gltf and human-rounded-robe.gltf. Original imports, older smoothing variants, source ZIP/UO installation and Documents/Codex prototype remain unchanged. This is an offline review; the default live Avatar and server are unchanged.

## Evidence and limits

Nine source-free parser/refinement tests pass. Both Forward+ and Compatibility report zero engine validation failures across five actors, three clips and four phases each (60 body samples plus 24 garment samples per renderer): finite deformed bounds, stationary roots, grounding and bounded garment deformation. Evidence: ignored `outputs/third-dawn/rounded-forward-validation.json` and `rounded-compatibility-validation.json`. Fresh head close-up, running and clothed walking captures were inspected. The crown/jaw silhouette is visibly rounder; articulation changes are subtler and do not add modern corrective muscle deformation. The old rig, face anatomy, fingers, atlas details and garment shapes remain limits. Sampled bounds checks are not exhaustive clipping/artistic approval.

Full project verification is recorded in `outputs/third-dawn/rounded-full-verify.log`. All original-derived models, atlas files, provenance and screenshots remain ignored/local; this work establishes no redistribution grant.
