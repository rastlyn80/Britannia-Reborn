# Original Acid and Poison Elementals

Native AcidElemental 158 and PoisonElemental 162 retain their original later Third Dawn/Age of Shadows meshes, separate 128-square atlases, 34-joint rigs and table scale 1.3. Poison's original model-table animation link selects Acid 158. Exact normalized geometry, UV, weights and rig contracts are checked before sharing those motions. Source meshes have 183 points / 362 triangles; private refined forms have 5,792 triangles. Original bind normalization and bounded refinement are explicit conversion steps, not exact original-client skinning reconstruction.

## Motion and material

Twelve table-declared source motions are imported: Idle, Walk, Run, Attack, Attack2, Attack3, Hit, Death, Death2, Fidget, Cast2 and Stomp. Pillage explicitly reuses Stomp; LieDown is the existing static-rest compatibility category. Some original source files contain identical motion bytes; twelve named imports do not imply twelve unique choreographies. Classic actions 12/14 and newer type 11 select Cast2. Newer types 2/5/14 select Hit/Fidget/Pillage.

The fluid renderer extends the accepted original Snow renderer without changing it. Its measured two-leg plane support, cached complete-skin bounds and temporary negative-only death-crossfade support are inherited. Run uses one constant whole-clip anchor and retains 214.206 mm of measured source vertical rise. Imported source joint centres and same-phase source segment lengths are preserved before terrain adaptation. Imports use 240 Hz, no key optimization/compression and uncompressed meshes. Physical no-slip, arbitrary terrain and all-phase transition correctness remain unproved.

The modern material retains each original RGB atlas, UVs and opacity. Both original atlases are wholly opaque. Authored procedural grain, relief, softened contrast, wet reflectance and faint emission add surface detail; there is no generated high-resolution bitmap or recovered native normal/material map. Acid is wetter than Poison. Full hue flags are retained; partial hues use an authored UV region, not recovered original mask semantics.

The gel shader uses an explicit per-material clock, never global shader time. Finished deaths stop the clock; static corpses keep a fixed surface. Actual rendered drift checks cover all six corpse-colour cases. Hues rebuild materials without replacing the rig.

## Exact source and publication boundary

