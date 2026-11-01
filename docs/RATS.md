# Ordinary rat body 238

The ordinary Rat uses an independent CC0 model by **br-n518**, rather than a miniature of the scarred Third Dawn giant rat. The source table has no body 238 entry; its giant-rat body 215 remains a separate actor. A rendered scaled-donor trial looked visibly monstrous, and inspection of the original giant-rat atlas found entirely opaque alpha, so its white markings were not a missing cutout problem. That trial remains unaccepted and local.

## Source and conversion

- Author/source: [br-n518, Rat](https://opengameart.org/content/rat-0), published 17 September 2018; [CC0-1.0](https://creativecommons.org/publicdomain/zero/1.0/).
- Exact download: `https://opengameart.org/sites/default/files/rat_source.7z`, 1,167,383 bytes, SHA-256 `3c8ec130b6a3ec3c93e0290107bcebdd5b34e23fd9205fab373feffea27cc883`.
- `rat.blend`: 990,624 bytes, SHA-256 `fb6af70d6d9121e6f694c3e58fb8842b7bf3319e331d14332738af57af4046e0`.
- `rat.png`: 439,120 bytes, SHA-256 `b5ef72933348583c79f789dc3f3316163c600911fc38d5398aaa7d04bf4450bf`.

`scripts/rat-inputs.json` pins the inputs; `prepare-rat.py` verifies the archive and required members before use. Trusted Blender opens the source with automatic scripts disabled. `blender-prepare-rat.py` captures evaluated source IK/tracking poses before removing authoring constraints and baking portable bone curves. The 21-bone rig and original UV/skin assignments remain. The largest measured sampled bone-position reconstruction error is below 0.0002 mm. The optional original comparison retains 270 triangles; the installed rounded mesh has 4,816 triangles, smooth normals and a uniform 0.15 presentation scale, approximately 14 cm high at idle. No server coordinates or statistics change.

Five categories retain the licensed author's motion: Idle, Walk, Run, Attack and Death. Hit, Fidget, Eat, Attack2 and Alert are separately authored on that rig. These are not recovered Ultima Online choreography. The source gait cycles end at frame 15 and omit their duplicate frame 16; the refined version explicitly adds that closing interval (0.625 to 0.6667 seconds). The uncorrected comparison retains its measured gait discontinuity and sinking death pose. Refined support uses actual skinned minima, with source-rig death correction bounded at approximately 27 mm. A source-only export warning about the old mesh remains in the comparison log; the refined export and its actual skins pass validation.

The original atlas stays byte-identical. The matte fur shader adjusts its colour response, makes the red source eye dark, and offers full and fur-only partial dyes while preserving pink ears/nose/tail in partial mode. Fine relief is albedo-derived, not a sculpted normal bake or simulated fur. Four real two-joint source legs receive independently weighted sole support through `RatGroundSupport.gd`; there are no invented Third Dawn joint names. The measured interaction bounds, 0.15 m camera and animated skull label suit a small animal.

## Evidence and scope

- `RatMotionTests.gd`: **724 checks / zero failures**, 260 complete source/refined skin samples, normalized actual export weights, finite bones, distinct bites, feeding trajectory and closed refined gait endpoints; 12 actual Forward+ captures.
- `RatPresentationTests.gd`: **186 checks / zero failures** on both the private candidate and final public asset. It tests actual avatar/material response, raw full/partial hues, small selection/camera/label bounds, 18 finite raised/lowered flat/sloped terrain cases across Idle/Walk/Eat and two facings, every weighted paw, animal action routing and three static corpse hues. Idle soles are within **0.8 mm** and feeding soles within **0.4 mm**, with a 4 mm standing/feeding gate. The sampled walking swing paw reaches **12.1 mm** (18 mm gait gate).
- `ordinary_rats/live.json`: **110 actual isolated-server/two-client checks / zero failures**, repeated against the installed public asset. Both real native `Rat` constructor cases use body **238**, native `Mobile.Move` walk/run, native weapon hurt/actions/hues/death and replicated static **0x2006 / amount 238** corpses. Controlled fixture AI is frozen; this is not autonomous AI or taming certification. Production, real accounts and saves remain untouched.
- `test-rat-distribution.py`: **291 clean checks** in a new source-only Godot project, with no `local-art`, original source imports, game input or server. The actual public avatar, 130 complete skin samples, animal routes, four legs and static cadaver resolve.

Focused final logs are under ignored `work/creatures/rat-cc0/`: `prepare.log`, `motion-final.log`, `presentation-final.log`, `presentation-public-final.log`, `native-public-final.log` and `distribution.log`. Earlier failed probes remain separate. The first broad regression accidentally included unfinished trial folders; its verified owned process tree was stopped before acceptance. The corrected `accepted-regression.log` exits 0: all 38 accepted groups / 103 source forms have current receipts totalling 71,456 pose checks / 21,567 skin samples and 1,435 fresh standard GPU checks / 618 views, with focused gesture/terrain gates also passing. The complete 168-variant corpse catalogue passes 1,568 fresh rendered checks. `full-verify.log` exits 0 with no script errors, 71 server-extension / 84 client developer-edit checks and clean final world startup. Existing Unicode/teardown diagnostics and two nullable compiler warnings in unchanged PreviewTools tests remain. The root run includes the 291-check public rat distribution test. The stricter final standing/feeding paw assertion was then checked by the focused public GPU run; runtime and asset bytes did not change.

The public bundle is `Viewer/Art/Creatures/Rat/`: GLB, its unchanged embedded PNG companion, import sidecars, exact provenance and NOTICE. It contains no original UO mesh, rig, map or motion. GPL-3.0-or-later project conversion/actions/shaders retain the underlying CC0 notice. The original rat blend, source comparison and captures stay ignored. The corpse registry automatically includes accepted native body 238 without inventing another static graphic ID.

## Reproduction and remaining work

```powershell
python -B scripts/prepare-rat.py --verify-only
./.tools/blender/blender-5.2.1-windows-x64/blender.exe --background --factory-startup --disable-autoexec --python-exit-code 1 --python scripts/blender-prepare-rat.py
# Import Viewer, then run RatMotionTests.gd in Godot Forward+.
python -B scripts/prepare-rat.py --verify-only --candidate
# Run RatPresentationTests.gd against the candidate.
python -B scripts/prepare-rat.py --verify-only --stage
./scripts/test-horses.ps1 -Live -SkipContact -CreatureFamily ordinary_rats
python -B scripts/prepare-rat.py --verify-only --install
# Import Viewer; run RatPresentationTests.gd -- --public and repeat native tests.
python -B scripts/test-rat-distribution.py
./scripts/verify.ps1
```

Bounded body evidence becomes **136/279 (48.7%)**, with 103 local source forms plus four independently licensed public forms. Generic protocol connectivity becomes **2,294/3,091 (74.2%, including reuse)**, leaving 797 slots; adding a body adds its tracked denominator too. The rat has no native spellcasting behaviour, so an irrelevant missing Cast slot is not filled with invented motion merely to improve that percentage. Positive named body/constructor pairs reach 117; their complete denominator is unknown.

The original donor remains simple: ears, paws, tail and fur volumes can improve further. No final-art or full original mode/subaction fidelity is claimed. Arbitrary obstacles, gait transitions and large crowds need broader testing. Continue Cat body 201, then Eagle body 5 and the configured occurrence queue, while retaining all outstanding creature families, identities and animation gaps.
