# Original giant serpent: source motion reuse and grounded skin

Native GiantSerpent body 21 retains the Third Dawn snake's own geometry, UVs and eighteen-bone rig. The 118-point / 237-triangle source cage becomes 3,792 triangles through two bounded refinement passes. The coiled source height remains approximately 0.614 m at the model table's 1.2 scale. Its uncoiled motion is much longer than its coiled rest bounds: measured source/refined pose diagonals reach about 7.03 m. This is not a new humanoid skeleton or a held-idle walking substitute.

Only the base giant serpent is accepted here. Ice, lava and silver serpent identities, DeathAdder and other classes sharing body 21 remain separate work; this checkpoint proves the real GiantSerpent constructor, not every class sharing its appearance.

## Exact private inputs

The unchanged local archive is `work/third-dawn/uotdb.zip`, SHA-256 `d872d59a4d3f92c82672bbadb98ae44772e42b44dacb4a28a1fdf39cf121dc0e`.

| Member under `uotdb/uotd/Models/` | SHA-256 |
| --- | --- |
| `Monsters/serpents_snake_giant_lod2.grn` | `1a84d76ab90e2bf9c19b69b147cc1e9d39a9ac1f489d17dde9651e0b59f9780d` |
| `Monsters/serpents_snake_giant_silver_lod2.grn` | `fbd5b145cdf4d2b6843027a6d0bec80426901eb3549730db5c5d8d4fa83ac13c` |
| `Maps/Serpents_snake_giant_v03.tga` | `90ff2fbbb0fade01deb5ff7f94db6422f947115d29c7ec0e3f645a33199d1983` |
| `Monsters/serpents_snake_giant_idle.grn` | `9cc22004bca8605f10b986283f1ac2c1e3edfdeb5f41a934ecc98455a7d1f4b6` |

The private preparation report records every additional silver-donor clip member and hash. The base keeps its own recovered Idle: seventeen target tracks match, and eight unbound leg tracks are omitted. Walk, Run, Attack, Hit, Death and Fidget use real silver-serpent source motions, with all seventeen animated target tracks matching.

That reuse is explicitly authored; no recovered model-table link from base to silver is claimed. A new strict motion contract proves exact points, normals, triangle/corner indices, skin weights/ties, rest transforms/hierarchy and all weighted or ancestor joint names. Only the declared, unweighted mesh-label leaf differs. UV coordinates differ between the variants and are deliberately retained from the base, together with its own atlas. The original exact mesh/UV reuse contract and strict Granny reader remain in place for their existing callers.

The modern atlas is an edit using the built-in image-generation tool, saved at `Viewer/local-art/creatures/serpents_snake_giant-albedo-v1.png` with its exact sibling `serpents_snake_giant-albedo-v1.prompt.txt`. The generated 1,254-square image is retained without resizing; SHA-256 `b2a28759e2fa60e4e0de89b92ef67f9bffb5044a5b670afeb141473b9b18cdce`. Input/output hashes, mode and original tool output are recorded in `work/creatures/giant-serpent-atlas-v1.json`. It adds detailed earthy scales, belly scutes, eye and mouth detail to the existing UV layout. Surface relief is an albedo-derived shader approximation, not a sculpted normal bake. These maps, the original inputs, derived GLTFs and captures remain private and ignored.

## Corrections found through actual skin tests

The initial default export/import settings left the strike approximately 124 mm above the floor at one sampled phase. This version samples floor corrections at 120 Hz plus original source key times and disables animation key reduction/compression for this specific model. Mesh compression is also disabled for this asset. The final measured plane gap stays within 5.92 mm across all focused poses. Other creatures retain their existing import settings.

The generic runtime feeding bend drove the snake's neck about 380 mm through the floor. The converter now supplies an explicitly authored, distributed bend on the retained neck/head bones, with actual-skin floor correction. Its measured feeding underside stays within about 0.002 mm on these finite planes, while its skull genuinely lowers. This is a new feeding category, not a recovered original clip.

