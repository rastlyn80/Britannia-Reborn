# Human wearable 65% batch

Target: at least **732/1,126 indexed graphics**, using the unchanged denominator. Starting point: 572/1,126 (50.80%). This measures fitted category replacements; exact original cuts/ornament, item-specific action fidelity and active server eligibility remain separate.

Plan:

1. Audit missing player/NPC equipment against the pinned local catalogue and ModernUO class ancestry. Keep race-restricted equipment and earlier rejected prototypes unmapped.
2. Connect historical clothing/weapon variants to complete traced fitted meshes on both bodies. Add small original accessories without importing proprietary game artwork.
3. Validate hashes, complete derivative topology/materials/named weights, native hue and identity, rendered walking/running/riding, armour opacity, hair depth and actual source-file selection. Review real engine frames; reject failed candidates.
4. Rebuild the catalogue, run `scripts/verify.ps1`, record actual evidence and remaining gaps, then commit/push only this batch's code and documentation.

Packaging is a separate unfinished milestone: a Git clone currently does not include these ignored generated character assets. A versioned redistributable character pack and clean-install test are still needed before a playable download reproduces the local wardrobe automatically.

## Implemented scope

The local catalogue now resolves **732/1,126 indexed graphics (65.0089%)**, up by **160**, across **351 registered categories** (+93). Final finite GPU acceptance passed. Every model/body/mount group has a nontrivial rendered projection: the minimum best-view footprint is 33 pixels across 372 groups. The denominator remains unchanged. This is category mapping coverage, not a percentage of distinct finished designs, gameplay or animation fidelity.

The additions are **curated indexed wearable variants**, mostly historical player/NPC clothing, armour, weapons, books and talismans. No new active ModernUO item-class eligibility is certified by this batch. The independent audit rereads the wearable flag, layer, name and animation number from hash-pinned local `tiledata.mul`. Of the 160 animation references, **103** have an EQUIPMENT row, **9** a HUMAN row, **16** a MONSTER row and **32** no `mobtypes.txt` row (including 18 zero animation numbers). Those labels are reported, not interpreted as proof that the current server equips these graphics. Server body/item/hue authority remains unchanged; no monster bodies or server classes were added.

Historical names are not new creature support: for example, the indexed ogre club has a fitted human held-prop replacement; no ogre actor was implemented. Exact historical or current-game cut/ornament and individual attack choreography remain separate. Existing action coverage stays 35/35 classic, 28/28 on foot and 7/7 ordinary-horse rider groups.

## Construction and sources

There are **198 new local exports**: 93 base category models per body plus six independent riding variants per body. **184** are complete fitted-source derivatives/assemblies; **14** are original small parametric accessories (headband, crook, necklaces and coiled whips). Shared silhouettes and materials are intentional category reuse, not claims of 93 distinct finished art designs.

The six new outer garments include a continuous fitted inner shirt using matching outer cloth. Their source topology and named weights are retained, with **12 mm front / 6 mm rear** outer depth clearance and **2 mm inward** lining clearance. The runtime omits the duplicate generic undercoat only for these registered composites. No new body masks are introduced. This addressed the severe inner-shirt/trouser overlap seen during riding review; finite views are not a universal collision proof, and small visual refinements remain.

Source metadata and input/export SHA-256 hashes are in `scripts/human-wardrobe65-inputs.json` and ignored per-body `coverage/provenance.json`. An attribution-only manifest correction was applied after generation; all 198 mesh byte hashes stayed unchanged and the complete source audit was rerun. The independent audit checks 61 matching inverse binds, normalized named weights, finite geometry/normals, opaque materials and every source triangle. Assembly clearance is explicitly accounted for; residual export error is below **0.001 mm** (maximum observed 7.75e-7 m), within the 2-micrometre float32 tolerance. The lining receives matching cloth materials; other derivatives retain their fitted source materials.

Sources are the already pinned foundations, with no new downloads:

