# Original Lich and Lich Lord

The original later Third Dawn bodies now have measured private character presentation. Native Lich24, AncientLich78, DarkGuardian78 and LichLord79 are exercised through their actual ModernUO constructors. Source body82 has the Lord artwork as an explicit compatibility route; no native constructor is claimed for it. The source meshes, atlases, animations, generated derivatives, palettes, downloaded cabinets and screenshots remain excluded from Git. The owned preparation/runtime/verification code is publishable; the game artwork is not granted a redistribution licence by this experiment.

## Sources and recipe

The preservation listing is <https://zuluarchive.com/pages/files.html>; the inspected container is <https://zuluarchive.com/static/files/uoaos.zip>. This is a third-party historical copy, not a current official installer or an authenticity/redistribution guarantee. Bounded HTTP206 reads identified the ZIP central directory and extracted four individual members, checking their sizes and CRCs. The full643,359,825-byte ZIP was not downloaded and has no verified full-file hash. No installer or game executable was run. Trusted installed7-Zip statically extracted the cabinets under ignored `work/third-dawn/late-source-research/`.

Exact cabinet, original-member and private generated-albedo pins are in [the input manifest](../scripts/lich-inputs.json). The cabinets are client7.cab (model table), client11.cab (monsters/motions), client10.cab (maps) and client12.cab (rigid equipment). Their SHA-256 values are respectively `8180b7c2b7cb4ca6e868a3ff460e25c0e6aa710367b8d5487d2d455bfef29859`, `307a6b91c4d5459080d1fe8a74ae4fe0b91dea8a21a2866ca91e7dc7ba92f1a8`, `92e9b23c0c226a0d20af5402af7624b188d3bf6e1c4adb510c9d0575d2daa1d9` and `e8eb9d3a04306a553c10f0570f3ca7dbb46354ede26763a99ffb98bdc175c15f`.

`liche_liche_retro_lod2.grn` and `liche_liche_lord_retro_lod2.grn` each contain231 points,450 source triangles and36 source joints. Model-table scale1.5 is retained; original/refined/modern comparisons share the same body proportions and source rig. Refinement yields7,200 triangles per body, retaining source UVs and skinning. Seven recovered motions (Idle, Walk, Run, Attack, Hit, Death, Fidget) remain beside four explicitly authored categories (Attack2, Attack3, Cast, Pillage) and the common terminal LieDown pose. Unamended joint centres and measured limb lengths are compared directly between original and modern imports. A120Hz source floor track bounds the measured imported poses; this conversion is not proof of every original-client transform, particle or action sequence.

The original128-square RGBA atlases control opacity independently of the generated RGB. This preserves torn robe edges, hair and hand cards. The private generated atlas supplies woven cloth and desiccated skin detail; the Lord has an authored crimson accent. Cloth-only partial dye and relief inferred from albedo are authored shader choices, not recovered original partial-hue/normal maps. Original `_m` maps inspected here are entirely zero. Raw native hue bits and the original palette remain authoritative.

The actual later `weapon_liche_staff_lod2.grn` has30 points/40 triangles and its original weapon atlas. It uses the source right-grasp socket, authored idle-up orientation and0.8 relative prop scale. Two measured source finger chains close around its shaft. A support amendment can raise the reachable arm while preserving wrist orientation and limb lengths. Death restores source finger rotations and releases the prop to rest beside the corpse. This is default artwork: native Lich and LichLord **pack** a GnarledStaff as loot, rather than equipping this displayed prop. No extra server item is spawned or equipped.

Render-stage landmark updates synchronize the actual picking box/nameplate after staff and foot corrections. Terrain support measures the flat source foot lift before solving each limb against its actual finite collider, rather than misclassifying a low step on a slope. Native actor coordinates remain unchanged. Corpse graphic remains0x2006 with body identity in amount; no invented wire graphic IDs are used. All four body routes inherit the runtime corpse catalogue automatically.

## Current evidence

