# Original red and black Solen workers

Native RedSolenWorker 781 and BlackSolenWorker 805 use their original later Third Dawn/Age of Shadows models and UVs. Both retain 42 source joints, their original table scale of 1.3 and ten source motions. The black worker has its own source mesh and atlas and explicitly uses the red worker's table-declared animation link. Its native constructor hue remains `0x453` (1107).

The source meshes have 735 points and 1,322 triangles; the private refined forms have 5,288 triangles. Original bind-matrix normalization and bounded smoothing are explicit conversion steps, not a claim of exact original-client affine skinning. The imported original/refined/modern joint centres match at the same animation phase before terrain adaptation.

## Motions and six-leg support

The source motions are Idle, Walk, Run, Attack, Attack2, Attack3, Hit, Death, Fidget and Fidget2. The second fidget was present in the archive but absent from the earlier trial's label map. It is now imported independently and classic action 18 selects it. Death2 explicitly reuses Death; Eat and Pillage reuse Fidget. LieDown is the existing static-rest compatibility category. Missing ranged, casting and flight categories remain visible gaps, rather than invented choreography or unverified new-protocol mappings.

Walk and Run retain constant whole-clip model anchors and their source torso bob. A fixed anchor alone left the lowest distal leg surface as much as about 179 mm above the plane. `SourceSolenSupport.gd` adapts the six actual `legbone` chains, with two joints per leg. Historical `bip01` arms are not treated as feet. Relative swing height is measured from the six source distal surfaces; the lowest leg supplies the grounded reference. Low stance soles are placed on the actual contacted plane, while relative swing height and original segment lengths remain intact. This is authored terrain adaptation, not an original-client ground-placement reconstruction or physical no-slip certification.

An initial world-Y solve missed four sloped cases by up to 15.431 mm. The final solver rotates the two original leg joints against signed plane distance. It changes no bones outside the twelve leg joints. Actual render-stage measurements prove that the torso, arms, antennae and mandible joint positions retain their same-phase source poses, including mixed transitions. Whole-body and actual mobile-picking bounds update from the modified skin, and nameplates clear it.

An imported original Attack2 probe exposed two 12 mm floor errors between ordinary samples. Cached 960 Hz complete-skin residual corrections apply only to Attack2. Walk/Run channels are untouched. The independent off-grid holdout set samples different times and passes without relaxing the 8 mm floor tolerance. Death crossfades use temporary negative-only complete-skin support.

## Materials and exact sources

