Latest geometry refinement: see [THIRD_DAWN_ROUNDING.md](THIRD_DAWN_ROUNDING.md). Current review compares the same v2 material on original versus locally rounded geometry; material evidence below predates that change.

# Skin material pass v2 — 27 October 2026

The owner judged subdivision visually unhelpful and asked to prioritize shaders
and textures. The current human review therefore uses the original 362-triangle
body for both the prior material and PBR material v2. The shirt/robe comparison
also uses the original coarse garment configurations. Refined asset files are
retained locally as research, not deleted or used as the new default.

## What changed

- A separately generated OpenGL tangent-space normal atlas supplies approximate
  skin/anatomical/linen relief. It was generated from the existing UV atlas,
  with island preservation requested, then inspected on the animated model.
- Existing colour atlas is retained. A new colour-atlas generation was rejected
  by the image tool and no output from that attempt was saved or used.
- Bounded shader-based approximate de-lighting reduces broad painted contrast
  and the bronze cast. It uses a mip-level colour reference while retaining
  fine colour detail. This is not exact recovery of physically unlit albedo.
- Skin, face, palms and linen have different roughness/specular response. The
  normal strength is modest; a small subsurface term runs only in Forward+.
- A derivative-based tangent frame supports the original mesh, which lacks
  an authored tangent stream. Diffuse luminance is not embossed as height.
- Albedo and normal atlas imports now generate mipmaps; filtered procedural
  roughness detail fades with pixel footprint instead of shimmering.
- Previous shader is retained as ThirdDawnSkinLegacy.gdshader, so old/new are
  compared at the same pose, geometry, camera and lighting.

## Try it

Review-Third-Dawn-Human.cmd opens the review. Material close-up isolates prior
material and PBR v2. Skin detail and Skin sheen sliders affect only the new
material. Base/clothing/All views, pose buttons, pause and camera controls remain.

    ./scripts/review-third-dawn.ps1 -Human -View materials
    ./scripts/review-third-dawn.ps1 -Human -View materials -Light side -Clip Walk
    ./scripts/review-third-dawn.ps1 -Human -View materials -MaterialTest outputs/third-dawn/skin-gpu.json
    ./scripts/review-third-dawn.ps1 -Human -Compatibility -View materials -MaterialTest outputs/third-dawn/skin-gpu-gl.json

The generated normal atlas must exist locally as
Viewer/local-art/third-dawn/human-normal-v2.png. No automatic download or public
distribution of these proprietary-derived inputs is provided.

## Verification

Eight source-free importer/wardrobe tests pass. Both Forward+ and Compatibility
pass five bodies × three clips × four phases (60 body poses plus 24 garment
poses) on the original geometry. Walk under side light and clothed running
captures were inspected. Full scripts/verify.ps1 passes, including actual-crop
load. There were no live login/server/default-avatar changes.

Actual GPU image tests freeze the pose and vary one input at a time. Mean
absolute RGB differences at 320×200, averaged over the whole frame:

| Test | Forward+ | Compatibility |
|---|---:|---:|
| Normal strength 0 → 0.30 | 0.000274 | 0.000401 |
| Roughness 0.40 → 0.78 | 0.000528 | 0.000618 |
| Studio → side light | 0.039518 | 0.054669 |

All responses exceed the fixed 0.000005 minimum, and actor roots stay stationary.
These tests demonstrate an actual rendered material response, not artistic
approval or physically calibrated skin. Fine-detail shimmer is mitigated by
mipmaps/filtering but has not had a long moving-camera performance study.

## Provenance and limits

Local skin-v2-provenance.json records normal/albedo/shader hashes, exact normal
generation prompt and output identifier, the unsuccessful colour attempt and
material changes. The normal map is synthesized, not a scan or a high-poly bake.
Its relief/UV seams still need artistic inspection; the authored roughness
regions are approximations. The face and hands remain extremely coarse. No
modern-quality claim is made for anatomical silhouettes, hair, eyes or wardrobe.

All art derivatives, prompt/provenance and captures are ignored/local. No rights
to distribute original-derived art are established. Review source and shader
code stay separate from those inputs. Existing UO files, the Documents/Codex
prototype, saved login and server state remain unchanged.

Repository evidence is in ignored outputs/third-dawn/skin-v2-*.log; the fresh
screenshots and GPU metric JSONs were also saved to this chat's outputs folder.