- General imported poses:1,805 checks/546 complete skins, zero failures.
- Focused actual original/refined/modern actions:20,174 checks/1,512 complete skins/504 paired joint poses, zero failures. Maximum flat body-floor error2.446mm; unamended joint-centre error0. Measured flat held-hand support displacement0, wrist rotation difference0.056degrees (floating-point noise).
- Actual Forward+ avatar:8,470 checks/720 finite-plane poses/12 body-hue corpse variants, zero failures. Includes all12 declared categories on six raised/lowered flat/sloped planes for both models,60 lifted-foot and1,068 planted-foot cases. Maximum measured planted gap1.986mm. Actual full/partial hues, Lord accent, original cutouts, modern RGB and multi-angle staff visibility have distinct pixels. Original staff visibility totals2,430 sampled changed pixels per model across three camera views.
- Standard GPU control:27 checks/12 views, zero failures. Candidate corpse acceptance:35 checks/four bodies, zero failures.
- Actual native two-client test:646 checks, zero failures, covering Lich, LichLord, AncientLich and DarkGuardian on both owners. Constructor body, movement, full/partial hue, classic/new action decoding, death, native corpse identity/facing and final static skin replicate. AI is frozen for controlled sampling: autonomous mage combat, AncientLich/LichLord special summons and all gameplay are not certified.
- Refreshed full corpse catalogue:188 variants/1,773 rendered checks, zero failures.

Full `scripts/verify.ps1` exits0, including71 server-extension/84 developer-edit tests and clean final world startup. Existing Unicode/teardown diagnostics and two unchanged PreviewTools nullable warnings remain. Air/Fire/Bogling/Chicken current Forward+/native/clean/strict public controls pass. Ten affected accepted local families pass their current focused gates, and all45 accepted local families pass final exact-input strict acceptance. The first broad driver also tried the **superseded, unaccepted original Dolphin trial**, which fails six floor checks; this is separate from the accepted public independent Dolphin, whose current clean-distribution checks pass. That driver therefore exits1 honestly; its other ten accepted families completed successfully. No failing source trial is routed or counted.

All45 accepted local groups/112 forms retain exact current pose inputs:78,313 checks/23,667 skins. Standard GPU evidence covers1,535 checks/672 views; unchanged inputs reuse their prior exact receipts and affected shared-avatar gates are refreshed. Evidence lives under ignored `outputs/creatures/liches/` and `work/creatures/lich/`; original/refined/modern comparison captures include16 fresh frames per Lich kind. Source-only publication is tracked independently from all private inputs and captures.

## Reproduction

With the exact private inputs already in their documented temporary locations:

```powershell
python -B scripts/prepare-liches.py --check-inputs
# Optional static extraction of the pinned cabinets:
python -B scripts/prepare-liches.py --extract
python -B scripts/prepare-liches.py --prepare
scripts/test-creatures.ps1 -Families @('liches') -Capture
scripts/test-horses.ps1 -Live -SkipContact -CreatureFamily liches
scripts/build-corpse-catalogue.ps1 -Render
python -B scripts/build-creature-catalogue.py
python -B scripts/build-creature-actions.py
scripts/verify.ps1
```

The live harness refuses an occupied2594 port and uses its own disposable runtime/accounts. Production2593, existing saves and the installed UO client are excluded. Native body82 deliberately produces no constructor fixture. The acceptance gate pins the source inputs, recipe, all imported treatments/precision settings, staff, shader/runtime, measured source comparisons and actual terrain/corpse evidence before installing a local route.

## Remaining fidelity work

Original Walk/Run are retained, but physical cadence and no-slip travel are not certified. A private241-phase diagnostic using both stable ankle markers and complete source soles finds uneven stance speeds and lowest-vertex changes; inherited generic speed references are insufficient evidence. Improve actual stance travel without flattening source lift or stretching limbs before claiming final gait quality. The generated atlas does not certify exact UV landmark registration or final art. Original ranged/flight groups remain unsupported rather than being counted as invented equivalents. Arbitrary terrain, original particles/full choreography, dynamic native states and autonomous special abilities remain part of the larger port backlog. Proceed to original SnowElemental, BullFrog and the remaining occurrence queue while preserving these explicit gaps.