The preservation source is [uoaos.zip](https://zuluarchive.com/static/files/uoaos.zip), listed by the [Zulu archive](https://zuluarchive.com/pages/files.html). These are third-party preserved inputs; neither official authenticity nor redistribution permission is claimed. No downloaded executable was run. `scripts/source-solen-inputs.json` pins three cabinets and fifteen original members, including both meshes/maps, the model table and all ten worker motions. It also pins both private generated textures and their exact prompts.

| Cabinet | Bytes | SHA-256 |
|---|---:|---|
| `client7.cab` | 20,805 | `8180b7c2b7cb4ca6e868a3ff460e25c0e6aa710367b8d5487d2d455bfef29859` |
| `client11.cab` | 35,160,963 | `307a6b91c4d5459080d1fe8a74ae4fe0b91dea8a21a2866ca91e7dc7ba92f1a8` |
| `client10.cab` | 33,956,665 | `92e9b23c0c226a0d20af5402af7624b188d3bf6e1c4adb510c9d0575d2daa1d9` |

The built-in image-generation tool edited each original 256-square atlas separately, preserving its layout and eye landmarks while adding warm red/amber or charcoal chitin detail. Actual generated size is 1,254 square. Final saved images are `work/creatures/solen/red-worker-albedo-v1.png` and `black-worker-albedo-v1.png`. Their sibling `.prompt.txt` files hold the full final prompts; `.provenance.json` files record edit targets, hashes, sizes and generation mode. These are proprietary-source derivatives, not independently licensed artwork. Source alpha remains bound separately from generated RGB. Authored relief and chitin reflectance are shader effects, not recovered native normal/material maps. Fine UV registration and final art quality remain reviewable limitations.

Full and partial native hue flags survive without rebuilding the skeleton. Partial hues classify the original atlas, independently of generated detail. Both original atlases have nonopaque texels; actual bound cutouts are measured. The black worker's native hue has an additional actual-render check.

## Verified evidence

Reports are private under `outputs/creatures/solen_workers/`, with logs and publication receipts under `work/creatures/solen/`.

- Focused source/action: 20,028 checks, 3,108 complete skins, 1,036 paired phases and 54 action-timing/restart cases. Relative source joint error is zero. Maximum ordinary grounded error is 6.316 mm. Another 5,196 independent off-grid Attack2 skins remain within 3.214 mm.
- Actual Forward+: 29,867 checks over 1,512 finite-plane poses, covering all fourteen source/reused/rest categories, six actual legs, raw hues, cutouts, relief, whole-skin clearance, picking/nameplates and six corpse-colour cases. Maximum planted gap is 1.347 mm and swing-height error 1.055 mm. The whole-skin minimum is -1.120 mm. All 216 gait-plane cases stay grounded; protected source joint error is zero.
- Eight actual movement/action transitions per body: 4,034 checks / 576 mixed skins on flat and sloped finite planes. Minimum gap is -0.487 mm; all 216 gait-transition samples stay grounded. Actual modified protected joints retain the reference source pose, with current picking bounds.
- General source validation: 1,891 checks / 588 complete skins. Standard GPU validation: 27 checks / twelve views.
- Real native constructor/action/movement/death: 250 two-client checks, exercising both worker classes on both disposable owners, including separate classic Fidget2 packets. Native `Mobile.Move` is fixture-controlled movement, not player movement or autonomous AI evidence.
- Native friendship/damage: 68 checks, six friendship-state cases and eight damage cases. Real helpers and `IsEnemy` agree for players and actual controlled pets; native `Damage` dispatch revokes matching friendship and restores enmity for both direct and player-owned-pet attacks. Assigning friendship and pet control is fixture setup, not quest completion or taming gameplay.

The first isolated login attempt lost its relay connection before any creature code ran. The terminal failed run and server log are retained separately; a fresh isolated run passes without a client/core/gameplay change. This is not a diagnosed or fixed transport defect.

All 49 accepted local groups / 119 forms pass current exact gates: 84,614 general checks / 25,620 skins and 1,629 standard GPU checks / 714 views. Unchanged evidence is reused only after exact input verification. All 195 corpse variants pass 1,836 fresh rendered checks. Full `scripts/verify.ps1` exits 0, including 71 server-extension tests, 84 developer-edit tests and clean final world startup. Existing Unicode/teardown diagnostics remain. Thirty-two fresh original/refined/modern comparison frames are saved privately.

AI is disabled for controlled native tests. Autonomous combat, Solen quests, persistence, arbitrary terrain, complete original choreography/particles, physical gait calibration and final art remain open. Warriors, queens and matriarchs are separate unfinished variants; this worker milestone does not count them as complete. Production 2593, accounts/saves, original installations, concurrent terrain/building work and the converter/IR/Godot foundation remain untouched.

## Reproduction

Keep the exact private cabinets and generated textures at the manifest's paths. Regenerating a texture changes its identity and requires new pins and validation. Conversion and acceptance are separate operations.

```powershell
python -B scripts/prepare-source-solen.py --check-inputs --extract --prepare
$godot = (Get-ChildItem .tools/godot/*console.exe | Select-Object -First 1).FullName
$env:APPDATA = Join-Path $PWD '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
& $godot --headless --path Viewer --editor --import
python -B scripts/configure-creature-imports.py solen_workers
& $godot --headless --path Viewer --editor --import
& $godot --headless --path Viewer --script res://Presentation/BakeSourceSolenGround.gd
python -B scripts/prepare-source-solen.py --finalize-ground
./scripts/test-creatures.ps1 -Families solen_workers -Capture -Live
python -B scripts/check-source-solen.py --native
python -B scripts/build-creature-catalogue.py
python -B scripts/build-creature-actions.py
./scripts/verify.ps1
```

Import settings use 240 Hz, no animation key optimizer/compression and uncompressed mesh data. `--refresh-support` checks original input/pipeline pins before refreshing owned recipe/renderer hashes; all affected evidence must be rerun afterwards. The regular batch requires focused action, actual six-leg/whole-skin/material and transition proofs before acceptance. The live driver uses a newly isolated workspace runtime on loopback 2594 with disposable accounts and an explicitly guarded fixture module. It refuses an occupied port and never attaches to or stops an unknown server.
