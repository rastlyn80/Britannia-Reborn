# Human frontier batch â€” 30 October 2026

The human wearable catalogue now maps **400/1,126 graphics (35.52%)**, up from 248 (22.02%). It contains **152 equipment categories**, up from 73. The denominator is unchanged; monsters, elf-only circlets, gargoyle equipment and rejected apron experiments were not added to the numerator.

This is the established **category replacement** metric. A distinct native item can select a fitted replacement while still needing exact silhouette, ornament, texture or combat work. This batch includes material variants of existing fitted geometry. It does **not** mean 35.52% of original equipment has final, individually recreated art or bespoke animation.

## Implemented

Added **79 models per body / 158 local exports / 152 native graphics**:

- Dragon and bone armour, Tokuno leather/studded/plate do, haidate, suneate and hiro sode; ninja jacket/pants/mitts and ringmail gloves.
- Jingasa, kabuto, hatsuburi, ninja hood, kasa, orc helm and flower garland.
- Axes, blades, polearms, martial weapons, fishing pole, yumi and composite bow.
- Six school books: necromancy, chivalry, bushido, ninjitsu, spellweaving and mysticism.

All additions use the existing male/female skeletons. **33 of the 79 models per body** retain the exact fitted triangle topology and named skin weights of existing armour, cloth, glove, helmet or book inputs. Roundtrip float32 tolerances are <2 micrometres for vertex positions and <2e-5 for weights. The other 46 are original parametric headwear/weapons/bows. Native IDs/hues/hair remain separate from the replacement mesh.

Armour keeps continuous neutral textile backing and opaque manufactured plates. Metallic dragon/plate materials use metallic 0.9, roughness >=0.5; native dyes preserve those properties. No new body-hiding masks were introduced. Plate-derived leg variants select the existing fitted under-greave boots. Book variants select the existing book hand fitting; new bows select the ranged stance and left grip. Mounted locomotion continues to select rider clips.

Long hair remains depth-tested. Brimmed hats and kabuto have real rear openings for ponytails; coif-style tail fits remain compatible with the cape. No depth override draws hair through armour.

## Sources and native identity evidence

`human-frontier-inputs.json` pins every consumed fitted GLB/material, exact ModernUO class file/hash and per-ID mapping basis. ModernUO revision: `ab59efea86fd9e399d261bed9d188ab4d95ad4c2`, unchanged from `Server/dependencies.json`. Its checkout was inspected read-only; no gameplay or race restrictions were changed.

**125 graphics** have a literal/Flippable reference in pinned server source. **27 are client direction counterparts**, verified in the existing local tile catalogue by the same tile name and same nonzero animation reference as a class-backed canonical graphic. These are explicitly marked as counterparts in the manifest, rather than claimed as server constructors. The validator also checks inherited race restrictions. A native graphic being indexed is not evidence that the current server actively uses every variant or expansion feature.

