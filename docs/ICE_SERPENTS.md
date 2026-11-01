# Ice Serpent: retained Third Dawn body89

Native IceSerpent89 uses its recovered Third Dawn mesh, eighteen-joint rig, own UVs and original opacity map. Compatible Silver-serpent motions are reused under an explicit measured source contract. The detailed ice atlas, head RGB registration, partial-dye region, shorter active jaw gape, feeding gesture and shared vertical ground correction are authored adaptations. This is bounded integration evidence, not complete original choreography, final art or autonomous gameplay certification.

## Sources and boundaries

The local `work/third-dawn/uotdb.zip` archive is pinned by `audit-creature-sources.py`; its SHA-256 is `d872d59a4d3f92c82672bbadb98ae44772e42b44dacb4a28a1fdf39cf121dc0e`. Important members include:

- `uotdb/uotd/Models/Monsters/serpents_snake_giant_ice_lod2.grn`, SHA-256 `526bf19da1bcd3b63f654294e2ae81f5a976401de11d02e580c534f21c5b48e2`.
- `uotdb/uotd/Models/Maps/serpents_snake_giant_ice_v02.tga`, SHA-256 `da1f9603393c7b8e790def6ef05d92b71c6eb6edc2251365dc5b13e1519e5b6e`.
- The named Silver-serpent Idle, Walk, Run, Attack, GetHit, Death and Fidget GRNs, with exact member hashes recorded in the private preparation report.

The archive model table explicitly associates89 with the ice mesh and animation body21. The Ice and Silver meshes have equal source points, normals, polygons, weights/ties, rest transforms/hierarchy and all seventeen weighted ancestor names after the declared bind conversion. Their own UV coordinates/atlases remain separate. Only the explicitly unweighted scene label at index17 differs. `assert_motion_contract` verifies those facts; this does not establish intended original animation semantics or exact animated scale/shear fidelity of the legacy rigid/affine conversion.

The source mesh has237 triangles; bounded refinement produces3,792 triangles while retaining the original hierarchy/material islands. Maximum source-cage displacement is0.023334 source units before the final model scale (not a world-space millimetre measurement). Source and refined versions remain available for comparison. Native ModernUO classification is **monster**, despite the class residing in the Animals/Reptiles folder. No game executable is run and no server core/gameplay source is changed.

Original maps/models/animations, generated derivatives, palettes, local reports and rendered captures remain excluded from Git. Only original project conversion/runtime/tests/documentation are published; source possession does not grant redistribution rights.

## Surface and motions

The selected private atlas is `work/creatures/ice-serpent/ice-serpent-albedo-v2.png`, SHA-256 `6ca71957364122b3926cfd01e2d45d1846360f811da9d2c87bdfd9fde46d810a`. It was made with the built-in image-generation tool. Exact prompts are retained in `texture-v1-prompt.txt` and `texture-v2-prompt.txt`, with provenance alongside. The generated eye landmarks drifted; a declared bounded head RGB sampling transform registers them to the original head. Original mesh UVs and opacity sampling remain unchanged. This is not a claim that the generated raster preserves every original UV landmark.

The original64-square map contains opacity, including46 texels below half alpha. Losing that channel makes tooth/mouth surfaces solid. `IceSerpentSurface.gdshader` samples this original alpha independently of RGB registration. The named `_m` source map is entirely zero in this archive, so its purpose is unproved and it is not used as a recovered partial-hue mask. Partial dyes use an explicit authored neutral-ice region; raw server hue bits remain intact. Restrained albedo gain, diffuse reflectance and fine albedo-derived relief replace the over-bright surface. No sculpted/recovered normal map is claimed.

All seven source categories remain. Original Attack is retained as `SourceAttack`; the active Attack limits only the lower-jaw angular excursion from Idle to32degrees. Off-grid measurements find31.99998degrees active versus50.57026degrees in retained SourceAttack. An authored source-rig neck/head feeding bend supplies Eat, and the common runtime LieDown category copies Death. These are nine saved and ten runtime categories.

The source's uncoiled motion envelope reaches7.0312m diagonal; a coiled rest box is insufficient. Cached positive bone-influence boxes conservatively contain each actual animated skin and drive picking/nameplate bounds. The existing avatar updates the collider's size and centre as poses change.

## Ground correction

A30Hz export left a123.9mm attack gap. A240Hz floor bake reduced this, but a second imported240Hz correction still missed a13.43mm off-grid intersection. Those trials were rejected without relaxing the8mm ground tolerance.

`BakeIceSerpentGround.gd` instead measures each actual imported complete skin offline at960Hz:11,090 samples for each of original/rounded/modern. `SourceGroundLookup.gd` samples the resulting scalar curves at runtime. `IceSerpentVisual.gd` applies the correction to the complete model and updates bounds; native entity coordinates and relative joint motion stay separate. Steady clips use only the scalar lookup. A final actual crossfade probe exposed up to137.7mm sinking/198mm floating between individually grounded poses. During the short crossfade window the visual now measures cached unique weighted points against the current support plane; the rest of playback keeps the scalar lookup. The cache merges UV/normal-seam duplicates without changing positions or skin weights:1,849 points instead of11,376 imported vertices. Finite-plane alignment preserves the model's configured proportions. Arbitrary terrain remains unproved.