- Selected [MakeHuman CC0 packs](https://static.makehumancommunity.org/assets/assetpacks.html) and the pinned [CharacterCreator foundation](https://github.com/kblood/CharacterCreator/tree/852e48f316b90a0937234886630e4fb4cdfd1f78); exact authors/files/hashes in `scripts/character-expansion-inputs.json` and existing human manifests.
- CC-BY-4.0 fitted Objaverse/Sketchfab weapon and shield art, including the axe, bardiche and halberd families. Exact source URLs, authors, modifications, source/output hashes and notices remain in `scripts/human-coverage-inputs.json` and `Viewer/Art/Objaverse/`. These derivatives retain that attribution; they are not relabelled CC0.
- Existing ambientCG fabric inputs via `Viewer/Art/MedievalKit/NOTICE.md` and the previous 50%/frontier manifests. New original parametric geometry and generator code are GPL-3.0-or-later.
- Pinned ModernUO `ab59efea86fd9e399d261bed9d188ab4d95ad4c2` was inspected read-only; its source is not copied into this batch.

No proprietary UO mesh, texture or animation frame is exported. Generated art, local original-data catalogues, screenshots and failure evidence remain ignored. Asset-pack distribution/clean-install automation is still unfinished; committing generators is not a complete playable-client distribution.

## Evidence

| Check | Result |
|---|---|
| Source/native metadata, bind and complete triangle audit | 160 graphics / 198 exports, 0 failures |
| All accepted base coverage exports | 666 exports, 0 failures |
| Native layers, cosmetic independence and real resource/lining selection | 816 checks, 0 failures |
| Final native/grip/pose GPU checks | **19,664 checks / 5,952 views, 0 failures** |
| Final opacity/seat stress views | **1,664 views, 0 failures** |
| Final depth-tested long hair/ponytail views | **864 views, 0 failures** |
| Total new finite rendered views | **8,480** |
| Full `scripts/verify.ps1` | **Exit 0**; 1,759 human coverage checks, 816 new layer checks, 2,468 horse checks / 768 contact poses, completes through VIEWER PASS |

The full suite still emits existing TimberBridge fixture missing-`id` errors, Unicode parsing diagnostics, teardown/RID/resource warnings and PreviewTools nullable warnings. It is not diagnostic-clean. No login/protocol code changed and no new live-login, world-entry or multiplayer claim is made.

## Rejected and remaining work

The draft backpack (0x0E75/0x09B2) was rejected: the first hair test had **16 failures in 896 views**, with long-hair retention as low as about 88% in initial walking/running samples. It is absent from the accepted registry and gallery. Failure evidence and its original geometry draft are in ignored `outputs/human-wardrobe65/rejected-backpack/` and `work/`. Thresholds were not weakened. Previously rejected masks/veil, shorts/shoes, apron and middle-over-plate experiments remain unmapped.

Coiled whips currently use shared held-weapon locomotion/actions; dynamic lashes, per-whip combat and effects remain pending. Robes/kimono, harnesses, old shirt variants, waraji, armour and books share fitted category silhouettes; exact cuts, patterns, ornaments and arbitrary outfit/action combinations are not certified. Hair has finite rear visibility evidence, not strand simulation. Remaining work includes accurate middle/apron construction, the backpack/hair fit, precise missing hair/masks/shorts/shoes and a separately versioned distributable character pack with a clean-install test.

## Reproduce and review

After preparing the existing pinned licensed human/horse foundations:

```powershell
./scripts/prepare-human-wardrobe65.ps1 -Gpu -Review
./scripts/build-human-catalogue.ps1 -NoOpen
./scripts/verify.ps1
```

`-VerifyOnly` skips Blender generation while retaining source/export/native-layer checks. The full coverage preparation pipeline invokes the 65% builder after the 50% builder. A fresh machine still needs the pinned inputs; this session does not certify a clean-room asset bootstrap.

With Pillow installed, `python -B scripts/review-human-wardrobe65.py` builds eight contact sheets and a searchable `outputs/human-wardrobe65/index.html` from **372 completed engine frames** (male/female, walking/riding, front/rear). Frames show actual engine resources and the revised integrated linings. Review images and mesh inputs are local artifacts, not committed game artwork.

## Accepted category mappings

| Category | Indexed graphics | Fitted basis |
|---|---|---|

| legacy_daemon_sword | `0x2554` | coverage/rune_blade |
| legacy_ettin_hammer | `0x2555` | coverage/smith_hammer |
| legacy_liche_staff | `0x2556` | coverage/skull_staff |
| legacy_lizard_mace | `0x2557` | coverage/mace |
| legacy_lizard_spear | `0x2558` | coverage/spear |
| legacy_ogre_club | `0x2559` | coverage/club |
| legacy_ophidian_staff | `0x255A` | coverage/wild_staff |
| legacy_ophidian_bardiche | `0x255B` | coverage/bardiche |
| legacy_orc_club | `0x255C` | coverage/club |
| legacy_ratman_axe | `0x255D` | coverage/hatchet |
| legacy_ratman_sword | `0x255E` | coverage/long_sword |
| legacy_skeleton_axe | `0x255F` | coverage/battle_axe |
| legacy_skeleton_scimitar | `0x2560` | coverage/scimitar |
| legacy_terathan_staff | `0x2561` | coverage/wild_staff |
| legacy_terathan_spear | `0x2562` | coverage/spear |
| legacy_terathan_mace | `0x2563` | coverage/mace |
| legacy_troll_axe | `0x2564` | coverage/double_axe |
| legacy_troll_maul | `0x2565` | coverage/war_mace |
| legacy_frost_club | `0x2566` | coverage/club |
| legacy_orc_lord_axe | `0x2567` | coverage/battle_axe |
| legacy_orc_mage_staff | `0x2568` | coverage/skull_staff |
| legacy_bone_mage_staff | `0x2569` | coverage/skull_staff |
| legacy_scale_shield | `0x256A` | coverage/round_shield |
| legacy_magic_staff | `0x256B`, `0x256C`, `0x256D`, `0x256E` | coverage/wild_staff |
| legacy_smith_hammer | `0x256F` | coverage/smith_hammer |
| legacy_hatchet | `0x2570` | coverage/hatchet |
| legacy_javelin | `0x2572` | coverage/short_spear |
| legacy_magic_sword | `0x2573`, `0x2574`, `0x2575`, `0x2576` | coverage/rune_blade |
| legacy_naginata | `0x2577` | coverage/halberd |
| legacy_no_dachi | `0x2578` | coverage/no_dachi |
| legacy_pick | `0x2579` | coverage/pickaxe |
| legacy_spear | `0x257A`, `0x257B` | coverage/spear |
| legacy_sword | `0x257C` | coverage/long_sword |
| legacy_longsword | `0x257D` | coverage/long_sword |
| legacy_shortsword | `0x257E` | coverage/wakizashi |
| legacy_war_mace | `0x257F` | coverage/war_mace |
| paladin_sword | `0x26CE`, `0x26CF` | coverage/rune_blade |
| book_of_arms | `0x2254` | coverage/chivalry_book |
| bard_book | `0x225A`, `0x225B` | coverage/spellbook |
| legacy_jester_cap | `0x172E` | coverage/jester_hat |
| legacy_winged_helm | `0x2689`, `0x268A` | coverage/spirituality_helm |
| legacy_kabuto_mempo | `0x268F`, `0x2690` | coverage/plate_mempo |
| legacy_ninja_mask | `0x26A3`, `0x26A4` | coverage/ninja_hood |
| legacy_robin_cap | `0x269D`, `0x269E` | coverage/feathered_hat |
| legacy_jester_pants | `0x2649`, `0x264A` | coverage/wedding_pants |
| legacy_ninja_pants | `0x2651`, `0x2652` | coverage/ninja_pants |
| legacy_checkered_shirt | `0x25EA`, `0x25EB` | coverage/dark_shirt |
| legacy_robe | `0x25EE`, `0x25EF` | coverage/veteran_robe |
| legacy_death_shroud | `0x25F0`, `0x25F1`, `0x2685`, `0x2686` | coverage/gm_robe |
| legacy_amazon_armour | `0x2659`, `0x265A`, `0x265B`, `0x265C`, `0x265D`, `0x265E` | coverage/leather_torso |
| legacy_amazon_harness | `0x25E6`, `0x25E7` | coverage/leather_torso |
| legacy_elite_harness | `0x25E8`, `0x25E9` | coverage/studded_torso |
| legacy_cloth_shirt | `0x265F`, `0x2660`, `0x2661`, `0x2662`, `0x2663`, `0x2664`, `0x2665`, `0x2666` | coverage/dark_shirt |
| legacy_ninja_shirt | `0x2667`, `0x2668` | coverage/cloth_ninja_jacket |
| legacy_kote_sleeves | `0x266B`, `0x266C`, `0x266D`, `0x266E` | coverage/plate_hiro_sode |
| legacy_do_maru | `0x2671`, `0x2672` | coverage/plate_do |
| legacy_haramaki | `0x2673` | coverage/studded_do |
| legacy_haramaki_arms | `0x2674` | coverage/studded_hiro_sode |
| legacy_kote_gloves | `0x2677`, `0x2678`, `0x2679`, `0x267A` | coverage/dragon_hands |
| legacy_plate_gorget | `0x264B`, `0x264C` | coverage/plate_gorget |
| legacy_haidate | `0x264D`, `0x264E` | coverage/plate_haidate |
| legacy_kobakama | `0x264F`, `0x2650` | coverage/tattsuke_hakama |
| legacy_long_dress | `0x267F`, `0x2680` | coverage/plain_dress |
| legacy_kimono | `0x2681`, `0x2682` | coverage/male_kimono |
| legacy_male_kimono_dress | `0x279E`, `0x27E9` | coverage/male_kimono |
| legacy_female_kimono_dress | `0x279F`, `0x27EA` | coverage/female_kimono |
| legacy_waraji | `0x2653`, `0x2654` | coverage/samurai_tabi |
| tall_tabi | `0x2795`, `0x27E0` | coverage/ninja_tabi |
| mail_haidate | `0x278C`, `0x27D7` | coverage/mail_legs |
| virtue_cape | `0x2B04`, `0x2B05` | coverage/arcane_cloak |
| virtue_legs | `0x2B06`, `0x2B07` | coverage/plate_legs |
| virtue_torso | `0x2B08`, `0x2B09` | coverage/plate_torso |
| virtue_arms | `0x2B0A`, `0x2B0B` | coverage/plate_arms |
| virtue_gorget | `0x2B0E`, `0x2B0F`, `0x3BB5` | coverage/plate_gorget |
| virtue_boots | `0x2B12`, `0x2B13` | coverage/arcane_boots |
| female_shirt_variants | `0x3177`, `0x3178` | coverage/dark_shirt |
| tuxedo_shirt | `0x9EFB`, `0x9EFC` | coverage/dark_shirt |
| legacy_talisman | `0x1096` | coverage/totem_charm |
| tailoring_talisman | `0x9E25` | coverage/totem_charm |
| alchemy_talisman | `0x9E26` | coverage/totem_charm |
| cooking_talisman | `0x9E27` | coverage/totem_charm |
| inscription_talisman | `0x9E28` | coverage/totem_charm |
| fletching_talisman | `0x9E29` | coverage/totem_charm |
| blacksmithing_talisman | `0x9E2A` | coverage/totem_charm |
| tinkering_talisman | `0x9E2B` | coverage/totem_charm |
| carpentry_talisman | `0x9E2C` | coverage/totem_charm |
| hachimaki | `0x268B`, `0x268C` | original headband |
| shepherd_crook | `0x13F4`, `0x13F5` | original crook |
| fellowship_medallion | `0xA429`, `0xA42A` | original medallion |
| octopus_necklace | `0xA349` | original octopus |
| barbed_whip | `0xA289`, `0xA28A`, `0xA28B`, `0xA291` | original whip_barbed |
| spiked_whip | `0xA292` | original whip_spiked |
| bladed_whip | `0xA293` | original whip_bladed |
