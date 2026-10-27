# Robe motion and natural human appearance

27 October 2026. Implements stages 1–2 of CHARACTER_SYSTEM_PLAN.md in the private equipment review. Live avatar, character creation, login storage and server remain unchanged.

## Robe

The earlier mask removed almost all legs while the lower robe was progressively locked to the pelvis. Rest-pose bounds tests could pass while a running character showed disconnected feet or exposed missing geometry.

The new recipe retains the full lower body below the waist and raises the hem slightly. Eight garment-only front/back controls at four heights are baked from the evaluated native leg motion. Their axial clearance, lateral ease and bounded hem lift allow a stride while keeping a single continuous skirt. Sleeves and upper torso retain their native weights. Toes are excluded from the cloth envelope: enclosing them inflated the skirt along the floor. This is fitted deformation, not cloth simulation.

The original 53 bones remain; eight garment bones make 61 in the equipment variants. Shared native Idle/Walk/Run timing, tracks and rest layout are independently compared with the original free base. Original body geometry is preserved. All 6,386 lower-body triangles below 0.88 m are retained in both robe variants.

## Skin/material research and selection

- Official MakeHuman natural male skins: https://static.makehumancommunity.org/assets/assetpacks/skins02.html
- Official system skins and their CC0 declarations: https://static.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html
- Godot material reference, including normal maps, roughness, anisotropy and Forward+-only subsurface scattering: https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html
- Pinned source export licence notes for the additional hair: https://raw.githubusercontent.com/kblood/CharacterCreator/852e48f316b90a0937234886630e4fb4cdfd1f78/LICENSE-NOTES.md

Compared the Aksel skin with official young male system variants and inspected their previews/material definitions. Tattoos, deliberately applied eyeliner/makeup and aged/bearded skins were unsuitable for a neutral starting character. Aksel's author explicitly says the normal/specular maps include body hair absent from the colour map. Its broad relief was therefore a poor match for this clean base.

Selected young_caucasian_male2 as the clean initial appearance, with young_asian_male and young_african_male as two additional authored colour presets. Each texture retains its original pixels and UV layout. These are reusable authored textures; no claim of calibrated photogrammetry or scanned skin is made.

The original Godot shader uses Burley diffuse/GGX specular, restrained normal detail, narrow roughness/specular variation and modest Forward+ subsurface scattering. A mip-filtered normal detail calculation suppresses broad mismatched relief while retaining fine authored detail. Compatibility retains the diffuse/normal/roughness treatment without subsurface scattering. No third-party shader code was copied.

Eyes have a lighter natural iris, eyebrows use softer colour/coverage, and hair has reduced glossy response. Short and bald options are available in the review, plus three skin presets. Hooded variants conceal hair. Additional sleek/ponytail candidates were inspected but are withheld from visible choices because scalp/ear coverage remains unsatisfactory. The ponytail fitting experiment remains available through explicit diagnostic arguments only; normalized weights and a valid rig do not establish artistic acceptability. These controls are review tools, not saved character-creation settings.

## Exact inputs and evidence

System archive: https://files.makehumancommunity.org/asset_packs/makehuman_system_assets/makehuman_system_assets_cc0.zip

SHA256: b542127a8e25547c7c29c19f2d1d2adb9a664c80396ecd694095dbc8028a0107

Selected colour maps:

| Archive member | SHA256 |
|---|---|
| skins/young_caucasian_male2/young_lightskinned_male_diffuse2.png | 03efe1f6b0ae52429649dcefc9dcaef6058032f874a251169cc3e2ed473c3874 |
| skins/young_asian_male/young_lightskinned_male_diffuse3.png | f50016a5507fc687dc8df06599c8ea48de950cd185de33a71cafc1319ddab4d5 |
| skins/young_african_male/young_darkskinned_male_diffuse.png | e3f0dbb634e4c68561338f0087f7a122444e84ec56df102212f1222aa12e4d50 |

The corresponding mhmat files explicitly declare CC0. Their hashes, archive URL and default selection are pinned in scripts/prepare-natural-skin.py and local-art/free-equipment/natural-skin-provenance.json.

Additional hair exports use pinned CharacterCreator commit 852e48f316b90a0937234886630e4fb4cdfd1f78:

| File under output/ | Source SHA256 |
|---|---|
| hair_short04.glb | ee2b27b2a004297ed5150edb7f6dc321e22cb87a30b5b7dcea582e1cf4789598 |
| hair_ponytail01.glb | 944efb6fb4bc223017697d4838ba27ec95c58866f2c98eac661e32f50467ebed |

Only data was downloaded. The exporter licence notes, hair catalog and source asset licence records declare these CC0. Gender/muscle morphs are baked to match the fixed male base; the same native rest skeleton and normalized weights are validated. Output hashes are recorded in hair-provenance.json. Existing clothing/Aksel input pins remain in download-free-equipment.py.

## Reproduction

1. Verify/fetch the existing pinned inputs with scripts/download-free-human.py and scripts/download-free-equipment.py. Use --verify-only for an existing checkout.
2. Run the repository's Blender in background with scripts/prepare-free-equipment.py. It invokes the original robe-motion.py and prepare-natural-skin.py; no downloaded scripts are executed.
3. Optionally run Blender with scripts/prepare-human-hair.py for the experimental pinned ponytail. Both additional hair candidates remain withheld from the UI after visual rejection; this optional experiment is not required for the approved short/bald appearances.
4. Run Python scripts/validate-free-equipment.py and Blender scripts/validate-robe-clearance.py.
5. Run scripts/review-third-dawn.ps1 -Equipment -Human. Use Robe movement, Idle/Walk/Run, front/profile and the appearance controls. The wrapper accepts -Phase and -Screenshot for reproducible poses. Direct Godot review arguments --motion-grid --clip=Run --angle=profile --view=robe produce eight evenly spaced rendered poses.
6. Run scripts/verify.ps1. No live login change was made; live-login testing is reserved for integration.

## Validation scope

Actual asset validation: eight variants, shared 61-bone skeleton/animations, normalized weights, unchanged base body, preserved lower-body triangles, and the additional ponytail mesh. Native rest error is below 8.14e-7; native animation numeric error is below 8.04e-7 after export, including unchanged timing.

Independent geometric robe check: 48 poses across Idle/Walk/Run, 25,648 retained-leg vertex samples above both 0.50 m and the animated opening, side-ray enclosure and robe floor clearance, zero failures. The moving open hem is intentionally excluded; a raised heel is allowed below the lifted opening. This does not prove arbitrary animation/collision correctness.

Further evidence and final project check results are recorded in outputs/third-dawn/natural-human-review-evidence.json. All art and captures remain local and ignored. Combat, sitting, other body shapes, live equipment swapping and universal wardrobe coverage remain later work. Artistic acceptance remains the owner's review.
