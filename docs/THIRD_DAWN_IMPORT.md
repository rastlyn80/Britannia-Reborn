# Third Dawn human and ogre import experiment

27 October 2026. **Local Godot import and animated review implemented.** This is
an asset compatibility experiment, not a live mobile replacement or finished art.

## Plan and result

Preserve the existing converter/IR/Godot foundation and current Avatar. Convert
one original human and one ogre to portable glTF, using their own rigs and clips;
compare them with the current avatar in the actual Viewer project; verify skin
deformation, ground contact, materials and root isolation before considering live
entity-body mappings. No ModernUO changes or logins are required for this stage.

`Review-Third-Dawn.cmd` opens the local comparison: current CC0 avatar, Third Dawn
human and Third Dawn ogre. Choose Idle/Walk/Run, pause/resume, hold RMB to orbit,
scroll to zoom and press Escape to close. There is no network connection.

## Reproduce with a local source archive

```powershell
python scripts/import-third-dawn.py --archive work/third-dawn/uotdb.zip
python scripts/test-third-dawn.py
./scripts/review-third-dawn.ps1 -Validate
./scripts/review-third-dawn.ps1 -Validate -Compatibility -Screenshot outputs/third-dawn/idle.png
./scripts/review-third-dawn.ps1 -Clip Walk -Screenshot outputs/third-dawn/walk-forward.png
./scripts/review-third-dawn.ps1 -Clip Run -Screenshot outputs/third-dawn/run-forward.png
./scripts/verify.ps1
```

The importer reads the ZIP directly and writes only to ignored
`Viewer/local-art/third-dawn/`. Source archive and research references are under
ignored `work/third-dawn/`. Converted art, engine caches, provenance, captures and
validation JSON remain local. Neither the Documents/Codex prototype nor the
existing UO installation was modified. The current default Avatar, collision,
networking, saved login and server state are unchanged.

## Exact provenance and scope

- Preserved download: `https://zuluarchive.com/static/files/uotdb.zip`, linked by
  `https://zuluarchive.com/pages/files.html`. Third-party preservation source, not
  an authenticated current official release.
- Archive SHA-256:
  `d872d59a4d3f92c82672bbadb98ae44772e42b44dacb4a28a1fdf39cf121dc0e`.
- Internal build evidence: `2.0.4 UO:Third Dawn Alpha Build 35` in `uotd.exe`.
  No original executable or DLL was executed.
- Source paths under `uotdb/uotd/Models/`: `Humans/H_Male_LOD2.grn`,
  `H_Male_Idle1.grn`, `H_Male_Walk.grn`, `H_Male_Run.grn`,
  `Monsters/ogres_ogre_lod2.grn`, `ogres_ogre_idle.grn`,
  `ogres_ogre_walk.grn`, `ogres_ogre_run.grn`, and
  `Maps/UT256_H_Male.tga`, `Maps/ogres_ogre.tga`.
- Local `provenance.json` records every input hash, converter hash, output hash,
  scale, clip correspondence, omitted leaf tracks and sampled floor corrections.
- These are proprietary EA/Origin game assets. No redistribution grant is
  established. All originals, converted models/textures and screenshots are
  ignored and must not be committed or packaged with the public client.

## Implementation

`scripts/import-third-dawn.py` is an independently implemented bounded parser and
glTF writer using Python's standard library. Format research consulted Iris2's
`include/grannyparser.h`, `include/grannyloader_i2.h` and related loaders at
commit `c3f53748f3366d6716e89c9aa94a6743a72edc6e`; reference source remains ignored.
No Iris2 library or proprietary Granny runtime is linked into the client.

- Reads typed Granny 1 chunks, bones, skin-weight-to-bone ties, object-name
  metadata, separate UV indices, absolute local animation tracks and raw/RLE TGA.
- Emits embedded-texture glTF with skin inverse bind matrices and original rigs.
  Rough nonmetallic materials retain the original albedo; no new art is invented.
