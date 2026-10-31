# Five free equipment substitutes and human material pass

The owner requested broader free replacements for UO wearables, an actual four/five-piece trial, and a less cartoony human through textures/shaders. Five CC0 pieces have been fitted and animated on the fixed MakeHuman-derived base: a mail tunic, trousers, leather boots, monk robe and hood. Combined Viking and monk configurations are also reviewed. The default live Avatar, server, source UO installation and original Documents/Codex prototype are unchanged.

## Sources and concrete substitutions

All five come from the official [MakeHuman suits02 CC0 pack](https://static.makehumancommunity.org/assets/assetpacks/suits02.html). RehmanPolanski authored the Viking items; Donitz authored the robe/hood. Their mhclo headers state CC0, and the pack catalog independently marks every selected item CC0. Each item includes its original mesh, atlas and fitting references. Exact archives, selected-file SHA-256 values, catalog hashes and a pinned CC0 hm08 base.obj revision are in scripts/download-free-equipment.py and local download-manifest.json. Only static data is downloaded; no downloaded scripts or installers are executed.

| UO role | Selected free piece | Mesh triangles | Current evidence |
|---|---|---:|---|
| Chain shirt / tunic | rehmanpolanski_viking_tunic | 6,568 | Individually and layered over trousers/boots |
| Long trousers | rehmanpolanski_viking_pants | 2,544 | Individually and under tunic/boots |
| Boots | rehmanpolanski_viking_boots | 6,320 | Individually and over trousers |
| Robe with cowl down | donitz_monk_robe | 19,820 | Individually and with separate hood |
| Raised-cowl component | donitz_monk_robe_hood | 9,008 | Individually and over robe |

These are semantic substitutes, not exact recreations or native-item-ID mappings. The hood is a composable component for a cowl-up robe, not proof of another distinct server equipment layer. Local source examples include H_MALE_Armor_Chain_Shirt_LOD2, H_MALE_pants_long_LOD2, H_MALE_Boots_LOD2 and H_MALE_Robe_CowlUp/cowldown_LOD2. Full original names/inventory remain in ignored outputs/third-dawn.

## How far free libraries cover the whole wardrobe

The preserved Third Dawn archive contains 370 Others GRN records. Collapsing sex/LOD prefixes gives 143 distinct human-prefixed model names (clothing, armour and accessories); this is not a count of modern server item graphics and does not establish full current-UO coverage.

| Family | Free source evidence | Status |
|---|---|---|
| Ordinary cloth, mail-like tunic, trousers, boots, robes, cowls | MakeHuman suits02 | The five pieces above were actually fitted and sampled |
| Additional everyday clothes, hats, dresses, hair and skin | MakeHuman official catalogs | Available candidates; not all downloaded/fitted |
| Ranger/leather/peasant modular parts | Quaternius Modular Character Outfits Fantasy Standard | Existing free CC0 parts are available in the project; this pass does not certify their fit on the new body |
| Swords, daggers and clubs | [Quaternius uploader's CC0 medieval weapons](https://opengameart.org/content/low-poly-medieval-weapons) | Source/license checked; weapon attachment not tested here |
| Exact bone/dragon armour, Japanese armour, rare artifacts, race/gender-specific variations and every layer combination | No complete audited free match set | Still gaps requiring individual selection, modification or original art |

[Quaternius's pack page](https://quaternius.com/packs/modularcharacteroutfitsfantasy.html) distinguishes the free Standard subset from the full Source kit; paid-only content is not counted as free coverage. Many broad categories look feasible, but an all-items replacement claim would be unsupported. Shape consistency, license checks, slots, body masks and in-motion fit matter as much as finding a free download.

## Import and fitting method

The new clothing pipeline uses the CC0 hm08 topology, not the UO garment mesh. UV identities recover all 13,380 original body vertices from the baked glTF's 14,517 seam-split vertices, with maximum UV residual about 7.1e-6. Authored mhclo barycentric references/offsets fit each garment to that exact body; target skin weights are interpolated, pruned to four and normalized. Four pieces use only recovered body references. Boots use 369 tights-helper references, approximated from the nearest three physical-body displacement/weight samples; that approximation remains a fit-review point.

Small inside/near-body surface corrections supplement the authored fit (maxima: tunic ~25 mm, trousers ~3.3 mm, boots ~6.7 mm, robe ~59 mm, hood ~13 mm). Existing author delete groups plus explicit fixed-body sleeve/leg/foot masks remove hidden body faces. Covered briefs and hood-covered hair are omitted. Boots receive a 13 mm visual sole-height offset. The long robe's lower weights fade toward the pelvis and its rest hem is shortened to a minimum 85 mm reference clearance so sampled running does not drag it through the floor. This is a practical skinned-skirt fit, not cloth simulation. Extreme poses and collisions still need review.

## Skin and shader changes

The [official skins02 CC0 pack](https://static.makehumancommunity.org/assets/assetpacks/skins02.html) supplies Mindfront's aksel_skin: matching 2048-square diffuse, tangent normal and specular maps. Its catalog says CC0. These replace the previous unmatched/generated micro-normal combination. FreeHumanSkin.gdshader uses the supplied normal, varying roughness estimated from the legacy specular map, dielectric highlights and modest Forward+ subsurface scattering (Compatibility retains the remaining material features). Eye/cornea roughness/specular/opacity are toned down; hair uses subdued anisotropic highlights, and strong eyelash cards are hidden on the new treatment. Mipmaps/filtering are set reproducibly by the review launcher. The studio uses AgX tone mapping for both sides of the comparison.

The body geometry was not sculpted again: independent exported-position comparison finds at most 5.96e-7 m floating-point round-trip difference. Same pose and lighting are used for the before/after view. The maps are authored materials, not a claim of calibrated scanned skin. Face proportions and the hair silhouette remain stylized; textures and shaders alone do not establish photorealism.

## Verification

- Four source-free OBJ/proxy boundary tests and ten prior source-free importer/refinement tests pass.
- All eight actual GLBs pass finite-position, normalized-weight, bone-index and matching-animation inspection. They retain the shared 53-bone rest layout (max numeric difference 2.39e-7); no new body geometry or UO bones are introduced.
- Both renderers sample nine actors at four phases of Idle/Walk/Run: 108 actor samples and 120 worn-piece samples per renderer. Roots stay stationary; finite deformation, source-run aerial phase, grounding and garment bounds pass. Bounds are not proof of clipping freedom. Fresh complete-outfit, individual-piece, walking/running and skin-comparison screenshots were inspected.
- Actual GPU probes confirm normal-map, roughness and light-direction responses while holding body geometry/pose fixed. Forward+: 0.000989 / 0.001295 / 0.020892 mean RGB differences; Compatibility: 0.001390 / 0.001789 / 0.033832. All exceed the fixed 0.000005 signal threshold. See free-equipment-gpu-*.json.
- The required full project verification passes (exit 0); its log is outputs/third-dawn/free-equipment-full-verify.log.

Detailed source/license records are local work/free-equipment/licence-evidence.json. Export/fit hashes and counts are Viewer/local-art/free-equipment/provenance.json. Independent results are outputs/third-dawn/free-equipment-asset-validation.json, free-equipment-forward-validation.json, free-equipment-compatibility-validation.json and free-equipment-review-evidence.json. Binaries, downloaded inputs and captures remain ignored/local; no publication occurred.

## Reproduce and review

1. python scripts/download-free-human.py (existing pinned CC0 base inputs).
2. Blender -b --factory-startup --python scripts/fit-uo-to-free-human.py -- --base-only (builds only the CC0 base; this mode reads no UO input).
3. python scripts/download-free-equipment.py (or --verify-only).
4. Blender -b --factory-startup --python scripts/prepare-free-equipment.py.
5. python scripts/validate-free-equipment.py; python scripts/test-mhclo.py.
6. Reviews/Review-Free-Equipment.cmd. The UI switches among complete outfits, all five pieces, skin comparison and head close-up, with Idle/Walk/Run and front/three-quarter/profile controls.

Blender is the existing .tools/blender/blender-5.2.1-windows-x64/blender.exe. Equivalent direct review: ./scripts/review-third-dawn.ps1 -Equipment -Human -View clothing; add -View parts, -View bust, -Compatibility, -Validate or -MaterialTest PATH as needed. Each display variant contains a self-contained rig; production dynamic layer swapping, current-server item mapping, all body sliders, full wardrobe coverage, cloth physics, NPC performance/LODs and mobile hardware validation remain future work.
# Follow-up: robe motion and natural skin

The owner's next review found missing leg sections and rejected the blotchy Aksel appearance. The subsequent pass is documented in CHARACTER_FOUNDATION_POLISH.md and planned integration in CHARACTER_SYSTEM_PLAN.md. It retains the legs, adds eight skirt controls (61 total bones with 53 native bones), and uses cleaner CC0 system skin presets. The earlier 53-bone/material results below remain historical evidence for the initial trial.
