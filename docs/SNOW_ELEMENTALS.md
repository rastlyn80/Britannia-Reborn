# Original SnowElemental

Native SnowElemental163 now uses the actual later Third Dawn source mesh, original34-joint hierarchy/UVs and twelve original table-declared Acid158 motions. The private refined mesh has5,792 triangles versus362 original triangles/183 source points. Source table scale1.3 is retained. An authored detailed snow atlas, diffuse frost/UV relief and partial body-colour region modernise its surface. Original/generated game artwork, inputs, palettes and captures remain excluded from Git. This is a source port with bounded integration evidence; full original-client simulation and final art are not claimed.

## Source and reproducibility

Preservation listing: <https://zuluarchive.com/pages/files.html>. Container: <https://zuluarchive.com/static/files/uoaos.zip>. This is a third-party historical copy, not an official current installer or authenticity/redistribution guarantee. Bounded HTTP ranges retrieved individual cabinet members with size/CRC checks; no full ZIP hash or downloaded executable execution is claimed. Trusted installed7-Zip statically extracts the cabinets under ignored `work/third-dawn/late-source-research/`.

[The input manifest](../scripts/source-elemental-inputs.json) pins3 cabinets and21 original files, including the model table, four original elemental meshes/maps and twelve Acid motions. Metadata client7.cab SHA-256 is `8180b7c2b7cb4ca6e868a3ff460e25c0e6aa710367b8d5487d2d455bfef29859`; monsters client11.cab is `307a6b91c4d5459080d1fe8a74ae4fe0b91dea8a21a2866ca91e7dc7ba92f1a8`; maps client10.cab is `92e9b23c0c226a0d20af5402af7624b188d3bf6e1c4adb510c9d0575d2daa1d9`. Actual Snow mesh SHA-256 is `44fa64eb759ff853d71f141bd49ed6f037dc35f3bba9ec121922b7c446645df2`.

The inspected Snow, Acid, Ice and Poison meshes have exactly equal source points, normals, topology, UVs, weights, ties and bone records after the declared normalization. Their atlas inputs remain distinct. Snow's model-table entry explicitly selects animation body158; this is a recovered source assignment, not a guessed donor. Its motions are Idle, Walk, Run, Attack, Attack2, Attack3, Hit, Death, Death2, Fidget, Cast2 and Stomp. Pillage explicitly reuses Stomp as a ground-slap category; no original pillaging clip or native scavenging ability is invented. Classic12/14 and modern11 select the recovered Cast2. Modern14 selects the labelled Pillage reuse. Unsupported ranged/flight categories remain recorded gaps.

The original128-square atlas is wholly opaque, confirmed from actual bound/decompressed texels. It is retained separately from the detailed private RGB. No cutout or exact partial-mask recovery is claimed. Shader relief comes from albedo gradients; it is not a measured/recovered normal map. Full/partial raw native hues use the original palette; partial dyes use an authored body region and retain pale head frost. Metadata pins the generated atlas and its saved prompt/provenance under `work/creatures/elemental-variants/textures/`.

```powershell
python -B scripts/prepare-source-elementals.py --check-inputs
# Optional static extraction from the exact pinned cabinets:
python -B scripts/prepare-source-elementals.py --extract
python -B scripts/prepare-source-elementals.py --prepare
scripts/test-creatures.ps1 -Families @('snow_elementals') -Capture
scripts/test-horses.ps1 -Live -SkipContact -CreatureFamily snow_elementals
scripts/build-corpse-catalogue.ps1 -Render
python -B scripts/build-creature-catalogue.py
python -B scripts/build-creature-actions.py
scripts/verify.ps1
```

The live harness refuses an occupied2594 port and uses new disposable accounts/runtime. Production2593, original installations, existing saves and remembered login remain separate. No ModernUO core/gameplay change was made. SnowElemental is still a native melee creature; a preserved casting category does not give it new server powers.

## Motion and presentation changes

The old30Hz import measured31.97mm floor error. Coupled120Hz/disabled optimizer-compression reduced this to8.96mm;240Hz reduces the sampled grounded error to1.459mm. Mesh compression and animation key reduction stay disabled so source joints and floor curves remain coupled. These are measured imported skins, not a claim of exact original-client scale/shear/particle reconstruction.

Per-frame grounding also suppressed the source Run's rise/fall. Run now uses one constant per-clip source-space anchor, chosen from the maximum complete-clip correction; source joint channels and their vertical trajectory remain intact. The measured imported rise is214.206mm. Actual terrain support samples the original flat source foot lift, then corrects each foot against its own finite surface while preserving same-phase source segment lengths. This includes airborne phases rather than dragging raised feet to the floor. Entity coordinates remain authoritative and unchanged.