The preservation input is [uoaos.zip](https://zuluarchive.com/static/files/uoaos.zip), listed by the [Zulu archive](https://zuluarchive.com/pages/files.html). It is a third-party preserved source; neither official authenticity nor redistribution permission is claimed. No downloaded game executable was run. `scripts/source-fluid-elemental-inputs.json` pins seventeen extracted members and these cabinets:

| Cabinet | Bytes | SHA-256 |
|---|---:|---|
| `client7.cab` | 20,805 | `8180b7c2b7cb4ca6e868a3ff460e25c0e6aa710367b8d5487d2d455bfef29859` |
| `client11.cab` | 35,160,963 | `307a6b91c4d5459080d1fe8a74ae4fe0b91dea8a21a2866ca91e7dc7ba92f1a8` |
| `client10.cab` | 33,956,665 | `92e9b23c0c226a0d20af5402af7624b188d3bf6e1c4adb510c9d0575d2daa1d9` |

The bounded remote ZIP/CAB evidence does not provide a whole-ZIP hash or publisher signature. Original files, derived meshes/textures, source tables, screenshots and private reports remain excluded from Git. Published project source provides conversion, presentation and validation code plus source/hash provenance. This milestone does not make these game-derived assets distributable in a clean client download.

## Verified evidence

Private reports are under `outputs/creatures/fluid_elementals/`; logs, failed attempts and continuity records are under `work/creatures/elemental-variants/acid-poison/`.

- Source actions: 118,500 checks / 3,108 complete skins / 1,036 paired phases, including 24 timing/restart cases. Relative source joint error is zero; maximum grounded error is 1.459 mm. Constant anchors retain source Run rise.
- Actual Forward+: 17,560 checks / 1,512 finite-plane poses across fourteen source/reused/rest categories, with 96 airborne Run cases. Maximum planted gap is 1.856 mm, lift error 0.999 mm and whole-skin minimum -1.757 mm. Actual original atlas detail, gel relief/flow, raw full/partial hues, render-stage bounds/picking/nameplates and static corpse colours pass.
- Six actual movement/action transitions per body: 2,594 checks / 432 mixed skins on flat/sloped finite planes, including Run-to-Cast2 and Run-to-Death. Signed minimum is -4.219 mm; 120 positive-rise cases remain. Actual modified skins/picking and native coordinates are checked.
- General source validation: 2,031 checks / 630 skins. Standard GPU validation: 25 checks / twelve views. Thirty-two fresh original/refined/modern comparison frames are retained privately.
- Real native constructor/action/movement/death: 390 two-client checks across both native classes on both disposable owners. Full/partial hues, native Move, classic/new Cast2 and static corpse routing pass. NPC Move is fixture-controlled, not autonomous AI or player movement evidence.
- Native spell/poison: 136 checks across four owner/body cases. Real `LightningSpell.Cast`, its cast timer, actual `Target.Invoke` and native damage reduce target health by 25/29/24/30 points. No skill, mana or cast deadline is forced. Native lethal poison application and the actual immunity API confirm Poison immunity and Acid's absence of that immunity. Hit-poison probabilities remain native 0.75 / 0.6; random melee proc frequency is not certified.
- Existing Snow native control: 198 two-client checks pass with the expanded Cast2 test driver. The production renderer and server gameplay code are unchanged.

Two initial spell runs ended when no targeting cursor remained. Diagnostics establish that a native cast can return to no spell before the fixture observes a cursor; the cause is not diagnosed or fixed. The final run retains two interrupted attempts for one Poison case, followed by a successful third real cast. The harness permits at most eight fresh native-constructor attempts, records interruptions and requires actual positive spell damage. Failed logs remain private.

Pinned native `Spell.Cast` starts hand movement only for human bodies or player-controlled monster bodies, not these NPC monsters. Therefore actual spell damage does **not** certify an automatic NPC Cast2 animation packet. Explicit real classic/new cast packets and their render routing are separately verified by the ordinary native test. Automatic NPC spell presentation remains a documented gap; no manual packet is passed off as native autonomous casting.

AI is disabled in controlled tests, and fixture commands choose the spell and target. Autonomous combat/spell selection, loot, melee proc probability, persistence, full original choreography/particles and final art remain open. The native fixture is explicitly enabled only in the guarded disposable world on loopback 2594 with test accounts. Production 2593, accounts/saves, original installations, concurrent terrain/building work and the converter/IR/Godot foundation are preserved.

All fifty accepted local groups / 121 forms pass exact current gates: 86,645 general checks / 26,250 skins and 1,654 standard GPU checks / 726 views. Unchanged evidence is reused only after exact input verification. All 197 corpse variants pass 1,854 fresh rendered checks. Full `scripts/verify.ps1` exits 0, including 71 server-extension / 84 developer-edit tests and clean final world startup; existing Unicode/teardown diagnostics remain.

Bounded native body coverage is 164/279 (58.8%); 162 named body/constructor pairs have no complete class denominator. There are 121 local plus twelve independent public forms: 133 generic records / 159 routes and 2,860/3,801 connected protocol slots (75.2%, including reuse), with 941 missing. Original metadata inference is 802/3,003; 626 routed-body category misses and 1,575 entries without a generic model remain separate from specialized human/mount presenters. These are integration metrics, not final art/gameplay/choreography completion.

## Reproduction

Keep the exact private cabinets at `work/third-dawn/late-source-research/uoaos-cabinets/`. Source extraction/preparation never activates routes; current source/action/GPU/transition evidence is required before local acceptance.

```powershell
python -B scripts/prepare-source-fluid-elementals.py --check-inputs --extract --prepare
$godot = (Get-ChildItem .tools/godot/*console.exe | Select-Object -First 1).FullName
$env:APPDATA = Join-Path $PWD '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
& $godot --headless --path Viewer --editor --import
python -B scripts/configure-creature-imports.py fluid_elementals
& $godot --headless --path Viewer --editor --import
./scripts/test-creatures.ps1 -Families fluid_elementals -Capture -Live
python -B scripts/check-source-fluid-elementals.py --native
python -B scripts/build-creature-catalogue.py
python -B scripts/build-creature-actions.py
./scripts/verify.ps1
```

`--refresh-support` verifies original/pipeline/helper pins before refreshing owned preparation/renderer hashes; all dependent evidence must be rerun afterwards. The regular creature batch requires both bodies' focused action, rendered presentation and mixed-transition checks. Strict acceptance rechecks exact source, helper, recipe, assets, import settings and runtime hashes. The live driver creates a fresh disposable runtime, refuses an occupied port and never attaches to or stops an unknown server.
