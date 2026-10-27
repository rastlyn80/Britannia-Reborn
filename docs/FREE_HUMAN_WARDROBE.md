# Free human base with UO3D wearables

Owner rejected continued sculpting of the old UO body and requested a good-looking freely downloadable human foundation, then a real test with original UO3D wearables. Selected a textured MakeHuman/MPFB-derived body exported by CharacterCreator. The exported data is CC0-1.0; its generator code is separately GPL-3.0-or-later and was not executed or vendored. This is a candidate for owner visual review, not final art approval or a live avatar replacement.

## Sources considered and exact download

- Selected: [CharacterCreator generated body/hair/briefs](https://github.com/kblood/CharacterCreator/tree/852e48f316b90a0937234886630e4fb4cdfd1f78/output), pinned commit `852e48f316b90a0937234886630e4fb4cdfd1f78`. [Publisher licence notes](https://github.com/kblood/CharacterCreator/blob/852e48f316b90a0937234886630e4fb4cdfd1f78/LICENSE-NOTES.md) explicitly release generated GLBs, morphs and animations under CC0. The [MakeHuman core asset licence](https://static.makehumancommunity.org/about/license.html) independently confirms CC0 for the underlying core assets.
- Existing alternative: [Quaternius Universal Base Characters](https://quaternius.com/packs/universalbasecharacters.html), CC0, already used by the default project Avatar; its stylized superhero proportions are a different direction from this realistic-body experiment.
- Considered but not selected: [Innerscene MakeHuman base](https://www.innerscene.com/tools/library/3d-parts/male-base-mesh-3d-person-rigged-a-pose-380e6d89), CC0, advertised as clay-grey and roughly 109k triangles. Selected the textured, animated export instead.
- Added the original male skin from [MakeHuman's official CC0 system pack](https://files.makehumancommunity.org/asset_packs/makehuman_system_assets/makehuman_system_assets_cc0.zip), member `skins/young_caucasian_male/young_lightskinned_male_diffuse.png`. This replaces the female skin shipped in the chosen export; asset-pack source/hash/member names are recorded locally.

Exact URLs and SHA-256 values are pinned in `scripts/download-free-human.py` and ignored `work/free-human/download-manifest.json`. Downloaded model inputs: base_body_anim.glb, hair_short02.glb, clothing_briefs.glb, base_body.joints.json, asset_licenses.json and hair.json. Saved publisher LICENSE-NOTES.md is hash-checked. Downloading/extraction only; no downloaded scripts, installers or executables are run. Uses the existing official Blender tool with our own script.

## Reproduction

1. `python scripts/download-free-human.py` (network access required); `--verify-only` checks all pinned inputs without downloading.
2. Retain/import the local UO ZIP and prepare original gear using the earlier THIRD_DAWN_HUMAN.md steps.
3. `.tools/blender/blender-5.2.1-windows-x64/blender.exe -b --factory-startup --python scripts/fit-uo-to-free-human.py`
4. `python scripts/validate-free-human.py`
5. `./scripts/review-third-dawn.ps1 -FreeHuman -Human -View clothing`. Use `-View bust -Angle three-quarter` for old/new anatomy, `-Clip Walk` or `-Clip Run` for movement, `-Compatibility -Validate` for alternate-renderer validation.

Outputs remain in ignored Viewer/local-art/free-human: free-human.glb, free-human-shirt.glb, free-human-robe.glb and provenance.json. The private combined outputs include proprietary-derived garments and must not be committed. Base CC0 inputs can be treated separately if later adopted, but this pass keeps every experimental binary local. Original UO assets, original Documents/Codex prototype and default live Avatar remain unchanged.

## What the conversion does

The publisher GLBs currently default all 92 morph weights to one. The fitter explicitly clears/bakes only gender_male=1 and muscle_max=0.35, applies the corresponding supplied joint offsets and removes unused morph payloads. It retains 53 target bones and the target's own Idle/Walk/Run clips. Hair/briefs use the same baked shape. Body/face includes eyes, brows/lashes, teeth and tongue. The base is 41,160 triangles including these parts, hair and briefs, rather than the UO body's 362.

UO inputs are the original H_MALE_Armor_Chain_Shirt_LOD2.grn and H_MALE_Robe_cowldown_LOD2.grn through the existing converter. The fitter maps original bone semantics to the new skeleton, changes from the source T-pose to the target bind pose and scales anatomical segments. Crucially, it uses the FULL original human skeleton for segment endpoints: garment rigs omit unweighted child bones, whose arbitrary display-bone lengths caused the first failed fit to stretch. Named source weights are remapped to target bones; no UO rig or UO animations remain in the new outputs.

Simple garment tessellation supports local surface projection, retaining the original UVs/albedo. Inside/near-surface vertices are pushed outside the new body, collars/hem are bounded, weights are normalized/pruned to four influences, covered body faces are hidden and covered briefs are omitted. Robe lower-hem weights fade from calf-heavy source weights toward the pelvis to stop floor penetration. This is an explicit long-skirt fitting rule, not cloth simulation. Skin/garment material roughness and robe tint are reviewed separately from the topology.

Chain shirt: 2,014 exported garment vertices / 2,544 triangles / 13 mapped bones. Robe: 3,990 garment vertices / 5,040 triangles / 15 mapped bones. Largest initial surface corrections are about 90 mm (shirt) and 45 mm (robe), so this is a real refit rather than a bone rename. The report includes exact values and all input/output/code hashes.

## Validation and limits

Pinned input/hash verification, ten existing source-free importer/refinement tests, and independent checks of all actual GLB vertex positions, normalized weights, joint indices, shared 53-bone rest rig and identical Idle/Walk/Run tracks pass. Evidence: outputs/third-dawn/free-human-asset-validation.json. Each variant contains its own self-contained target rig/animator; runtime swapping to one shared Avatar rig is not implemented here.

Both renderers' review validation samples five actors at four phases of three clips, including two refitted garments, and reports zero deformation/root/grounding/bounds failures. Target running has a natural aerial phase (about 36–38 mm at sampled phases); for this model Run checks floor penetration separately and bounds flight height at 90 mm instead of artificially pinning a foot. Idle/Walk retain the existing ground tolerance. Evidence: free-human-forward-validation.json and free-human-compatibility-validation.json.

Fresh base/clothing, movement and old/new face captures were visually inspected. Old UO materials/garment folds remain visibly dated; cuffs/collars, skirt motion and clipping in more extreme poses need artistic work. Bounds tests do not prove clipping freedom. This establishes feasibility for these two garments and this one fixed body shape; arbitrary body sliders, other races, every wearable, layering, attacks/deaths, cloth physics and live equipment mapping are not claimed. The free base licence does not grant distribution rights for UO-derived clothing.

The required broader project checks pass (exit 0); evidence is recorded in outputs/third-dawn/free-human-full-verify.log. Two unrelated roof/display-counter declarations needed explicit bool annotations to compile in the current shared workspace; no gameplay or server code was changed.
