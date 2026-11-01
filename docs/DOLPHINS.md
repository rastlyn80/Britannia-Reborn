# Independent dolphin replacement

Native body 151 (`Dolphin`) uses an independently licensed bottlenose study mesh and maps, with an authored nine-bone rig, skin weights and 14 animation clips. It follows the configured Trammel occurrence queue after sea serpents. The original Third Dawn 51-vertex source trial was prepared and inspected first; its angular silhouette remains saved locally for comparison and is not accepted. No original UO mesh, texture, rig or animation is included in this public replacement.

## Source, licence and exported bundle

- Author: Innerscene Corp. [Original model page](https://www.innerscene.com/tools/library/3d-parts/common-bottlenose-dolphin-a7f74d0e), [library terms](https://www.innerscene.com/tools/library/terms), [CC0-1.0 dedication](https://creativecommons.org/publicdomain/zero/1.0/).
- Exact download URL and pins: `scripts/dolphin-inputs.json`. The original 3,475,348-byte GLB has SHA-256 `3028e97a3b576c78891083c7963b6f4a039f31cee3e710c26c2e40f7ed6bb263`.
- Static inspection verifies glTF 2.0, six meshes, embedded PBR maps and no rig or source animations. The source GLB itself carries its author's CC0 statement.
- The source has 57,656 triangles. Conservative body reduction retains 20,216 triangles across all six surfaces. Original embedded base-colour and normal maps, dark eyes, nose and mouth surfaces remain. The model is approximately 3.04 m long, 0.97 m wide and 0.83 m high; it is an authored generalized study, not a scan or anatomical reference standard.
- `scripts/blender-prepare-dolphin.py` creates the independent rig and motions without loading source scripts. At most three normalized weights per vertex blend longitudinal body/tail stations and the flippers. The exported rig faces the project's +Z heading. Swimming uses vertical cetacean fluke strokes. Root trajectories remain inside the visual rig; server coordinates are authoritative.
- Public files are under `Viewer/Art/Creatures/Dolphin/`, with an exact source/recipe/map/export provenance record and `NOTICE.txt`. Five extracted PNG companions are byte-identical to their embedded GLB members, not repaintings. The source mesh/maps retain CC0; project conversion, rig, motions and shaders use GPL-3.0-or-later. Godot import sidecars are retained; caches and the downloaded original stay ignored.

The 14 authored clips are Idle, Walk, Run, Attack, Attack2, Attack3, Hit, Death, Death2, Fidget, Fidget2, Jump, Roll and Cast. This is an export inventory, not 14 recovered original action groups or a claim that native dolphins normally cast spells. Both deaths roll the body belly-up, on opposite sides. Native sea routes use the applicable categories; unused extra clips remain available for explicit future work.

## Native actions and presentation

Pinned ModernUO `Projects/UOContent/Mobiles/Animals/Misc/Dolphin.cs` sets body `0x97`, `CanSwim=true` and `CantWalk=true`. Its `Jump()` randomly emits classic group 3 with 16 frames or group 4 with 20 frames. The replacement explicitly maps those to Jump and Roll, keeps both alive, and retains group 7 for the native weapon hit reaction. The guarded disposable fixture calls the actual `Dolphin.Jump()` method until both choices have been observed; it does not merely send invented animation packets. This proves the method's two paths, not a timed observation of autonomous random AI breaches.

The marine PBR surface keeps the licensed source colour/normal maps and roughness factors. Wet roughness/specular response is explicit. Raw native hue bits use the shared palette; dark eyes, nose and mouth retain their own materials. Native palette colours still come from the separately configured local hue table; that game-derived table is not bundled. Partial tint uses an authored neutral-colour test on the licensed body; the original UO partial-hue mask was not recovered. This approximation is recorded in the manifest.

The actual avatar uses `native_waterline`: source Y=0 stays at native water Z, with no seabed/deck floor lift or stance-foot IK. Matching corpse graphic **0x2006 / amount 151** freezes all six surfaces at final Death, removes the skeleton and appears automatically in the graphic-ID catalogue. Generic frozen-corpse minimum-height settling still differs from a physically submerged floating death; precise vertical handoff, shoreline clearance and water effects remain gaps.

## Verified evidence

All focused checks pass:

- **1,038 motion checks / 126 complete six-surface skin samples**: finite deformation, all 14 clips, +Z heading, closed trajectories, vertical fluke strokes and measured metre-high breaches.
- **90 actual Forward+ material checks**: licensed colour/normal maps, full/partial raw dyes, protected dark eyes, measured wet response and normal-map pixel response.
- **56 actual avatar/aquatic Forward+ checks**: real marine material, measurable wet pixels, Jump/Roll/Hit categories through the presenter, no invented feet, eight finite collider/gait cases, unchanged native anchor and static cadaver.
- **159 final actual disposable-server/two-client checks** using the installed public route: native Dolphin constructor on both characters, genuine wet destinations after native Move, raw hues, actual weapon hurt, both native Jump variants, explicit categories, death/facing and corpse replication. The initial private-stage run passed 162; the difference is the random number of attempts required to see both breach variants.
- **16 isolated public-distribution checks**, including a real avatar, rig, six surfaces, shader, swimming, native categories, finite deck/seabed support cases and static corpse, in a source-only disposable project with no `local-art`, original source imports, game inputs or server.

Logs: `work/creatures/dolphin-free/motion.log`, `materials-connected.log`, `avatar-aquatic.log`, `distribution-final.log`, and `work/creatures/dolphin-native-final.log`. Reports/captures: ignored `outputs/creatures/dolphin-trial/` and `outputs/creatures/dolphins/live.json`. These are bounded category/presentation/native integration tests, not complete original choreography, behaviour/taming/reward certification, arbitrary-shoreline clearance or final art approval.

## Reproduction

From the repository root, with trusted Blender/Godot and the pinned server available:

```powershell
python -B scripts/prepare-dolphin.py
./.tools/blender/blender-5.2.1-windows-x64/blender.exe --background --factory-startup --disable-autoexec --python-exit-code 1 --python scripts/blender-prepare-dolphin.py
./.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path Viewer --editor --import
./.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path Viewer --script res://Presentation/DolphinMotionTests.gd
python -B scripts/prepare-dolphin.py --verify-only --candidate
./.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path Viewer --script res://Presentation/DolphinMaterialTests.gd
./.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path Viewer --script res://Presentation/AquaticPresentationTests.gd -- --family=dolphins --candidate=res://local-art/dolphin/candidate.json
python -B scripts/prepare-dolphin.py --verify-only --stage
./scripts/test-horses.ps1 -Live -SkipContact -CreatureFamily dolphins *> work/creatures/dolphin-native-final.log
python -B scripts/prepare-dolphin.py --verify-only --install
python -B scripts/test-dolphin-distribution.py
```

Stage and install reject stale source/recipe/asset/import/runtime receipts. Install also requires actual native constructor/water/breach evidence for both characters and a clean native log newer than the presentation receipt. The native fixture runs only in the isolated loopback 2594 environment; production and existing saves remain untouched. A fresh repository download uses the public bundle directly and needs neither the original study GLB nor UO/Third Dawn art for this dolphin. Root verification includes the public motion test and isolated distribution test.

Final shared regression retains 103 local source forms / 38 groups, with 71,060 pose checks / 21,441 skin samples and 1,435 GPU checks / 618 views. The independently licensed dolphin is counted separately, alongside public bird and water elemental. All 167 available corpse variants pass 1,559 rendered checks. Fresh full `scripts/verify.ps1` exits 0 with no script errors, 71 server-extension / 84 client developer-edit checks and a clean final world startup; existing malformed-Unicode and teardown RID-leak diagnostics remain. The final expanded 16-check distribution test also passes separately. Current bird and water GPU controls retain 117 / 12 support cases and 547 checks. Logs: `work/creatures/dolphin-shared-regression.log`, `dolphin-full-verify.log`, `dolphin-bird-control.log` and `dolphin-water-control.log`.

The bounded catalogue reaches 135/279 tested bodies (48.4%), 130 generic routes and 2,266/3,068 connected generic protocol slots (73.9%, including reuse). These are coverage figures, not final-art or complete-original-animation percentages. Continue occurrence-first with the existing Ettin/hind action reviews and missing ordinary rat, cat and eagle; the all-creature objective remains active.
