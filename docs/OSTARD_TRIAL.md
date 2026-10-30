# Desert ostard: original Third Dawn upgrade trial

30 October 2026. A local animated comparison is implemented. This is an art
trial for owner review, with no live creature/body/mount replacement yet.

The owner subsequently approved the desert result. Forest, frenzied and ethereal
comparisons and the all-creature programme now follow in
[CREATURE_MODERNISATION.md](CREATURE_MODERNISATION.md); the measurements below
remain the original desert checkpoint.

## Result and review

Open `Review-Ostard.cmd` for the interactive comparison, or the local
`outputs/ostard-trial/index.html` for animated walk/run comparisons, head
close-ups and 31 actual Godot stills. Left is the source geometry/atlas; centre
isolates geometry refinement; right adds the new atlas and surface shader.
The camera, lighting, animation and pose match across treatments.

| Measurement | Source | Refined / modern |
|---|---:|---:|
| Geometric vertices, before glTF corner splitting | 98 | 1,490 |
| Triangles | 185 | 2,960 |
| Bones, unchanged names/hierarchy/rests | 24 | 24 |
| Available source clips | 7 | 7 |
| Albedo atlas | 128 x 128 | 1,254 x 1,254 |

The visible improvement is principally the eye, beak and scale detail; masked
Loop refinement softens the head, haunches and bends. The original long neck,
crest and overall silhouette remain. This supplies a useful original-creature
baseline, rather than a finished anatomical sculpt. The old sparse cage still
limits the mouth, feet, crest and some bends. No coverage percentage increases.

## Source and treatment

The read-only source is the previously acquired Third Dawn 2.0.4 Alpha Build 35
archive, from `https://zuluarchive.com/static/files/uotdb.zip`; acquisition is
documented in [THIRD_DAWN_IMPORT.md](THIRD_DAWN_IMPORT.md). The importer pins its
SHA-256 to `d872d59a4d3f92c82672bbadb98ae44772e42b44dacb4a28a1fdf39cf121dc0e`.
No original client executable, DLL or installer is run.

Members, case-insensitively resolved and individually hashed in local provenance:

- `uotdb/uotd/Models/Animals/ostards_ostard_desert_lod2.grn`
- Same stem with `_idle.grn`, `_walk.grn`, `_run.grn`, `_attack1.grn`,
  `_gethit.grn`, `_die1.grn`, `_fidget.grn`.
- `uotdb/uotd/Models/Maps/Ostard_ostard_desert.tga` (128-square, 32-bit TGA).

`prepare-third-dawn-ostard.py` uses the existing bounded independent Granny
reader. Two Loop levels retain UV seams, blend at most four normalised bone
influences and smooth joint weights by 0.22. A bone/height mask protects 14
original toe/contact vertices; displacement from the linearly subdivided cage
is capped at 55 mm at the chosen display scale. The common rig scale is
1.1146239953, calibrated from a 2.2 m original height, an artistic display choice.

The new texture was edited with the **built-in imagegen tool**, using the exact
source atlas as the edit target. No fallback API/CLI was used. Requested UV
registration is a generation constraint, not proof of exact pixel alignment.
On-mesh side/front/three-quarter review shows usable eye/beak placement and
detail; stretched islands and inherited painted shading remain limitations.
Generated atlas SHA-256:
`af769243adfaf763aabe85f3c8567c0dcec812d7f9b9c95a449e89dad0c62990`.

Final local assets and the exact final prompt:

- `Viewer/local-art/ostards/desert-original.gltf`
- `Viewer/local-art/ostards/desert-rounded.gltf`
- `Viewer/local-art/ostards/desert-modern.gltf`
- `Viewer/local-art/ostards/desert-modern-albedo-v1.png`
- `Viewer/local-art/ostards/desert-modern-albedo-v1.prompt.txt`
- `Viewer/local-art/ostards/provenance.json` (input/output/recipe hashes and prompt).

`OstardSurface.gdshader` uses nonmetallic rough skin, restrained specular and
fine normal detail approximated from albedo gradients. This is **not a sculpted
normal bake**. Existing native hue palettes and raw partial-hue bits work in the
review; these preview controls do not establish server identity integration.

## Animation and verification

All seven clips match 23 named source tracks. Original bone rotations and clip
durations survive import. As in the existing converter, horizontal root motion
is removed and a 30 Hz lowest-deformed-vertex correction is baked for the flat
review floor. This changes authored translation, including jump/attack height;
it is not terrain support, foot IK or faithful native world displacement.

`OstardTests.gd`: **6,933/6,933 checks**, **252 actual skinned poses** (three
treatments, seven clips, twelve phases). Checks cover real inverse-bind skinning,
finite/bounded vertices and bones, unchanged rig rests/hierarchy, normalised
weights, tangent frames, original durations, animated rotations, stationary
actor roots and lowest vertices within 35 mm of the review floor.
The measured maximum floor error in these samples was 24.8 mm.

Forward+ and OpenGL Compatibility GPU tests both pass actual-image changes for
normal detail, roughness, light and native hue. Local JSON contains measured
differences. These are fixture/material checks, not multiplayer evidence.
The full `scripts/verify.ps1` completed with exit 0, including existing human,
horse and equine regressions. Its known unrelated bridge fixtures still emit
two missing-`id` script diagnostics; existing malformed-Unicode, teardown and
PreviewTools nullable warnings also remain. This is not a diagnostic-free run.
The gallery includes 31 real stills plus 96 real sequence frames; GIF timing
follows the source cycles (walk 0.816667 s, run 0.483333 s), with distributed
centisecond rounding. Screenshots are renderer output, not generated artwork.

Local evidence: `outputs/ostard-trial/validation.json`, `material-forward.json`,
`material-compatibility.json`, `captures.json` and `frames/timings.json`.

## Reproduce

```powershell
python -B scripts/prepare-third-dawn-ostard.py
./scripts/review-ostard.ps1 -Validate
./scripts/review-ostard.ps1 -MaterialTest
./scripts/review-ostard.ps1 -MaterialTest -Compatibility
./scripts/review-ostard.ps1 -Capture
./scripts/review-ostard.ps1 -Sequence
# With Pillow available (the bundled workspace Python includes it):
python -B scripts/build-ostard-gallery.py
./scripts/verify.ps1
```

The first command requires the pinned archive under `work/third-dawn/` and the
saved generated atlas. Reusing that atlas reproduces the trial; generating a
fresh image from the prompt is not deterministic. All game art, derived glTF,
generated texture, provenance and captures stay ignored and local. Git contains
only code, recipes and notes; this trial adds no redistributable art package.

## Remaining work

Owner art review comes first. Then refine any rejected anatomy/material areas,
fit male/female riders and worn outfits, validate transitions and terrain
support, and map audited native bodies/items only after those pass. Test forest,
frenzied and ethereal forms independently before reusing the desert clips.
The original ki-rin still has the separate parser non-finite-value blocker.
Existing human/horse routes, wearable coverage (732/1,126), remembered login,
server rules, saves and concurrent house/terrain/item work are preserved.