`IceSerpentTransitionTests.gd` independently skins the complete imported arrays and samples7,600 actual mixed poses at five playback rates and30/60Hz plus864 poses on six real raised/lowered finite-plane collider configurations. All24,548 checks pass: flat gaps -1.568mm to+4.704mm; plane gaps -0.285mm to+0.251mm. Temporary support costs a approximately370microseconds per evaluation on this host in the isolated test; this is not a general game-performance guarantee.

The same test exposed a shared native-action duration bug: global locomotion speed could multiply the packet's custom animation rate. `CreatureVisual.receive_action` resets that global rate before applying the packet duration. Actual attacks requested for800ms reach their half/final animation times at400/800ms after slow, normal and fast gaits. Current shared/public/native regression is required after this common runtime change.

## Current focused evidence

| Gate | Result |
| --- | --- |
| General imported source/refined/modern poses |682 checks /210 complete skins, zero failures |
| Actual avatar plus paired refined/modern poses |1,366 checks /230 paired skin poses, zero failures; retained relative-skin error0 after shared vertical translation |
| General Forward+ visibility/full hue |14 checks /six views, zero failures; source cutouts visible across the view set |
| Actual Forward+ avatar, hues, opacity, head registration, picking, terrain and corpse |4,102 checks /660 finite-plane poses, zero failures; maximum absolute underside gap4.898mm |
| Native IceSerpent on both disposable owners |126 checks, zero failures; real world entry, movement/gaits, hit/actions, colours, death and corpse replication |
| Actual mixed poses/native action duration |24,548 checks /7,600 flat mixed poses /864 finite-plane mixed poses, zero failures |
| Candidate corpse catalogue |Native body89 /graphic0x2006, ten checks, zero failures |

Full and partial hues change2,488 and732 sampled pixels respectively; their images differ by1,756 pixels. Original tooth/mouth opacity removes348 close-up pixels, and head RGB registration changes8,985. Both native clients receive the exact raw hues. The native type14 scavenging request selects this serpent's declared Eat replacement. The live harness verifies the decoded type before checking the explicit per-body replacement, rather than assuming every monster uses the same clip label.

Native AI is frozen for controlled sampling. These are actual native packet/world/movement/action/corpse tests; autonomous cold-damage combat, loot behaviour, charm interactions and full gameplay are not certified. The failed first native run exposed the harness's hard-coded type14 label; the corrected run is error-free. Production runtime, accounts and saves are excluded.

Receipts: `outputs/creatures/ice_serpents/{validation,appearance,actions,transitions,live}.json` and `presentation/validation.json`. Logs: `work/creatures/ice-serpent/`. Current public Air/Fire/Bogling/Chicken controls pass544/1,416/2,295/1,176 Forward+ checks and480/320/166/112 native checks, with clean distribution and strict gates refreshed. All44 accepted local groups/110 forms pass76,508 current pose checks/23,121 complete skins and1,508 fresh standard GPU checks/660 views plus focused gates. All184 corpse variants pass1,733 rendered checks. Current scripts/verify.ps1 exits0 with71 server-extension/84 developer-edit tests and clean final world startup. Existing Unicode/teardown diagnostics and two nullable warnings in unchanged PreviewTools tests remain. Current public controls are in public-controls-final.log; current44-group exact pose/GPU inputs,184corpse variants/1,733renders and full root verification pass after the transition/timing correction. The first current660-pose sweep reached its900s deadline. Adaptive settling now retains all660poses, the same geometry tolerances and a real support-convergence check:651poses use3settling frames; six changed-plane configurations use22, and three others use4/5/7. The revised current GPU gate passes4,102checks/660poses with4.898mm maximum gap. The original batch driver exits1 for that initial Ice timeout; its43 unaffected families passed, and the targeted Ice rerun passes current strict acceptance separately. Logs: shared-regression-final.log, presentation-adaptive.log, accept-current.log, corpses-current.log, full-verify-final.log and public-controls-final.log under the Ice Serpent work folder.

## Reproduce

1. Keep the exact original archive and separately generated atlas/prompts in their ignored local locations. `python scripts/prepare-ice-serpent.py --prepare` validates the source contract, prepares all three treatments and preserves SourceAttack beside the declared jaw amendment. It installs no accepted route.
2. Configure/import the `ice_serpents` family with `configure-creature-imports.py`, Godot import, then configure/reimport as needed. Imports use240Hz, uncompressed meshes and disabled animation optimization/compression.
3. Run `BakeIceSerpentGround.gd`, then `python scripts/prepare-ice-serpent.py --finalize`. Finalization verifies every sampled asset/import/recipe hash before recording the lookup dependency. It grants no acceptance.
4. Run `IceSerpentTransitionTests.gd`, `IceSerpentActionTests.gd`, `CreatureTests.gd -- --family=ice_serpents`, `CreatureAppearanceTests.gd -- --family=ice_serpents` with Forward+, and full `IceSerpentPresentationTests.gd`. Its optional `--appearance-only` probe does not produce a full acceptance receipt.
5. `python scripts/accept-creatures.py ice_serpents` requires exact current pose, paired-skin, complete terrain, material, lookup and corpse evidence. Then use the already-authorized disposable loopback2594 native harness: `scripts/test-horses.ps1 -Live -SkipContact -CreatureFamily ice_serpents`. Do not use production saves/accounts.
6. Refresh current public controls, all accepted source groups, rendered corpse catalogue and `scripts/verify.ps1`; rebuild the creature/action work boards. Publish only verified owned code/notices/documentation and independently licensed assets, retaining proprietary-derived data outside Git.
