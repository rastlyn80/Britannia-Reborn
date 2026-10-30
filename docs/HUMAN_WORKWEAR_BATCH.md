# Human body sash — 30 October 2026

The accepted addition is **body sash**, native graphics **0x1541 / 0x1542**, ModernUO **MiddleTorso (17)**. Both bodies have civilian and plate-fit versions. The catalogue is now **248/1,126 graphics (22.02%), 73 categories**. This adds two native graphics, not a new animation family. Existing 35/35 classic action routing, 28/28 on-foot groups and seven ordinary-horse rider groups remain unchanged.

## Construction and native appearance

The civilian sash copies the existing fitted CC0 shirt's outer topology and original weights. A binary cloth-outline texture trims the shape without creating differently weighted intersection vertices. The plate version follows the original rigid cuirass vertices and spine weights; it closes above the articulated faulds instead of crossing their overlapping waist surfaces. Fixed offsets are 20 mm / 28 mm. The body's vertices, UVs, 61 named joints and inverse binds remain unchanged. No body triangles were copied into clothing and no extra body-hiding masks were introduced.

The material is rough woven linen with restrained normal detail and a darker stitched edge. Default, full and partial native dyes retain the alpha outline and original roughness/metalness. Previously the non-cosmetic hue shader did not preserve alpha-scissor outlines. It now carries the original cutout flag/threshold; the cosmetic threshold remains 0.35.

The sash replaces tunic/doublet on its native middle layer, retaining an independently worn shirt or armour. An outer robe conceals it. Hair type/hue and item hue stay independent, including long hair and ponytail layering. Native player/NPC appearance uses the existing renderer; server state and gameplay are unchanged.

## Sources and licences

Exact consumed file hashes, source records and native references are in `scripts/human-workwear-inputs.json`.

- Selected MakeHuman foundation: [CharacterCreator revision 852e48f316b90a0937234886630e4fb4cdfd1f78](https://github.com/kblood/CharacterCreator/tree/852e48f316b90a0937234886630e4fb4cdfd1f78), CC0 art; no upstream application code imported.
- MargaretToigo's [Fisherman sweater](http://www.makehumancommunity.org/node/1187), CC0, from the pinned [shirts01 archive](https://files.makehumancommunity.org/asset_packs/shirts01/shirts01_cc0.zip). Exact archive/member hashes are retained in the manifest and `character-expansion-inputs.json`. Uses the already fitted local shirt, not a new download.
- Existing original Britannia Reborn manufactured cuirass geometry, traced through `human-armour.py` and `human-coverage-inputs.json`; original project work GPL-3.0-or-later.
- Existing CC0 `Linen_Color.jpg` and ambientCG `Fabric045_2K-JPG_NormalGL.jpg`, with hashes/notices in the manifest and `Viewer/Art/MedievalKit/NOTICE.md` / `CREDITS.md`.
- Original sash outline, stitch edge and fitting code: GPL-3.0-or-later. Generated assets and screenshots stay local and ignored.

Native IDs/layer follow ModernUO `MiddleTorso.cs` at the pinned `ab59efea86fd9e399d261bed9d188ab4d95ad4c2`. No proprietary UO art is used in the replacement mesh/material.

## Evidence and reproduction

- **304 runtime/GPU checks, 128 views, zero failures:** male/female, civilian/plate, on foot/riding, Walk/Run, two phases and four angles. Includes both native IDs, default/full/partial dye state, middle/robe layering, independent hair metadata and unchanged body-mask bits.
- Visibility probes retain the full body, opposite garment surfaces and sleeves. Only outward-facing sash surfaces are compared with the matching underlayer's facing torso removed. Back-facing underlayer surfaces and sleeve/clavicle regions remain occluders. At least 98% of reference pixels must remain, with a four-pixel raster-edge allowance; projections below 15 pixels are not treated as fit evidence. A far-side sash may naturally be hidden by its wearer. This is finite visible-surface evidence, not universal collision proof.
- **64 long-hair/ponytail views, zero failures:** both bodies, foot/riding, Walk/Run, two phases, sash and sash/cape. At least 98% of rear tail pixels retained against the same complete body with only the new sash hidden. Alpha masks remain active in the probe.
- **Four exports, 32 actual final-modifier poses:** exact input/output hashes, exported original weights, 61 unchanged inverse binds, alpha MASK materials, finite geometry and offsets bounded below 31 mm. The source-record validator accounts for Blender's uniform rig scale. Signed triangle orientation at existing folds is diagnostic, not a global inside/outside test; rendered retention is checked separately.
- **Eight actual completed Godot review frames**, front/rear on foot/riding, with both bodies and civilian/plate fits. Two sheets and a local gallery are generated from those frames.

```powershell
./scripts/prepare-human-workwear.ps1 -Gpu -Review
./scripts/build-human-catalogue.ps1 -NoOpen
./scripts/verify.ps1
```

`-VerifyOnly -Gpu -Review` reuses prepared meshes. The established full coverage preparation also builds the sash after its source clothing/plate exports. `review-human-workwear.py` assembles sheets with a Pillow-enabled Python. Local evidence is under `outputs/human-workwear/`: `gpu-validation.json`, `hair-validation.json`, `poses.json`, `asset-validation.json`, eight sash frames and `index.html`. Logs are `work/workwear-*.log`. No new live world-entry/multiplayer claim is made.

## Held back and next work

Full/half aprons remain **unmapped and uncounted**. Matched-shirt/trouser prototypes improved standing fits but retained waist/lap defects and failed the stricter walking/running/plate review. Rejected code, poses and renders are retained only in ignored `work/human-workwear` / `outputs/human-workwear`. Do not enable them or raise the catalogue count merely because a standing screenshot looks acceptable.

Next: a clean apron waist/lap construction, then surcoat/dresses and remaining armour/weapon families. The sash is a category replacement awaiting owner visual review; exact original ornament, other torso/outer-leg combinations, all attack/cast poses and arbitrary garments are not established by this finite batch. Other armour currently uses the plate envelope and needs combination-specific review. Mounted full porting and monster coverage remain separate work.
