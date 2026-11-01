# Rabbit and JackRabbit: independent source rig and calibrated hops

Native Rabbit and JackRabbit share body 205. This checkpoint supplies one independent CC0 model for both, preserving the actual server hue and statistics. Both real constructors are tested separately; one body route does not stand in for two constructor tests. The package retains the artist's 37-bone rig, body mesh, separate alpha fur, UVs, albedo maps and actual normal map. The 2,640-triangle source becomes 7,884 triangles through one declared body subdivision pass; original fur-card topology remains intact.

## Source and licence

Creator: Čestmír Dammer (CDmir), for Kelgar. The listing names TinyWorlds as collaborator; the embedded licence credits ideas by Rick Hoppmann and Keppu. Both the [creator listing](https://opengameart.org/content/rabbit-0) and embedded `License` text specify CC0/public domain.

- Download: `https://opengameart.org/sites/default/files/rabbit.blend`
- Source file: 5,996,916 bytes, SHA-256 `bb6deef1ee91b21380355138374cae87946451ce864502b1af68eb60f4750843`.
- Pins: `scripts/rabbit-inputs.json`, including the embedded licence and all three packed-image hashes.
- Public package: `Viewer/Art/Creatures/Rabbit/`, with notice, exact provenance, GLB, three original extracted PNGs and their import settings.
- Public GLB SHA-256: `ad5bf072996028713b2ad092bd04ff42d90f536bd7dc5bb0ab701c83d59866a4`.

The extracted map hashes match the original packed image bytes: `Fur-skin` → `81bbbddae95938a74bd873491588475a469895f1045e78a0da83ca85b3985c25`; `rabbit-NORM` → `000bbb47c2bfc17d8f0839d0bd3c57485389309a971c914ec7177bb0347b428c`; `rabbot-skinn` → `96f367bce29f79d1e0ae037440d85c3fd87b7bd003e711964581fe65a04229b0`.

Only trusted Blender is executed, with factory startup, disabled automatic scripts, `open_mainfile(..., use_scripts=False)` and a nonzero Python error exit. The original source file is not modified. No game-derived mesh, atlas, rig or animation is included in this independent public bundle. Conversion, refinement, authored categories, gait reconciliation and shaders are original GPL-3.0-or-later project work; the donor's CC0 exception remains explicit.

## Motion and skin corrections

Five evaluated donor motions remain: Sitting → Idle, Running → Run, Dying → Death, Guarding and Jump. Original constraint results are baked before constraints are removed. Walk is an explicitly adapted Running cycle; Attack, Hit, Eat, Fidget and the short native Alert are authored on the retained rig. The long Guarding source remains available separately. Eleven categories are stored; source/adapted/authored origins and timing remain explicit. These are not recovered original UO choreography.

Legacy skin weights slightly exceeded one. Normalizing their ratios before export avoids the exporter's implicit clamping. Original ninth influences contain only numerical tails below 1e-12 of total weight. Subdivision introduces small additional influences; the explicit eight-influence budget discards at most 0.16351 percent on the refined body, below its declared 0.2 percent limit. Subsequent copied-mesh validation requires no hidden repair. Skin bounds and floor calculations use the same normalized weights as the exported asset.

The donor's planted paw velocities varied substantially between phases. `creature-rabbit-gaits.py` measures the actual weighted fore/hind sole points and derives a small longitudinal presentation offset, with a circular Hermite reset while airborne. The offset is applied through the separate `RabbitMotion` ancestor, retaining every original rig channel and relative joint pose. The native entity transform is never moved by the presentation correction.

Shortening the exported fast cycle initially lost pose detail. The final version retains original key density/durations and uses declared runtime playback rates instead. Actual avatar tests measure effective stance speeds of approximately 1.7998, 2.4398, 5.4999 and 6.7999 m/s at requested speeds 1.8, 2.44, 5.5 and 6.8 m/s. Original positive hop clearance remains; only negative complete-skin penetration is corrected. Source constraints are sampled at 120 Hz and export/import at 240 Hz, with per-asset key reduction, animation compression and mesh compression disabled.

Actual four-paw support reads all eight influences, including the longer four-joint hind chains. It releases genuine swing/airborne paws and measures stance against the surface below each paw. Final poses are captured at `SkeletonModifier3D.modification_processed`, before Godot restores the animation pose. Original segment lengths are checked against the corresponding source pose; support does not stretch the limbs.

## Appearance, selection and corpse

The shader binds the artist's real normal map and both original alpha/albedo maps. Matte fur, dark eyes and authored partial-dye feature protection replace neither the original pixels nor UVs. Both full and partial native hues visibly change the rendered model. This is an authored dye interpretation, not recovery of an original UO partial-hue mask or simulated hair.

Measured small-body bounds drive the mobile selection box; camera height is 0.4 m. Nameplate height includes the actual ear tips and back during a horizontal bound, rather than tracking only the lower head. The final measured clearance stays above 69 mm on the focused finite planes.

The cadaver uses native graphic `0x2006`, amount/body `205`, victim facing and raw hue. Both body and fur are frozen from the actual final Death pose, with no remaining skeleton. The artist's extra UV channels exposed a general freezer defect: float custom-channel arrays were passed back using default byte formats, producing empty surfaces. `CorpseModels` now carries the source custom-channel format bits and rejects a failed surface creation. Synthetic source-free tests preserve float RGBA, float RG and byte RGBA payloads exactly. The implementation follows the [Mesh custom-channel formats](https://docs.godotengine.org/en/stable/classes/class_mesh.html) and [ArrayMesh surface flags](https://docs.godotengine.org/en/stable/classes/class_arraymesh.html).

The focused corpse gate checks real surfaces and occupied rendered pixels, as well as final shape dimensions. Metadata alone cannot satisfy it. Future accepted bodies continue to receive a static-corpse entry automatically.

## Verified evidence and practical limits

| Check | Result |
| --- | --- |
| Complete source/refined skins | 1,905 checks / 726 samples, zero failures |
| Retained joint poses | Maximum relative-position difference 0.000000222 m; minimum quaternion dot 0.99999988 |
| Genuine airborne source cases | 23 explicitly preserved cases |
| Actual installed public avatar | 3,287 checks / 162 raised/lowered flat/sloped poses, zero failures |
| Paw support | 264 lifted / 348 planted cases; maximum planted gap about 2.04 mm |
| Original alpha | 174 measured visible gap pixels in the focused probe |
| Real native constructors | 218 checks on two clients; Rabbit and JackRabbit each exercised by both owners, zero failures |
| Clean public distribution | 228 checks / 99 complete skins, zero failures; no private art, donor, game inputs or server |
| Source-free custom corpse formats | 12 checks, zero failures |

Public presentation and native tests are repeated after moving the route from local candidates to the actual public package. `prepare-rabbit.py --verify-public` rejects stale model/import/runtime/index evidence and altered extracted maps. Final focused logs are under `work/creatures/rabbit/`, including `motion.log`, `presentation-public.log`, `native-public.log`, `distribution.log` and `corpse-attributes.log`. Earlier failed import, retiming, label and empty-surface probes are superseded by these reports. Shared-regression and root-verification results are recorded in the current PROGRESS checkpoint.

The native tests prove real world entry, constructor identity, Move, raw hues, action/hurt/death packets and corpse replication/facing. AI is frozen for controlled sampling. Autonomous AI, taming, arbitrary terrain/obstacles, complete original choreography and final visual polish remain separate. Selection uses a conservative measured box; fur remains the original cards/textures. Exact original UO partial masks are not claimed.

## Reproduction and continuation

Run `python -B scripts/prepare-rabbit.py --verify-only` after obtaining the pinned source (omit `--verify-only` to download a missing input). Run the trusted Blender with `--background --factory-startup --disable-autoexec --python-exit-code 1 --python scripts/blender-prepare-rabbit.py`. Import, run `ConfigureRabbitImports.gd`, reimport, run `RabbitMotionTests.gd`, then `prepare-rabbit.py --candidate` and `RabbitPresentationTests.gd`.

Only passing exact-input evidence allows `--stage`. Run the disposable native family test for `rabbits`; only proof of both constructors on both owners allows `--install`. Repeat `RabbitPresentationTests.gd -- --public`, the native family test and `test-rabbit-distribution.py`, then `prepare-rabbit.py --verify-public`, the shared creature/corpse checks and root `scripts/verify.ps1` before publication.

Continue the configured occurrence queue with SeaHorse, Wisp, AirElemental and the remaining families. SeaHorse is a native mount with body 144/item `0x3EB3`; its model-table row exists, but the named mesh was not found in this archive. Wisp also has a table row without its named mesh here. Preserve native rules while investigating retained/free alternatives; do not activate a guessed model-table assignment or stop for routine visual approval.
