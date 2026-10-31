# First male/female human batch — 27 October 2026

The fitted CC0 male and female humans are integrated into the playable Godot
client and character-sheet portrait. ModernUO supplies the body, skin hue and
worn items. The existing creation panel now offers male or female humans; this
is not yet the planned graphical appearance creator.

## What is included

- Fixed male (1.80 m) and female (1.72 m) shapes, natural sex-specific skin
  textures, eyes/brows, native short-hair or bald display and modest underwear.
- Five fitted free clothing meshes per sex: mail tunic, trousers, boots, robe
  and hood. Garments attach independently to the same animated 61-bone rig.
- Thirty-two body-coverage masks per sex. Changing clothing retains the
  animator and current gait phase. Robes retain the complete underlying legs.
- Native player and nearby-character appearances, full snapshot replacement,
  equip/remove/container updates, item hues and a shared portrait renderer.
- Legacy visual fallback when prepared local assets are absent or the native
  body is outside the two supported human bodies (400/401).

The female sleeve check caught a real fitting defect: the old height-only
skirt rule captured shorter cuffs and anchored them to the pelvis. The recipe
now preserves all authored arm influences. An independent 48-pose check also
tracks 78 female cuff landmarks relative to the wrists.

## Mapping and limitations

HumanWardrobe.gd lists the exact native graphic IDs. Shirts, fancy shirts,
doublets, tunics and chain chests currently share the mail-tunic substitute.
Short/long pants share trousers; **female starter skirts/kilts temporarily
also use trousers**. Shoes, sandals and boots share the boot substitute.
Robe graphics select the robe; monk/hooded shrouds select robe plus hood.
These are category replacements, not replicas of each original item.

Unknown wearables remain recorded as unsupported; weapons, shields, jewellery,
cloaks, speciality armour and the complete UO wardrobe are not solved. Hair
currently means short hair when the native hair layer exists, otherwise bald;
different native hair IDs are not distinct hair meshes. Three authored skin
presets approximate native skin-hue groups. Cloth hues are restrained RGB
tints, not exact UO palette remaps. Broader body sliders, graphical skin/hair
selection and additional cosmetic-profile persistence remain later stages.

## Animation is an open quality requirement

The owner explicitly rejected the current mannequin-like movement. The
existing MakeHuman Idle/Walk/Run clips remain a functional integration
baseline; they are **not accepted final locomotion**. Numeric deformation
checks cannot establish fluent or natural movement.

HumanMotionAudit.gd tested the already bundled CC0 Quaternius UAL1 Standard
Idle/Walk/Jog_Fwd/Sprint on both human rigs. Bone/rest retargeting is feasible;
the source `Head` maps to `head`, and four unused right fingertip leaf tracks
are omitted. Both rigs were sampled at 16 phases per clip with finite poses
and stationary entity roots. These candidates have not replaced locomotion.

Next animation work: compare authored motions visually, tune hip/torso and
arm motion, match cadence to measured travel, improve gait/turn/stop blending,
check stance-foot sliding and stair contacts, then rebake robe controls for
the selected motion. The present robe controls were fitted to the original
three clips; arbitrary new animation must not be advertised as validated.

## Sources and reproducibility

The body, morphs, joints, short hair and underwear are exported CC0 data from
[CharacterCreator, pinned commit 852e48f316b90a0937234886630e4fb4cdfd1f78](https://github.com/kblood/CharacterCreator/tree/852e48f316b90a0937234886630e4fb4cdfd1f78/output).
Its separately licensed generator code was not executed or imported.
The additional female input `clothing_bra.glb` has SHA256
`5f664e238312be3c4507f77f7e012b30731dbe0618c8e2941c350f516090fd5b`.
Male morphs are gender_male=1, muscle_max=.35; female morphs are
gender_female=1, muscle_max=.15, with corresponding source joint offsets.

Skin inputs come from the
[official MakeHuman system CC0 pack](https://files.makehumancommunity.org/asset_packs/makehuman_system_assets/makehuman_system_assets_cc0.zip),
SHA256 `b542127a8e25547c7c29c19f2d1d2adb9a664c80396ecd694095dbc8028a0107`.
The three female albedos and their material declarations are pinned individually
in prepare-natural-skin.py; pixels are unchanged. The live shader supplies
restrained detail/roughness and Forward+ subsurface scattering. Transparent
portraits omit SSS because that viewport does not support it.

Clothes are Donitz's monk robe/hood and RehmanPolanski's Viking tunic/pants/boots
from the [official suits02 CC0 pack](https://files.makehumancommunity.org/asset_packs/suits02/suits02_cc0.zip),
SHA256 `437f4d7ab92b698c1fb1047e7d62b22c11f195b2473e936118661dc8e6b7eb7a`.
Normal/specular source pins and author records remain in download-free-equipment.py.
Every selected input is hash-checked; no downloaded generator code is run.

From the project root:

1. `scripts/prepare-human-batch.ps1` fetches verified inputs and builds both
   bases, eight complete review variants, five runtime garment meshes and 32
   runtime body masks per sex. Uses the repository's Blender and local recipes;
   `--base-only` avoids any UO-derived inputs. Run `-VerifyOnly` to check an
   existing prepared batch without rebuilding it.
2. Let Godot import the prepared local assets. Launch normally to use them in
   game. `Reviews/Review-Human-Batch.cmd` opens the same renderer in a neutral studio.
3. `scripts/test-human-batch.ps1` checks appearance packets, mapping, all 32
   equipment combinations on both rigs, animation continuity and jump paths.
   `-Live -Visual` additionally uses dedicated local test accounts, reconnects
   both characters, removes/restores robes, checks a second client's updates
   and saves actual client/portrait screenshots.
4. `scripts/verify.ps1` and `scripts/test-login.ps1` run the broader project and
   native login regressions.

Inputs are under ignored work/free-human and work/free-equipment. Generated
art is under ignored Viewer/local-art/free-human[-female] and
free-equipment[-female]. Existing proprietary UO experiment files remain
separate and are not inputs to this first live batch. No art has been committed
or published. Original installation, owner login credentials and existing
characters are preserved; dedicated test character credentials remain local
under ignored work/character-polish.

## Evidence

- Full project verification and native login smoke passed. Targeted human,
  retargeted movement and live checks were repeated after the final fixes.
- Actual GLBs: eight complete variants plus 37 runtime files per sex,
  normalized weights, valid joints, native skeleton/timing comparisons and
  retained lower-body coverage; no reported failures.
- Independent robe geometry: 48 poses per sex, 25,648 male and 29,038 female
  leg samples, no enclosure/floor failures above the animated open hem.
  Female cuff landmarks also remain within the bounded wrist envelope.
- Live dedicated characters: native bodies 400/401; robe removal changes the
  visible mask from 14 (robe/pants/boots) to 7 (tunic/pants/boots), re-equipping
  restores it; both identities/sexes survive reconnect. A second connected
  client receives the female body and robe removal/re-equipping.
- Evidence files under outputs/third-dawn: human-batch-live.json,
  free-equipment-asset-validation.json, female-equipment-asset-validation.json,
  robe-clearance-validation.json, female-robe-clearance-validation.json and
  human-motion-feasibility.json. Execution logs are under work/character-polish.

These checks establish the first batch's integration and sampled deformation,
not universal equipment compatibility, cloth physics or animation quality.
