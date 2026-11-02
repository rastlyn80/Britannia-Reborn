# Original Slime and PlagueBeast

The local conversion retains the later Third Dawn/Age of Shadows designs for native Slime 51 and PlagueBeast 775. PlagueSpawn uses its seven actual native constructor forms, including the existing specialized male and female humans. Original game artwork, generated derivatives, comparison images and test receipts remain private. Project source contains conversion/rendering logic and source hashes, not redistributable copies of these models.

## Inputs and conversion

The preservation source is [uoaos.zip](https://zuluarchive.com/static/files/uoaos.zip), listed by the [Zulu archive](https://zuluarchive.com/pages/files.html). These are third-party preserved inputs, not an authenticated current official download or a redistribution licence. Only bounded ZIP members were recovered; no downloaded executable was run. The exact cabinet/member sizes and SHA-256 values are in `scripts/source-amorphous-inputs.json`.

| Original model | Native body | Original geometry | Source skeleton | Original motions |
|---|---:|---:|---:|---|
| `plague_beast` | 775 | 799 points / 1,555 triangles | 56 joints | Idle, Walk, Run, Attack, Attack2, Attack3, Hit, Death, Fidget |
| `slimes_slime` | 51 | 46 triangles | 29 joints | Idle, Walk, Run, Attack, Hit, Death, Fidget |

Both retain their own UVs, source opacity and model-table scale 1.3. The importer normalizes exporter bind matrices into a rigid rig; preserved source joint motion does not claim exact original affine scale/shear skinning. Missing Slime Attack2/3 reuse Attack. Death2 reuses Death; Eat/Pillage reuse Fidget. These are declared substitutions, not recovered choreography. Unsupported casting, ranged and flying motions remain gaps.

PlagueBeast has 6,220 refined triangles and a private generated RGBA detail layer composited over original RGB. Original alpha remains separate, avoiding both invented opaque edges and dark padding from transparent generated pixels. Slime uses original RGB/alpha with an authored moist-gel surface and restrained procedural grain. Neither material is a recovered native shader. PlagueBeast's exact fine eye/mouth texture registration and final art quality still need review.

Walk and Run use constant whole-clip floor anchors. Positive source bounce survives; per-frame floor flattening would destroy it. The nonstandard rigs use plane-only support rather than inferred ordinary foot IK. Other grounded clips retain sampled floor correction. Temporary negative-only complete-skin support prevents a death crossfade from sinking through the ground.

## Slime subdivision correction

Ordinary rest-pose smoothing plus interpolated skin weights caused substantial deformation: an initial mixed-gait check rose approximately 205 mm above the original surface. Matching joint centres alone did not detect this defect. The failed evidence remains private rather than being relabelled as a pass.

`SourcePoseSubdivision.gd` instead subdivides the actual posed source triangles. Each new point keeps its barycentric source contributions; conditional inverse-bind translations preserve each original bone's weighted contribution. Eight weight slots retain up to seven contributing source influences without truncation. The resulting Slime has 736 triangles and the original 29 bones, source scale and original animation channels. Newly inserted points have at most a 1.5 mm authored source-normal offset. This refines the surface without inventing different gait deformation.

An independent synthetic three-bone counterexample exposes 521 mm error in ordinary averaged skinning. The conditional-bind result differs by at most 20.9 micrometres, within the measured mesh weight-encoding bound. Actual Forward+ comparisons cover 49 original Slime poses with zero shaping offset, matching UVs/material/camera and 1,375 skin bindings. The production shaping/material/terrain paths have separate actual-avatar checks. These tests do not imply a universal eight-weight or arbitrary-topology solution.

## Evidence and limits

Current focused evidence is under `outputs/creatures/amorphous/`; reproduction logs and source/generated provenance are under `work/creatures/plague-spawn/`. Strict acceptance checks exact preparation, assets, import settings, original input pins and renderer/test hashes. Passing reports must not be reused after any of those inputs change.

- Source/action checks: 13,770 checks, 2,886 complete skins and 962 paired phases; zero relative source joint error. Maximum grounded floor error 2.116 mm. Both Walk/Run anchors remain constant.
- Actual Forward+ appearance: 10,007 checks over 1,404 finite-plane poses, source cutouts, relief, colours, actual picking/nameplates and ten corpse-colour cases. Maximum planted gap 2.250 mm. Slime includes all 24 native slime hues and all 15 PlagueSpawn hues.
- Seven actual rendered gait/action transitions per body: 3,530 checks / 504 mixed skins on flat/sloped finite ground. Signed minima are -0.024 mm PlagueBeast and -5.934 mm Slime; positive source rise is retained. Refined Slime's mixed-surface gap differs from the original by at most 1.754 mm.
- Synthetic subdivision: 917 checks / 61 poses; actual GPU subdivision: 98 checks / 49 paired poses. All pass.

General acceptance passes 1,759 checks. All 48 accepted local groups / 117 forms pass their current exact source/pose/GPU gates: 82,723 general checks and 1,602 standard GPU checks / 702 views, with unchanged evidence reused only after exact input verification. The global catalogue passes all 193 corpse variants / 1,818 fresh rendered checks. Five ordinary native classes on two disposable owners pass 576 real two-client checks. Owned PlagueSpawn passes 303 checks, all seven forms on both owners and eight native lifecycle cases; real expiry is observed at about 60.1 seconds. The final owned-presenter run uses Forward+ and is free of the dummy-renderer material diagnostics retained in the initial private log.

Full `scripts/verify.ps1` exits 0, including 71 server-extension tests, 84 developer-edit tests and clean final world startup. Existing Unicode and teardown diagnostics remain. Source publication is recorded separately in `PROGRESS.md`; prepared or privately tested models do not count by themselves. Bounded native coverage is 160/279 (57.3%), with 158 positive named body/constructor pairs and no complete class denominator. Generic action coverage is 2,776/3,691 connected slots (75.2%, including reuse); full choreography and final quality remain open.

The isolated lifecycle fixture samples real `PlagueBeast.OnGotMeleeAttack` callbacks until each of PlagueSpawn's seven random forms is observed. It never assigns their Body, Hue, Owner, stats or expiry deadline. Two real clients observe native body/colour and the actual presenter. Movement is frozen for controlled observation; minion AI timers remain enabled. Native `OnThink` must remove owned spawns after owner range, map change, deletion and the real one-minute expiry. Owner relocation is fixture setup, not evidence of player multiplayer movement. Ordinary constructor/action/movement/death tests cover Slime, CorrosiveSlime, Jwilson, PlagueBeast and PlagueBeastLord separately. Lord dissection, autonomous combat/feeding, acid effects, saves/reload, full choreography, arbitrary terrain, physical no-slip and final art remain open.

## Reproduction

Keep proprietary inputs and generated layers in the private paths named by the manifest; no production installation is modified.

```powershell
python -B scripts/prepare-source-amorphous.py --check-inputs --extract --prepare
./scripts/test-creatures.ps1 -Families amorphous -Capture -Live
python -B scripts/check-source-amorphous.py
python -B scripts/check-source-amorphous.py --native
python -B scripts/build-creature-catalogue.py
./scripts/verify.ps1
```

The live driver uses a newly isolated workspace runtime on loopback 2594 and disposable test accounts, guarded by explicit fixture settings. It refuses an occupied port and leaves production 2593, accounts and saves untouched. `--refresh-support` may refresh only owned renderer/recipe hashes after checking exact original input/pipeline pins; rerun all affected evidence afterwards. Every future accepted body must also pass the corpse catalogue and graphic-ID variant browser checks.
