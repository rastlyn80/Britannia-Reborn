# Original BullFrog and GiantToad

BullFrog (body 81) and GiantToad (80) now retain their distinct later Third Dawn meshes, original UVs, 27-joint bind rigs and table scales of 0.8 and 1.3. Each original has 125 source points and 246 triangles; each private refined version has 3,936 triangles. Both use the seven original GiantToad motions through the table's explicit 81-to-80 animation link. This is a source port with measured integration evidence, rather than a claim of complete original-client simulation or final artwork.

## Exact sources and preparation

Preservation listing: <https://zuluarchive.com/pages/files.html>. Container: <https://zuluarchive.com/static/files/uoaos.zip>. This third-party historical copy does not establish official authenticity or permission to redistribute game artwork. Bounded ZIP member downloads were checked for size/CRC, followed by cabinet and extracted-member hashes. No full-container hash or downloaded-executable execution is claimed. Trusted installed 7-Zip performs static extraction under ignored `work/third-dawn/late-source-research/`.

[The input manifest](../scripts/source-frog-inputs.json) pins four cabinets and eleven original members: the table, two body meshes, their shared map and seven motions. The new animal cabinet is `uoaos/UOTD/models/animals/client8.cab`, 5,793,154 bytes, SHA-256 `155fe820d8c0e2a08650f81ec037829bed49aeca74efd2a07479a907287a1afc`. BullFrog mesh SHA-256 is `da8bfb565c026ad3eefac3cc0ef89bd52e9c0d6a2ca93aa7c7da3210a7d3823c`; GiantToad is `390a6dafc269862188b25f94a7543448352dd2e860e7987b3a6220dbe6ca22cc`. The shared TGA is `frogs_frog_giant_v01.tga`, SHA-256 `4936da6fb258e8f56f6e39a55457ef4fb36ba8be406bf1099b0a16619743d0d6`.

UVs, topology and weights match between the two original bodies, but some points/normals and six forelimb bind records differ. Each original mesh/bind rig is retained. The previous authored half-scale BullFrog substitute is superseded. A private input adapter resolves the original table's cross-folder Animals/Monsters animation link while recording actual archive member paths; it does not invent duplicate archive members or assert exact bind equality.

The private natural atlas was made with built-in image generation from the original map. Its exact saved prompt, provenance and SHA-256 are pinned by the manifest; generated landmarks are not certified as exact UV reconstructions. The original 64-square graded alpha remains bound independently of the new RGB, using an authored 0.12 cutout threshold. A shader adds moist skin and albedo-gradient relief, not a recovered normal map. The two terminal tongue-chain weights supply an authored vertex scalar for a pink, slightly wetter tongue, without guessing an atlas rectangle or tinting the whole body. Full/partial native hues retain their raw flags; partial-region selection is authored.

Preparation requires the exact private inputs and saved atlas. Original and generated game-derived pixels, palettes, captures and evidence stay outside Git.

```powershell
$env:APPDATA = Join-Path (Get-Location) '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
$godot = (Get-ChildItem '.tools/godot/*console.exe' | Select-Object -First 1).FullName
python -B scripts/prepare-source-frogs.py --check-inputs
# Optional static extraction from the pinned cabinets:
python -B scripts/prepare-source-frogs.py --extract
python -B scripts/prepare-source-frogs.py --prepare
& $godot --headless --path Viewer --editor --import
python -B scripts/configure-creature-imports.py frogs
& $godot --headless --path Viewer --editor --import
& $godot --headless --path Viewer --script res://Presentation/BakeSourceFrogGround.gd
python -B scripts/prepare-source-frogs.py --finalize-ground
scripts/test-creatures.ps1 -Families @('frogs') -Capture
scripts/test-horses.ps1 -Live -SkipContact -CreatureFamily frogs
scripts/build-corpse-catalogue.ps1 -Render
python -B scripts/build-creature-catalogue.py
python -B scripts/build-creature-actions.py
scripts/verify.ps1
```

## Motion, support and native identity

Original motions are Idle, Walk, Run, Attack, Hit, Death and Fidget. Attack2 explicitly reuses Attack; Death2 reuses Death; Eat reuses the original tongue-snapping Fidget. Alert is an authored bounded head-up scan from the original idle pose. The terminal rest category retains the source collapse. These assignments do not claim newly recovered source clips. Unsupported casting/ranged/flight categories remain recorded gaps.