The generic height/coiled-bind envelope also rejected legitimate uncoiling. Optional source/refined skin measurements now record maximum posed diagonals across sampled/key times. The serpent's bounded-skin check uses those measurements plus a declared ten-percent interpolation margin. Existing exports leave that option off. A separate ignored-output regeneration proves all three existing Zombie GLTF files remain byte-identical; accepted Zombie assets were not overwritten for that check.

The actual avatar uses plane support without invented foot chains, its own animated skull/nameplate anchor and a 0.45 m camera height. A conservative measured Idle/Walk/Run selection box covers the long skin; it is not precise triangle picking or a complete strike/death sweep. The corpse preserves the final recovered Death skin, approximately 0.531 m tall, rather than imposing an arbitrary 0.5 m height limit. It is grounded, static and rig-free, with native graphic `0x2006`, amount/body `21`, victim facing and raw hue. Future accepted bodies continue to acquire graphics-catalogue cadavers automatically.

## Evidence

| Check | Verified result |
| --- | --- |
| Source/refined pose and skin | 616 checks / 189 complete skins, zero failures |
| Standard Forward+ visibility/full dye | 13 checks / six views, zero failures |
| Actual registered avatar | 2,645 checks / 432 terrain poses, zero failures |
| Terrain scope | Seven recovered categories plus authored Eat; nine phases on each of six raised/lowered flat/sloped planes |
| Final corpse | Actual final death skin dimensions match the static cadaver within 1 mm |
| Actual disposable native server | 96 checks on two characters, zero failures; real GiantSerpent constructor/body 21 |
| Whole static corpse catalogue | 172 variants / 1,615 fresh rendered checks, zero failures |

The native test uses genuine world entry, native Move walk/run, hurt/action/death packets, hue changes and corpse replication on both clients. AI is frozen for controlled sampling. Production, its accounts/configuration/saves and the original installation are untouched. This is not autonomous AI, taming or universal gameplay certification.

Full hues visibly change the rendered skin. Raw partial bits and palette/shader bindings are retained; the generic neutral-pixel heuristic changes only sixty sampled pixels in this view. No recovered exact UO partial mask or complete partial-dye coverage is claimed. Arbitrary terrain/obstacles, exact original choreography and extended modes, final anatomy/surface polish and broader native identities remain open.

Final focused logs are `work/creatures/giant-serpent-{contract-tests,export-defaults,final-validation,native}.log` and `work/creature-checks/serpents-{poses,gpu,avatar}.log`. Earlier failed probes are retained as diagnostics and superseded by the final zero-failure reports. Shared regression and root verification are tracked in the current PROGRESS entry.

## Reproduction and next identities

Run `python -B scripts/prepare-creature-kind.py serpents_snake_giant`, then `scripts/test-creatures.ps1 -Families @('serpents')`. Import precision, actual source/refined skins, measured avatar/terrain/feeding/hue/selection/corpse checks and six standard rendered views must pass before acceptance. Acceptance checks exact preparation, asset/import and critical runtime hashes. Previous family preparations are archived; unrelated, unaccepted variant art is not activated.

Run `scripts/test-horses.ps1 -Live -SkipContact -CreatureFamily serpents` against the disposable loopback test server, `scripts/build-corpse-catalogue.ps1 -Render`, the shared accepted-family regression and `scripts/verify.ps1`. Local loopback access is needed for native testing; no production connection or save copying is required.

Continue occurrence-first with JackRabbit/Rabbit, SeaHorse, Wisp, AirElemental and the remaining queue. A safely loaded independent rabbit donor is now audited and rendered as an unaccepted five-source-clip trial. Its creator listing and embedded licence both specify CC0; no Third Dawn rabbit mesh was found in this archive audit. The trial does not add a body route or coverage. Exact source, images and licence evidence remain under the ignored `work/creatures/rabbit/` folder until the full replacement is ready.
