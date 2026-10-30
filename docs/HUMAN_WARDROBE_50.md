# Human wearable 50% checkpoint — 30 October 2026

**572/1,126 indexed graphics (50.80%)**, up from 400/1,126 (35.52%). **258 equipment categories**, up from 152. This batch adds **172 native graphic mappings and 106 category models per body**, with **34 independent riding variants per body**. The denominator is unchanged.

This remains the established **category replacement** metric. Many additions are material variants of an existing fitted shape. The count is not a claim of individually recreated native silhouettes, final material/ornament quality, active server classes, or 172 new animations. Existing 35/35 classic, 28/28 on-foot and seven ordinary-horse action groups are unchanged. Monsters and other mount families remain out of scope.

## Implemented

The accepted set includes fitted dresses/robes/kimono, capes and quivers, skirts/hakama/kilts, trousers and footwear, additional armour, mempo, hats/hoods/spectacles, belts/talisman, shields, hatchet/crescent blade and other held props, plus lit/unlit torches, candles and lanterns. Native IDs, layer numbers, item hues, hair/beard IDs and colours remain authoritative.

- Outer garments reuse the existing robe mask and replace obscured upper layers without drawing a duplicate robe. Their independent split riding meshes and existing lining/cloth-safe locomotion are selected through explicit metadata. The catalogue checks required riding files on both bodies before counting them.
- New full boots use the existing foot mask. No additional body-hiding geometry/masks were authored. Skirt/kilt derivatives retain the previously accepted tighter thigh geometry.
- Lantern variants use the existing left-hand fitting, and held items retain a closed holding hand. Pose review selects the same weapon/cloth/rider movement routing used by the game.
- Spectacles preserve scalp hair and beard visibility. The closed pumpkin helmet hides beard meshes while preserving the server's beard identity/hue. Long hair remains depth-tested; new hats use real rear clearance ports and existing coif/cape fits.
- Skin, character creation, login, game protocol, server gameplay/race restrictions, converter and original IR were not changed.

## Source and eligibility evidence

`human-wardrobe50-inputs.json` pins all consumed fitted GLBs/materials and the local `tiledata.mul`, `mobtypes.txt` and `Equipconv.def` hashes. Class-backed IDs and client references are distinct:

- **92 graphics** have a pinned ModernUO class/property/table reference or a verified named tile counterpart. Declared inherited `RequiredRace(s)` restrictions are checked. ModernUO revision stays `ab59efea86fd9e399d261bed9d188ab4d95ad4c2` from `Server/dependencies.json`; the source checkout was inspected read-only.
- **80 graphics** are curated client equipment variants: indexed wearable flag, selected human garment/accessory family and a nonzero `EQUIPMENT` reference in the installed client metadata. They have **no active class/eligibility certification in the pinned server**. The renderer can present the raw graphic when supplied; this does not add server classes, enable expansion content or change who may equip it. Ambiguous racial/monster entries and unnamed reserved layer-15 graphics were excluded.