The original tongue extends in both Attack and Fidget; dynamic weighted bounds include it. Native feeding already sends animal group 3 for BullFrog and monster group 17 for GiantToad. Their Eat/Fidget routes therefore preserve the original tongue motion without changing server gameplay. Controlled action tests do not certify autonomous feeding or taming.

Per-frame floor normalization suppressed the original hops. Walk and Run now use constant whole-clip anchors, preserving all original local joint channels and their rise/fall. The sampled modern Run underside ranges from about 5 mm to 0.741 m for BullFrog, and 8 mm to 1.183 m for GiantToad. These are sampled pose clearances, not calibrated travel speeds or claims of exact original-client root simulation. Four measured sole chains preserve source foot lift while adapting to actual finite terrain planes; source entity coordinates remain authoritative.

Two sparse Hit poses initially floated by 8.82 mm. A denser 960 Hz scan found 14.124 mm residual error and showed that one constant offset still left an 8.160 mm worst residual. Instead, preparation saves small residual corrections measured from the imported Hit skin. Runtime samples that scalar curve only for Hit and adds it after the mixer writes its fresh source-space translation. Neither hopping clip is sampled or flattened. Independent off-grid Hit holdouts retain the original 8 mm acceptance tolerance, with measured worst error 4.096 mm. Death blends also retain temporary negative-only support; existing source joint channels and positive rises are preserved.

## Evidence and remaining work

- Source actions: 19,718 checks, 2,664 complete skins, 888 same-phase comparisons and 7,014 additional off-grid Hit poses; zero failures. All relative source joint centres remain unchanged. The sparse grounded-category maximum is 3.113 mm; dense Hit holdouts reach 4.096 mm. Animal/monster native group timing and repeated actions are tested at three preceding gait rates. Both static cadavers retain their final skin and materials.
- Actual Forward+ avatars: 18,220 checks over 1,296 finite-plane poses; zero failures. All four feet preserve source swing and stance, including 96 fully airborne Run cases. Maximum planted gap is 1.975 mm and retained lift error 0.961 mm. Actual picking/nameplates, original alpha, detailed RGB, relief, tongue material and six corpse colour cases are included. All six constructor-allowed BullFrog hues (`0x5AC`, `0x5A3`, `0x59A`, `0x591`, `0x588`, `0x57F`) are visibly rendered, alongside full/partial control colours.
- Actual mixed poses: 1,513 checks and 252 complete skins per body, zero failures, across seven gait/action transitions on flat and 0.08-radian sloped finite ground. Native attack, hit, feeding and death packet paths are included. Worst signed skin gaps are −1.772 mm and −1.951 mm; positive rises and actual picker containment remain intact.
- Real native BullFrog and GiantToad on both disposable owners: 210 checks, zero failures, covering constructor/body/hue identity, movement, classic/new action decoding, death and native corpse identity/facing/static skin. AI is frozen for controlled sampling; autonomous combat, taming and feeding are not certified.
- General poses: 1,635 checks and 504 complete skins. Standard GPU: 27 checks and twelve views. All 191 corpse variants pass 1,800 fresh rendered checks. All 47 accepted local groups pass current exact gates (80,964 general checks/24,486 skins and 1,575 standard GPU checks/690 views). Full scripts/verify.ps1 exits 0, including 71 server-extension/84 developer-edit tests and clean world startup. Existing Unicode/teardown diagnostics and two unchanged nullable warnings remain. Receipts are recorded in `work/creatures/frogs/`.

The live harness uses an unoccupied disposable loopback port 2594 and fresh accounts/runtime. Production 2593, existing accounts/saves, remembered login, original installations and concurrent terrain/building/UI work remain separate. No ModernUO core/gameplay change was made.

Physical stance-speed/no-slip calibration, final mesh/head/material polish, exact generated landmark registration, complete original choreography/particles, arbitrary terrain and autonomous gameplay remain open. Integration coverage includes labelled motion reuse and is not a final-fidelity percentage. Continue occurrence-first through PlagueSpawn, PlagueBeast and the remaining catalogue, including actual owned-spawn lifecycle rather than treating frozen/null-owner samples as that proof.