Native action testing exposed a shared repeated-action defect: `AnimationPlayer.play()` can resume an already assigned/paused category. The second cast reached the previous timeline's end rather than the new event's midpoint. Each accepted native action now seeks its new timeline to0 without immediate pose evaluation, preserving ordinary crossfading. Independent source-free tests reproduce18 failures across animal/sea/monster profiles, classic/new packets and three prior rates before the fix, then pass85/85. Source Snow's actual Cast2/Pillage timing checks also pass. Separate Horse/Ostard/Eagle override paths remain follow-up audit items; this generic correction is not a claim that every specialized presenter has been fixed.

A moving-pose audit found that the Run-to-death crossfade dipped107.615mm below flat ground even though its saved endpoint poses passed. The renderer now applies a temporary negative-only complete-skin correction during that death blend. It lifts only the visual model, preserving native coordinates, imported joint channels and positive source rise; steady poses keep their existing imported support. A further signed-plane audit exposed two walking blends at-9.470/-8.942mm on a slope. The new sole helper chooses the lowest skinned foot point against each actual contact plane instead of the lowest vertical point. The same8mm tolerance remains.

Owned manifests can select an explicitly named presentation script through the registry. The path is restricted to a direct project `Presentation/*.gd` script and the instance must retain the CreatureVisual contract; no code comes from a game archive. Acceptance pins the owned script hash and actual registered-avatar proof. Existing entries keep their previous dispatch. The review uses the same factory for these entries, so its modern column actually renders the game's frost material.

## Evidence and limits

- General poses:1,016 checks/315 complete skins, zero failures; standard GPU13 checks/six views.
- Source/refined/modern actions:59,250 checks/1,554 complete skins/518 phase comparisons, zero failures. All34 relative joint centres agree within10micrometres (measured maximum0). Every segment retains the same-phase original length, including source-authored helper translations; constant length across unrelated source clips is not assumed. Source Run retains214.206mm rise and a constant floor anchor. All grounded sampled categories remain within1.459mm.
- Actual Forward+ factory/avatar:8,019 checks/756 finite-plane poses, zero failures. There are150 lifted-foot/1,014 planted-foot cases and48 two-foot-airborne Run cases. Maximum planted gap1.856mm, maximum retained lift error0.999mm. Full/partial colours differ by3,529 sampled pixels; detailed RGB changes9,346 pixels and authored relief changes9,112 pixels in their controls. Camera, actual picking, upper labels and three static corpse hues are included.
- Actual Forward+ mixed poses:1,297 checks/216 fresh complete skins, zero failures, over six real gait/action transitions on flat and0.08-radian sloped finite colliders. Native attack/cast/death packet paths are included. Minimum signed complete-skin gap is-4.217mm, maximum118.647mm;60 positive-rise cases remain. Actual picker bounds contain every sampled mixed skin, and actor coordinates remain unchanged. This is offline rendering, not arbitrary-terrain/all-phase/native combat certification.
- Real native SnowElemental on both disposable owners:150 checks, zero failures, covering constructor identity, native movement, full/partial hue, classic/new action decoding, death and native corpse body/facing/static skin. AI is frozen for controlled sampling; autonomous melee combat/taming/gameplay are not certified by this harness.
- Shared45 prior local groups pass fresh poses/GPU/focused gates. Final strict gates pass all46 accepted local groups/113 forms:79,329 general checks/23,982 complete skins and1,548 standard GPU checks/678 views. Public Air/Fire/Bogling/Chicken current GPU/native/clean/strict controls pass.
- All189 corpse variants pass1,782 fresh rendered checks. Full root verification exits0, including71 server-extension and84 developer-edit tests plus clean final world startup. Existing Unicode/teardown diagnostics and two unchanged nullable warnings remain.16 fresh source/refined/modern comparison frames are saved privately.

Actual receipts/logs are under ignored `outputs/creatures/snow_elementals/` and `work/creatures/snow-elemental/`. Earlier failed exploratory probes remain labelled: constant-length assumptions across animated source helper translations were replaced by direct same-phase source comparison; a compressed-image texel-inspection error was corrected before the error-free rendered proof. Neither failure was counted as passing evidence.

Physical stance-speed/no-slip travel, exact generated atlas landmark registration, final head/material polish, original particle binding/full choreography, arbitrary terrain and autonomous native behaviour remain open. The global catalogue reports integration coverage with reuse, not final visual/gameplay completion. Continue occurrence-first through BullFrog/GiantToad and the complete remaining list.
