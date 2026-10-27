# Male body refresh, refinement and first wardrobe

Latest material-focused pass (original geometry, generated normal atlas,
shader correction and GPU validation): see [THIRD_DAWN_SKIN.md](THIRD_DAWN_SKIN.md).
The subdivision comparisons below are retained historical research.

27 October 2026. Local presentation experiment in the existing Godot Viewer.
No default Avatar, live login, server simulation or saved-account changes.

## Review

Open `Review-Third-Dawn-Human.cmd`. Five variants are available: original base,
AI texture + skin shader, subdivided base with the same new material, chain shirt
and cowl-down robe. Base/clothing close-up buttons isolate three relevant
variants; All restores five. Idle/Walk/Run, pause, RMB orbit and wheel zoom work.
The base retains its source briefs; no anatomical geometry was added.

```powershell
python scripts/import-third-dawn.py --archive work/third-dawn/uotdb.zip
# Supply the locally generated human-modern-albedo.png first; it is not public.
python scripts/prepare-third-dawn-human.py --archive work/third-dawn/uotdb.zip
python scripts/test-third-dawn.py
./scripts/review-third-dawn.ps1 -Human -Validate -View base -Screenshot outputs/third-dawn/human-subdivision.png
./scripts/review-third-dawn.ps1 -Human -Validate -Compatibility -View clothing -Clip Run -Screenshot outputs/third-dawn/human-smoothed-clothing.png
./scripts/review-third-dawn.ps1 -Human -View base -Rear -Screenshot outputs/third-dawn/human-rear.png
./scripts/verify.ps1
```

Original inspection/source hashes: THIRD_DAWN_IMPORT.md. Archive SHA-256:
`d872d59a4d3f92c82672bbadb98ae44772e42b44dacb4a28a1fdf39cf121dc0e`.
Preservation source: `https://zuluarchive.com/static/files/uotdb.zip`.

## Materials and geometry

The original 256×256 neutral atlas was edited with built-in image generation to
a 1254×1254 warm-skin atlas. Preserving normalized UV island layout was an
explicit prompt constraint. Front/rear views were inspected on the animated
model; exact pixel-level island identity is not guaranteed by generation.
The result still has noticeable painted shading; it is not a measured PBR scan.
The shared shader adds roughness, restrained specular, procedural fine normal
variation and a small Forward+-only subsurface term. Compatibility omits that
term. Source and refreshed albedos remain separately available.

`scripts/third-dawn-subdivide.py` implements bounded Loop subdivision, separate
UV seams, normalized top-four skin-weight interpolation and area-weighted
normals. Shape displacement is capped from the linearly refined source cage.

| Mesh | Levels | Triangles before → after | Source-space movement cap |
|---|---:|---:|---:|
| Human body | 2 | 362 → 5,792 | 18 mm (~19 mm displayed) |
| Chain shirt | 1 | 106 → 424 | 9 mm |
| Robe | 1 | 210 → 840 | 9 mm |

Body geometric vertices increase from 183 to 2,898. Bones, UV islands and native
animations remain. Refinement softens the old cage; it does not reconstruct
missing face/hand anatomy. The old coarse assets are preserved for comparison.

## Clothing

Source files under `uotdb/uotd/Models/Others/`:
`H_MALE_Armor_Chain_Shirt_LOD2.grn` (13 weighted human bones) and
`H_MALE_Robe_cowldown_LOD2.grn` (15). Original garment textures are retained with
simple material settings; the robe has a blue tint. Their textures have not
received the AI body refresh.

Garments attach as mesh/skin instances to the human's existing Skeleton3D.
Named skin bindings are remapped from each garment skeleton, retaining its own
inverse binds. Unmatched unused attachment bones are tolerated only if no
vertex weights reference them. There is one animator, not separate clothing
animations. Prototype masks hide covered torso/limbs while retaining head,
open collars, hands and feet. Final refined masks hide 1,722 body triangles for
the shirt and 2,972 for the robe. These are explicit garment-specific rules, not
a universal wardrobe solver. Shirt and robe are separate review configurations;
arbitrary combinations and server-driven layering remain unimplemented.

## Verification and evidence

- Eight source-free tests pass: malformed chunks/TGA, coordinate transforms,
  body-mask exclusions, subdivision triangle growth, displacement cap, UV seams,
  unchanged skeleton and normalized skin weights.
- Engine validation passes five bodies × three clips × four phases (60 body
  poses), plus two garments (24 garment poses). Checks include finite bounds,
  changing joints, stationary entity roots, grounding and garment extent.
- Forward+ and Compatibility captures/validation pass. Front/rear base,
  shirt/robe idle and locomotion were visually inspected. This is not proof of
  clipping-free coverage for every animation frame or arbitrary pose.
- Full `scripts/verify.ps1` passes, including the actual-crop smoke load.

Evidence is ignored in `outputs/third-dawn/`: `human-subdivision.png`,
`human-smoothed-clothing.png`, `human-rear.png`, `human-validation.json`, renderer
logs and `human-full-verify.log`. `Viewer/local-art/third-dawn/` contains the
generated atlas, exact prompt, original-derived glTF and
`human-wardrobe-provenance.json` with source/output hashes, masks and limits.

No downloaded executable or proprietary Granny runtime is used. Source archive,
generated original-derived art, prompts and captures are private/ignored.
No redistribution grant is established. The Documents/Codex prototype and
existing UO installation remain unchanged.

## Next gates

Art review of face/hands and atlas seams; less painted lighting in the albedo;
more garments with explicit hide rules; hair, dyes, weapons and layer mapping;
terrain IK and opt-in live presentation. Arbitrary attacks/deaths, cloth
simulation and physically measured material maps are not implemented or claimed.