Selected rig/clothing/helmet inputs are **CC0** from [CharacterCreator revision 852e48f](https://github.com/kblood/CharacterCreator/tree/852e48f316b90a0937234886630e4fb4cdfd1f78) and the pinned MakeHuman community packs. The consumed clothing includes MargaretToigo's shirt/gloves and grinsegold's Corinthian helmet, previously fitted in this project. Original armour topology, new parametric meshes and material-pattern generators are project **GPL-3.0-or-later**. The existing CC0 Fabric045 normal retains its source notice. Exact upstream URLs, archive/member hashes, author metadata and licence evidence remain in:

- `scripts/character-expansion-inputs.json`
- `scripts/human-coverage-inputs.json`
- `scripts/human-tailoring-inputs.json`
- `scripts/human-motion-inputs.json`
- `Viewer/Art/MedievalKit/NOTICE.md` and `CREDITS.md`

No game mesh, game texture or source installation was copied into this batch. Generated art, source archives, local tile/animation catalogues and screenshots remain ignored and uncommitted.

## Validation and local review

The local evidence directory is `outputs/human-frontier/`. `index.html` contains **316 completed Godot frames**, male/female walking and riding, front/rear, plus eight contact sheets. Weapon framing includes polearm tips; book views expose the carrying hand. These are actual renderer captures, not image-generated previews.

Final evidence:

| Check | Result |
|---|---|
| Native IDs, dyes, grips and completed pose frames | **19,472 checks / 5,056 GPU views, 0 failures** |
| Every new torso/arm/leg/glove in complete armour | **1,600 GPU views, 0 failures** |
| Long hair + ponytail, cape, new heads/torso/arms | **864 GPU views, 0 failures** |
| Total finite walking/running/riding views | **7,520** |
| New source/native/geometry audit | **152 IDs / 158 exports / 66 preserved fitted derivatives, 0 failures** |
| Full accepted coverage export audit | **268 exports, 0 failures** |

The 5,056 pose views cover every new model on both bodies, foot/riding, Walk/Run, two gait phases and four angles. Every new native ID was separately applied with undyed, full and partial hues in each body/mount state. The checks verify independent hair identity/hue, preserved material roughness/metalness, closed holding fingers, book/ranged routing, seat error <=2 mm and stirrup error <=25 mm. Armour uses an independent complete unmasked-body reference: <=4 visible skin pixels, >=98% total body occupancy and >=99.5% seat occupancy. Hair retains >=98% depth-tested tail pixels against a full-body reference.

`validate-human-frontier.py` independently checks input/generator hashes, class ancestry and native counterpart evidence, compatible 61-joint inverse binds, finite normals, opaque materials and complete triangle/weight preservation for all 66 derivative exports. `validate-human-coverage.py` checks **268 accepted coverage exports** across both bodies, not only this batch.

The full `scripts/verify.ps1` completed with exit 0. Its assertions passed, including **1,095 human coverage checks** and **2,468 horse checks / 768 contact poses**. It still logs the two pre-existing `TimberBridge.gd:41` missing-`id` fixture errors in StreetTests, teardown/RID/resource diagnostics and two existing nullable-reference compiler warnings in PreviewTools.Tests. This is not a diagnostic-clean suite; those unrelated files were preserved. No live login code changed, and this batch supplies no new live world-entry or multiplayer evidence.

## Reproduce

From the repository, after the existing pinned human/horse foundations have been prepared:

```powershell
./scripts/prepare-human-frontier.ps1 -Gpu -Review
./scripts/build-human-catalogue.ps1 -NoOpen
./scripts/verify.ps1
```

`-VerifyOnly` skips Blender generation while retaining source/export/runtime checks; combine with `-Gpu` for the finite renderer checks. For the optional sheets/gallery builder, use a Python runtime with Pillow:

```powershell
python -B scripts/review-human-frontier.py
```

The repository's bundled Codex Python runtime has Pillow. Runtime tests do not load game server saves or change remembered-login files. The complete `prepare-human-coverage.ps1` pipeline now invokes this batch after its fitted foundation/workwear exports; old generic gear generation skips these separately built recipes.

## Remaining work

Exact native decoration and final art direction remain open. Bone/dragon/Tokuno variants reuse fitted armour silhouettes; school books share the accepted closed tome topology with school cover colours. Haidate/suneate currently use full fitted leg silhouettes. Daisho currently uses a single held sword category proxy; its second blade and dual-wield choreography are still missing. Lajatang currently shares the double-bladed staff profile. Decorative/battle kabuto share horn treatment. These limitations remain category coverage, never exact-design completion.

Bespoke two-handed polearm stances, dual wielding, articulated nunchaku, opening/casting books, fishing actions, drawn bow strings/projectiles, cloth simulation, arbitrary outfit combinations and owner visual approval are separate work. Native race/era/gameplay eligibility is unchanged. Tests use finite poses and image projections; legitimate body/sleeve/horse occluders stay in both prop reference images, so those images are not a universal prop collision proof. No monsters, additional mount families or new action categories were introduced. Existing 35/35 classic, 28/28 on-foot and seven ordinary-horse action groups are unchanged.

Next: review this gallery, improve specific silhouettes/materials and two-handed/dual-wield presentation, then tackle the rejected apron waist/lap construction and missing dresses/surcoats before another coverage expansion.

## Added category registry

| Category | Native graphics | Construction |
|---|---|---|
| dragon_torso | `0x2641`, `0x2642` | Fitted coverage/plate_torso; dragon material |
| dragon_hands | `0x2643`, `0x2644` | Fitted expansion/gloves; dragon material |
| dragon_head | `0x2645`, `0x2646` | Fitted expansion/helmet; dragon material |
| dragon_legs | `0x2647`, `0x2648` | Fitted coverage/plate_legs; dragon material |
| dragon_arms | `0x2657`, `0x2658` | Fitted coverage/plate_arms; dragon material |
| leather_do | `0x277B`, `0x27C6` | Fitted coverage/leather_torso; lamellar_leather material |
| leather_haidate | `0x278A`, `0x27D5` | Fitted coverage/leather_legs; lamellar_leather material |
| leather_suneate | `0x2786`, `0x27D1` | Fitted coverage/leather_legs; lamellar_leather material |
| studded_do | `0x277C`, `0x27C7` | Fitted coverage/studded_torso; lamellar_studded material |
| studded_haidate | `0x278B`, `0x27D6` | Fitted coverage/studded_legs; lamellar_studded material |
| studded_suneate | `0x2787`, `0x27D2` | Fitted coverage/studded_legs; lamellar_studded material |
| plate_do | `0x277D`, `0x27C8` | Fitted coverage/plate_torso; lamellar_plate material |
| plate_haidate | `0x278D`, `0x27D8` | Fitted coverage/plate_legs; lamellar_plate material |
| plate_suneate | `0x2788`, `0x27D3` | Fitted coverage/plate_legs; lamellar_plate material |
| leather_hiro_sode | `0x277E`, `0x27C9` | Fitted coverage/leather_arms; lamellar_leather material |
| studded_hiro_sode | `0x277F`, `0x27CA` | Fitted coverage/studded_arms; lamellar_studded material |
| plate_hiro_sode | `0x2780`, `0x27CB` | Fitted coverage/plate_arms; lamellar_plate material |
| ringmail_gloves | `0x13EB`, `0x13F2` | Fitted expansion/gloves; mail material |
| ninja_mitts | `0x2792`, `0x27DD` | Fitted expansion/gloves; ninja material |
| ninja_jacket | `0x2793`, `0x27DE` | Fitted coverage/leather_torso; ninja material |
| cloth_ninja_jacket | `0x2794`, `0x27DF` | Fitted expansion/shirt; ninja material |
| ninja_pants | `0x2791`, `0x27DC` | Fitted coverage/leather_legs; ninja material |
| bone_torso | `0x144F`, `0x1454` | Fitted coverage/plate_torso; bone material |
| bone_arms | `0x144E`, `0x1453` | Fitted coverage/plate_arms; bone material |
| bone_legs | `0x1452`, `0x1457` | Fitted coverage/plate_legs; bone material |
| bone_hands | `0x1450`, `0x1455` | Fitted expansion/gloves; bone material |
| bone_head | `0x1451`, `0x1456` | Fitted expansion/helmet; bone material |
| heavy_jingasa | `0x2777`, `0x27C2` | Original parametric jingasa |
| light_jingasa | `0x2781`, `0x27CC` | Original parametric jingasa |
| small_jingasa | `0x2784`, `0x27CF` | Original parametric jingasa |
| leather_jingasa | `0x2776`, `0x27C1` | Original parametric jingasa_leather |
| standard_kabuto | `0x2789`, `0x27D4` | Original parametric kabuto |
| decorative_kabuto | `0x2778`, `0x27C3` | Original parametric kabuto |
| battle_kabuto | `0x2785`, `0x27D0` | Original parametric kabuto |
| chain_hatsuburi | `0x2774`, `0x27BF` | Original parametric coif_mail |
| plate_hatsuburi | `0x2775`, `0x27C0` | Original parametric coif_metal |
| ninja_hood | `0x278E`, `0x27D9` | Original parametric coif_ninja |
| kasa | `0x2798`, `0x27E3` | Original parametric kasa |
| orc_helm | `0x1F0B`, `0x1F0C` | Original parametric horned |
| flower_garland | `0x2305`, `0x2306` | Original parametric garland |
| double_axe | `0x0F4B`, `0x0F4C` | Original parametric axe |
| club | `0x13B3`, `0x13B4` | Original parametric club |
| scythe | `0x26BA`, `0x26C4` | Original parametric scythe |
| bone_harvester | `0x26BB`, `0x26C5` | Original parametric scythe_short |
| bladed_staff | `0x26BD`, `0x26C7` | Original parametric bladed_staff |
| double_bladed_staff | `0x26BF`, `0x26C9` | Original parametric double_staff |
| pike | `0x26BE`, `0x26C8` | Original parametric pike |
| lance | `0x26C0`, `0x26CA` | Original parametric lance |
| no_dachi | `0x27A2`, `0x27ED` | Original parametric katana_long |
| wakizashi | `0x27A4`, `0x27EF` | Original parametric katana_short |
| bokuto | `0x27A8`, `0x27F3` | Original parametric bokuto |
| daisho | `0x27A9`, `0x27F4` | Original parametric daisho |
| lajatang | `0x27A7`, `0x27F2` | Original parametric double_staff |
| kama | `0x27AD`, `0x27F8` | Original parametric kama |
| tetsubo | `0x27A6`, `0x27F1` | Original parametric tetsubo |
| nunchaku | `0x27AE`, `0x27F9` | Original parametric nunchaku |
| sai | `0x27AF`, `0x27FA` | Original parametric sai |
| tekagi | `0x27AB`, `0x27F6` | Original parametric claw |
| tessen | `0x27A3`, `0x27EE` | Original parametric fan |
| fukiya | `0x27AA`, `0x27F5` | Original parametric fukiya |
| fishing_pole | `0x0DBF`, `0x0DC0` | Original parametric fishing_pole |
| assassin_spike | `0x2D21`, `0x2D2D` | Original parametric spike |
| leafblade | `0x2D22`, `0x2D2E` | Original parametric leafblade |
| war_cleaver | `0x2D23`, `0x2D2F` | Original parametric cleaver |
| diamond_mace | `0x2D24`, `0x2D30` | Original parametric diamond_mace |
| wild_staff | `0x2D25`, `0x2D31` | Original parametric wild_staff |
| rune_blade | `0x2D26`, `0x2D32` | Original parametric greatsword |
| radiant_scimitar | `0x2D27`, `0x2D33` | Original parametric scimitar |
| ornate_axe | `0x2D28`, `0x2D34` | Original parametric axe |
| elven_machete | `0x2D29`, `0x2D35` | Original parametric cleaver |
| elven_spellblade | `0x2D20`, `0x2D2C` | Original parametric greatsword |
| necromancer_book | `0x2253` | Fitted coverage/spellbook; book material |
| chivalry_book | `0x2252` | Fitted coverage/spellbook; book material |
| bushido_book | `0x238C` | Fitted coverage/spellbook; book material |
| ninjitsu_book | `0x23A0` | Fitted coverage/spellbook; book material |
| spellweaving_book | `0x2D50` | Fitted coverage/spellbook; book material |
| mystic_book | `0x2D9D` | Fitted coverage/spellbook; book material |
| yumi | `0x27A5`, `0x27F0` | Original parametric bow_yumi |
| elven_composite_bow | `0x2D1E`, `0x2D2A` | Original parametric bow_composite |