Selected body/cloth/glove/helmet inputs remain CC0 from [CharacterCreator revision 852e48f](https://github.com/kblood/CharacterCreator/tree/852e48f316b90a0937234886630e4fb4cdfd1f78) and the pinned MakeHuman community packs; linen/normal inputs remain CC0. Original plate/riding geometry, new parametric accessories, masks/ports and material generators are project GPL-3.0-or-later. Recoloured shield derivatives retain **CC-BY-4.0** geometry attribution:

- wolfgar74, [Wall Shield (Free)](https://sketchfab.com/3d-models/b575f2bf5f9d469291b426a03b2e6aa5).
- Artem Mykhailov, [Medieval Shield](https://sketchfab.com/3d-models/b98b8f64d935415aab0fe9b70074511f).

Exact source URLs, archive/member hashes, selected authors and licence evidence remain in `character-expansion-inputs.json`, `human-coverage-inputs.json`, `human-tailoring-inputs.json`, `horse-riding-inputs.json`, `Viewer/Art/MedievalKit/NOTICE.md` and existing credits/notices. No new source downloads were needed. No proprietary mesh/texture was used by this builder. Generated art, local source catalogues, screenshots and drafts remain ignored and uncommitted.

## Verified results

| Check | Result |
|---|---|
| Native identity/material/grip and completed pose frames | **21,310 checks / 6,784 views, 0 failures** |
| Armour/garment opacity | **3,200 views, 0 failures** |
| Long hair/ponytail, cape and new layers | **2,144 views, 0 failures** |
| Total new finite walking/running/riding views | **12,128** |
| New source/native/bind/topology audit | **172 IDs / 280 exports, 0 failures** |
| All accepted base coverage exports | **480 exports, 0 failures** |
| Previous 35% batch regression | **19,472 checks / 5,056 pose views, 0 failures** |

The source audit independently checks hashes, per-row generator/dependency provenance, native references, 61 compatible inverse binds, finite geometry/weights, opaque materials and complete derivative triangles/weights. **202 of the 280 new exports** preserve an existing fitted source, including riding variants; positions match within a <2-micrometre float32 roundtrip tolerance (observed maximum <0.001 mm), weights within 2e-5. The remaining 78 are original parametric exports. The shared triangle auditor was extracted from the previous batch; the previous builder is now importable, and its existing 158 exports were revalidated.

The 6,784 main pose views cover every accepted category on both bodies, foot and horse, Walk/Run requests, two phases and four angles. Actual selected clip names are recorded: long garments may select Jog, weapons select armed locomotion, mounted actors select rider clips. Every indexed ID is also applied with undyed, full and partial hues. Tests check independent native hair identity, preserved physical material factors, closed holding fingers, book/ranged routing and actual seat/stirrup contacts. Every model/body/mount group has a nontrivial rendered projection.

Coverage views use a complete unmasked-body reference: <=4 visible skin pixels, >=98% total body occupancy and >=99.5% seat occupancy. Hair retains >=98% of depth-tested tail pixels with complete bodies in both reference frames. These are finite projections; legitimate body/sleeve/horse occluders stay in both prop reference images, so those images are not a universal prop collision proof. Arbitrary outfits and every action combination are not certified.

Full `scripts/verify.ps1` completed with exit 0, including **1,439 human coverage checks**, **26 native layer/resource checks** and **2,468 horse checks / 768 contact poses**. It still logs the two existing `TimberBridge.gd:41` missing-`id` errors from StreetTests fixtures, teardown/RID/resource diagnostics and the existing PreviewTools nullable warnings. The script is not diagnostic-clean; unrelated terrain/building/item work was preserved. No live login code changed, and this batch adds no live world-entry or multiplayer evidence.

## Rejected and uncounted

Nine mask/veil categories (17 graphics) were rejected after actual renders: crude tribal/horned/orc/bear/deer/kitsune/Ankur/tiger face prototypes and haunted veil. These stayed unmapped despite passing structural/pose checks.

Formal shirt, jester suit, surcoat and jin-baori (eight graphics) passed civilian views but failed strict over-plate cloth retention. Initial 512 views produced 52 failures. A larger-offset trial on formal shirt still failed 5/128 views. All four categories remain unmapped; the threshold was not lowered, body masks were not expanded, and their draft builder/test were moved into ignored work. Evidence remains in `outputs/human-wardrobe50/rejected-middle/` and `work/human-wardrobe50/`.

Leather shorts, tiger short pants and modern jester shoes (four graphics) were also left unmapped because the available prototype cuts were inaccurate. The earlier full/half apron experiments remain unmapped. None of these rejected graphics contributed to 572.

## Review and reproduce

`outputs/human-wardrobe50/index.html` contains **424 actual Godot frames** and eight walking/riding sheets, with male/female figures and front/rear views. Search by garment name or native graphic. Rejected categories are absent from the gallery and registry.

After preparing the existing pinned human/horse foundations:

```powershell
./scripts/prepare-human-wardrobe50.ps1 -Gpu -Review
./scripts/build-human-catalogue.ps1 -NoOpen
./scripts/verify.ps1
```

Use `-VerifyOnly` to skip generation while retaining source/export/runtime checks. `python -B scripts/review-human-wardrobe50.py` builds the optional sheets/gallery with a Pillow-enabled Python runtime (the bundled Codex Python has Pillow). The full `prepare-human-coverage.ps1` pipeline invokes this batch after the previous builders. The normal headless verification includes the new native layer/resource checks when these assets are installed.

## Remaining work

Robes, gowns and kimono currently share fitted garment silhouettes; skirts, armour and footwear also reuse traced source shapes. Exact neckline/sleeve/hem changes, ornaments, dye masks, fur strands, complex weapon effects, support-hand/dual-wield choreography and final material/art approval remain separate. Animated props, opening books, strings/projectiles and cloth simulation are not added here. The existing catalogue still records per-item/action fidelity as pending.

Next useful work is proper apron/middle-garment construction over armour, accurate shorts/shoes and masks from better source geometry, then remaining natural hairstyles and targeted clothing refinements. Maintain the distinction between usable family geometry, per-item fidelity and server eligibility.

## Accepted additions

| Category | Native graphics | Geometry basis |
|---|---|---|
| fur_cape | `0x2309`, `0x230A` | expansion/cloak |
| arcane_cloak | `0x26AD` | expansion/cloak |
| quarter_cloak | `0xA413` | expansion/cloak |
| arcane_gloves | `0x26B0` | expansion/gloves |
| valor_gauntlets | `0x2B0C`, `0x2B0D` | expansion/gloves |
| elven_female_plate | `0x2B6D`, `0x3164` | coverage/plate_torso |
| leaf_female_chest | `0x3181`, `0x2FCB` | coverage/leather_torso |
| dark_shirt | `0x3176` | expansion/shirt |
| fur_sarong | `0x230B`, `0x230C` | expansion/skirt + independent riding fit |
| hakama | `0x279A`, `0x27E5` | expansion/skirt + independent riding fit |
| knee_skirt | `0x25F2`, `0x25F3` | expansion/skirt + independent riding fit |
| leather_skirt | `0x1C08`, `0x1C09` | expansion/skirt + independent riding fit |
| tattsuke_hakama | `0x279B`, `0x27E6` | runtime/part-pants |
| fancy_dress | `0x1EFF`, `0x1F00`, `0x267B`, `0x267C`, `0x267D`, `0x267E` | runtime/part-robe + independent riding fit |
| plain_dress | `0x1F01`, `0x1F02` | runtime/part-robe + independent riding fit |
| gilded_dress | `0x230D`, `0x230E` | runtime/part-robe + independent riding fit |
| hakama_shita | `0x279C`, `0x27E7` | runtime/part-robe + independent riding fit |
| male_kimono | `0x2782`, `0x27CD` | runtime/part-robe + independent riding fit |
| female_kimono | `0x2783`, `0x27CE` | runtime/part-robe + independent riding fit |
| kamishimo | `0x2799`, `0x27E4` | runtime/part-robe + independent riding fit |
| male_elven_robe | `0x2FB9`, `0x3173` | runtime/part-robe + independent riding fit |
| arcane_robe | `0x26AE` | runtime/part-robe + independent riding fit |
| veteran_robe | `0x25EC`, `0x25ED` | runtime/part-robe + independent riding fit |
| gm_robe | `0x204F` | runtime/part-robe + independent riding fit |
| british_suit | `0x2042` | runtime/part-robe + independent riding fit |
| blackthorne_suit | `0x2043` | runtime/part-robe + independent riding fit |
| dupre_suit | `0x2050` | runtime/part-robe + independent riding fit |
| fur_boots | `0x2307`, `0x2308` | runtime/part-boots |
| arcane_boots | `0x26AF` | runtime/part-boots |
| samurai_tabi | `0x2796`, `0x27E1` | expansion/shoes |
| ninja_tabi | `0x2797`, `0x27E2` | runtime/part-boots |
| samurai_helm | `0x236C`, `0x236D`, `0x268D`, `0x268E` | Original parametric kabuto |
| leather_cap_legacy | `0x2691`, `0x2692` | Original parametric leather_cap |
| spirituality_helm | `0x2B10`, `0x2B11` | Original parametric winged |
| elven_spectacles | `0x2FB8` | Original parametric spectacles |
| plate_mempo | `0x2779`, `0x27C4` | Original parametric mempo_steel |
| leather_mempo | `0x277A`, `0x27C5` | Original parametric mempo_leather |
| studded_mempo | `0x279D`, `0x27E8` | Original parametric mempo_studded |
| ninja_belt | `0x2790`, `0x27DB`, `0xAF05` | Original parametric belt_leather |
| obi | `0x27A0`, `0x27EB` | Original parametric belt_brocade |
| hip_quiver | `0x2FB7`, `0x3171`, `0x2B02`, `0x2B03` | Original parametric quiver |
| totem_charm | `0x2F58`, `0x2F59`, `0x2F5A`, `0x2F5B` | Original parametric talisman |
| bone_machete | `0x020E` | Original parametric cleaver |
| hatchet | `0x0F43`, `0x0F44` | Original parametric hatchet |
| crescent_blade | `0x26C1`, `0x26CB` | Original parametric crescent |
| dupre_shield | `0x2B01` | coverage/heater_shield |
| candle_holder | `0x0A28` | Original parametric candle |
| candle_holder_lit | `0x0A0F`, `0x0A10`, `0x0A11` | Original parametric candle |
| torch_unlit | `0x0F6B`, `0x0F64` | Original parametric torch |
| torch_burning | `0x0A12`, `0x0A13`, `0x0A14` | Original parametric torch |
| lantern_variants | `0x0A16`, `0x0A23`, `0x0A24` | coverage/lantern |
| chef_hat | `0x781A` | Original parametric chef |
| wedding_tophat | `0x9EF9`, `0x9EFA` | Original parametric tophat |
| haunted_tophat | `0x9F47`, `0x9F48` | Original parametric haunted_hat |
| holiday_hat | `0xA28F`, `0xA290` | Original parametric holiday |
| pumpkin_helm | `0xA3EA` | Original parametric pumpkin |
| assassin_hood | `0xA410` | Original parametric hood |
| mage_hood | `0xA411` | Original parametric hood_mage |
| turtle_helm | `0x782D` | Original parametric turtle_helm |
| anniversary_robe | `0x4B9D`, `0x4B9E` | runtime/part-robe + independent riding fit |
| battleground_robe | `0x7816` | runtime/part-robe + independent riding fit |
| red_dress | `0x781E` | runtime/part-robe + independent riding fit |
| ceremony_dress | `0x7821` | runtime/part-robe + independent riding fit |
| wedding_dress | `0x9EEF`, `0x9EF0` | runtime/part-robe + independent riding fit |
| store_robe_1 | `0xA0AB` | runtime/part-robe + independent riding fit |
| store_robe_2 | `0xA0AC` | runtime/part-robe + independent riding fit |
| store_robe_3 | `0xA0AD` | runtime/part-robe + independent riding fit |
| store_robe_4 | `0xA0AE` | runtime/part-robe + independent riding fit |
| store_robe_5 | `0xA0AF` | runtime/part-robe + independent riding fit |
| tabard | `0xA412` | runtime/part-robe + independent riding fit |
| wedding_pants | `0x9EF7`, `0x9EF8` | runtime/part-pants |
| tiger_long_pants | `0x7824` | runtime/part-pants |
| turtle_pants | `0x782C` | runtime/part-pants |
| tiger_long_skirt | `0x7826` | expansion/skirt + independent riding fit |
| tiger_short_skirt | `0x7827` | expansion/kilt + independent riding fit |
| pattern_kilt_1 | `0x781B` | expansion/kilt + independent riding fit |
| pattern_kilt_2 | `0x781C` | expansion/kilt + independent riding fit |
| pattern_kilt_3 | `0x781D` | expansion/kilt + independent riding fit |
| tiger_cuirass | `0x7822`, `0x7823` | coverage/plate_torso |
| turtle_cuirass | `0x782A`, `0x782B` | coverage/plate_torso |
| turtle_bracers | `0x782E` | coverage/plate_arms |
| tiger_collar | `0x7829` | coverage/plate_gorget |
| holiday_boots | `0xA28D`, `0xA28E` | runtime/part-boots |
| first_aid_belt | `0xA1F6` | Original parametric belt_aid |
| mace_belt | `0xA40C` | Original parametric belt_mace |
| sword_belt | `0xA40D` | Original parametric belt_sword |
| dagger_belt | `0xA40E` | Original parametric belt_dagger |
| demon_belt | `0xA7E2` | Original parametric belt_demon |
| ornate_mempo | `0xA40F` | Original parametric mempo_steel |
| vice_shield | `0x7817` | coverage/heater_shield |
| virtue_shield | `0x7818` | coverage/heater_shield |
| pirate_shield | `0xA649`, `0xA64A` | coverage/round_shield |
| hildebrandt_shield | `0xA831`, `0xA832` | coverage/heater_shield |
| skull_sword | `0xA341`, `0xA342` | Original parametric skull_sword |
| skull_staff | `0xA343`, `0xA344` | Original parametric skull_staff |
| bottle_weapon | `0xA40B`, `0xAF2D` | Original parametric bottle |
| modern_wand | `0xA767`, `0xA768` | Original parametric wand |
| held_orb | `0xA772` | Original parametric orb |
| candy_staff_red | `0xA7C3` | Original parametric candy_staff |
| candy_staff_green | `0xA7C4` | Original parametric candy_staff |
| red_lantern | `0x40FE` | coverage/lantern_lit |
| blue_lantern | `0x40FF` | coverage/lantern_lit |
| green_lantern | `0x4100` | coverage/lantern_lit |
| purple_lantern | `0x4101` | coverage/lantern_lit |
| modern_lantern_lit | `0xA769` | coverage/lantern_lit |
| modern_lantern_off | `0xA76A` | coverage/lantern |