- Converts Z-up to Y-up, grounds the source visual and fits the human to 1.8 m
  and the ogre to 2.8 m. These are review choices, not claimed canonical UO sizes.
- Matches animation bones by name. Human: 31 matched tracks, 2 absent toe leaves.
  Ogre: 34 matched tracks, 1 absent ponytail leaf. An unmatched intermediary bone
  is rejected. Native bone order is not assumed to match between files.
- Human clips carry a rotated authoring frame and roughly six metres of pelvis
  offset. Re-anchor that offset in the correct frame while retaining the absolute
  joint orientations. Subtracting the animation file's posed skeleton as though
  it were a neutral rest pose incorrectly erases the original stance.
- Removes horizontal skeleton-root displacement for in-place presentation.
  A 30 Hz floor correction, calculated from weighted deformed vertices, removes
  varying clip stance offsets. This is a flat-floor fit, not terrain foot IK.
- `ThirdDawnBody.gd` offers the same `animate(moving,direction,delta,speed)` and
  reset entry points as the existing Avatar. Walk/Run selection is compatible
  with presentation speeds; its root is never driven by the imported animation.
  It is currently exercised only by `ThirdDawnReview.gd`, not installed in live
  mobile rendering. The default CC0 player body remains in place.

## Evidence

| Body | Source vertices | Triangles | Bones | Clips |
|---|---:|---:|---:|---|
| Human male | 183 | 362 | 34 | Idle, Walk, Run |
| Ogre | 229 | 452 | 37 | Idle, Walk, Run |

Six synthetic tests cover malformed/truncated chunk boundaries, coordinate
rotation, zero quaternions, TGA orientation and invalid RLE runs. The engine
validation samples four phases of each clip for both bodies: 24 deformed mesh
poses, using Godot's actual imported Skin inverse binds and skeleton poses.
Checks cover finite/non-exploding bounds, changing joint poses, stationary entity
roots and a 35 mm floor tolerance. Headless, Compatibility and Forward+ runs pass;
sampled floor error is under 10 mm. Idle and walking captures were visually
inspected; run capture is retained locally. All six clips are present.

Evidence: ignored `outputs/third-dawn/engine-validation.json`, renderer logs,
`idle.png`, `walk-forward.png`, `run-forward.png` and `full-verify.log`.
The importer runs without Blender or third-party Python packages.

## Assessment and remaining work

An additional read-only equipment probe found the male chain shirt (62 vertices,
13 weighted bones), plate breastpiece (54 vertices, 9 weighted bones) and
cowl-down robe (111 vertices, 15 weighted bones). Every weighted bone name in
these three files exists in the imported male body rig. This establishes a
promising attachment correspondence, not a rendered/fitted wardrobe: shared
bind transforms, body hiding, overlap, dyes and native equipment-layer mapping
still need implementation. Local evidence: `outputs/third-dawn/equipment-probe.json`.
The archive includes later-named equipment as well as the executable's early
build string; its asset completeness/era must not be inferred from that string.
File totals include animation files and variants, not that many unique monsters.

**Technically adaptable:** real textured skinned bodies and native locomotion
work in Godot. The small meshes are inexpensive. The review adapter supplies a
useful seam for a future opt-in body catalogue.

**Not suitable as finished modern art:** these early low-detail models and
painted textures look markedly older than the current character. The human
texture is neutral grey artwork intended for the old client's colouring system;
no skin-hue system, clothing, hair or equipment assembly is implemented here.
The original ogre's angular face/tusks are retained. No texture enhancement,
remeshing, normal-map creation or Quaternius-rig retargeting is claimed.

Next possible gates: review silhouettes/style with the owner; fit/validate
native attack and death clips; explicit body-ID/height catalogue with CC0 fallback;
terrain foot contact, movement pace and costume/hue assembly; then a separately
tested opt-in live presentation. Cosmetic animation is not server gameplay.
Distribution of any original-derived art requires a separate rights decision.
