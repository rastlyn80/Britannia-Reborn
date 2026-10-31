# Distinct mounts: live integration and rider fitting

31 October 2026. The requested ostard, ki-rin, skeletal-mount and llama batch is
integrated through the real avatar appearance path. This extends the accepted
humans/horses and preserves server-owned movement, stats and permissions.
The wider all-creature programme remains ongoing.

## Implemented identities

| Native class / form | Mobile body | Mounted item | Presentation |
|---|---:|---:|---|
| Desert ostard | 0xD2 | 0x3EA3 | Approved source mesh/skin and native clips |
| Forest ostard | 0xDB | 0x3EA5 | Its green source-derived skin |
| Frenzied ostard | 0xDA | 0x3EA4 | Its rust source-derived skin |
| Ethereal ostard | No loose mobile | 0x3EAC | Ethereal source form; 0xD2 is only a rendering proxy |
| Ki-rin | 0x84 | 0x3EAD | Repaired original mesh; authored golden UV atlas |
| SkeletalMount / HellSteed | 0x319 | 0x3EBB | Distinct scanned skeleton on the accepted horse rig |
| Ordinary / rideable llama | 0xDC | 0x3EA6 for RidableLlama | Original llama rig and authored fleece atlas |
| Pack llama | 0x124 | None | Reused llama body with authored bone-following panniers |
| Ethereal llama | No loose mobile | 0x3EAB | Original ethereal geometry, fleece atlas and spectral shader |

`scripts/audit-distinct-mounts.py` pins these identities and restrictions to the
exact ModernUO revision in `Server/dependencies.json`. Runtime dispatch is in
`MountVisual.gd`; the existing `HorseVisual`/15 horse-backed identities retain
their existing interface. Historical unknown aliases remain deferred. The old
horse-specific registry's deferred entries for ki-rin/skeletal geometry now
refer to this separate dispatcher, not globally missing art.

**The server still denies female ki-rin riders and does not permit riding a pack
llama.** The client never synthesises mounted equipment or changes these rules.
Forced female ki-rin review previews are for fitting only; one such attack view
showed eight upper-chest skin pixels and is not certified as covered. It is
excluded from the supported riding matrix for the documented native reason.
No acceptance threshold was relaxed, and no new body-hiding mask was added.

## Art, rigs and motion

All three ordinary ostards and the ethereal form use the approved 2,960-triangle
geometry, 24-bone rigs and seven source clips. Ki-rin uses 2,156 geometric
vertices / 4,320 triangles / 30 bones; llama uses 1,887 / 5,792 / 29. The ethereal
llama is imported independently and reuses the authored llama atlas.

The strict source reader remains single-mesh by default. Its explicit
animation-only mode ignores embedded reference meshes while preserving chunk,
bone, object-name and finite/timed-track validation. Ki-rin animation names use
`bip01` where its body uses `bip_01`; a unique spelling map and ancestor checks
permit matching. Only subtrees without retained bones are omitted. Clip reports
record 29 ki-rin / 28 llama matched tracks. Source timings and rotations are
retained; existing in-place translation and 30 Hz flat-floor corrections remain.
These translations are presentation adjustments, not native world motion or IK.

Missing ki-rin/llama skins were **authored with built-in imagegen** against
technical templates generated from their actual UV triangles. They are not
recovered original textures. Final saved files and exact prompts:

- `Viewer/local-art/mounts/kirin-albedo-v1.png`
- `Viewer/local-art/mounts/kirin-albedo-v1.prompt.txt`
- `Viewer/local-art/mounts/llama-albedo-v1.png`
- `Viewer/local-art/mounts/llama-albedo-v1.prompt.txt`

`*-provenance.json` records input, recipe and output hashes, repairs, omitted
tracks and prompts. Source and generated art stay local. Dark glossy eyes were
authored as head-bone attachments. The original coarse head/mane silhouettes,
some UV stretching and source-motion limitations remain open to artistic review.

The skeletal geometry is **Horse Skeleton by Diego Luján García, CC BY 4.0**,
acquired through its public GLB mirror and checked against the original model's
creator/licence metadata. It was reduced to 16,254 triangles, calibrated and
skinned to the separately licensed 39-joint Warhorse rig. Saddle/stirrup sockets
were lowered 153 mm to fit the scanned spine. Original scan normals/materials
remain, with matte bone shading; reaction/death floor fitting uses actual skin
vertices and preserves airborne gallop clearance. Exact attribution, source,
checksum, modifications and combined licence limits are in
[THIRD_PARTY/Mount-Art.md](../THIRD_PARTY/Mount-Art.md), also included in the client
art-credit dialog. It is not a freely redistributable standalone asset pack.

Rider hips, feet and available hands follow animated bone-relative anchors;
facing follows the creature, and the existing grip and native weapon/shield
rules remain. Mount/dismount ground-foot paths adapt to saddle height. Source
stance support samples actual skinned sole vertices and raycasts real terrain,
adjusting visual bones and bounded body slope without moving the network root.
Pack panniers follow the spine. Corpse amount/body IDs select matching held
death models and native hues; reins/contact sway are disabled on corpses.

## Evidence

- **529 actual isolated-server checks, 18 class/gender cases:** real world entry,
  upstream mounts/ethereal casting, exact layer 25 and hues, walk/run and return,
  observer replication, dismount, denied rides, attack/reaction packets, real
  deaths and corpse packets/art. Disposable loopback port 2594; no production
  accounts, runtime, saves or existing server process touched.
- **2,928 rider checks / 1,296 seated pose samples**, plus turned-facing checks:
  both human bodies, three outfits, source gaits, seated attacks/ranged actions
  and transitions between horse/source/skeletal families. This is offline
  kinematic evidence, separate from the live checks above.
- **1,193 skin/action/corpse checks / 558 deformed poses:** actual inverse-bind
  vertices, native raw identities/hues, all seven source clips and skeletal
  actions, stationary actor roots, corpse poses and skeletal reaction floors.
- **63 terrain checks / 21 samples:** seven loose body routes on flat ground and
  two slopes, actual collision rays and stance-sole fitting within 50 mm.
  These are finite idle/support fixtures, not exhaustive moving-terrain tests.
- **1,920 GPU clothing views**, all passed: `outputs/ostard-riding/clothing-validation.json` and
  `clothing-rear-validation.json`, using actual masked-skin and complete-body
  reference renders for supported native gender combinations. Limits are four
  visible skin pixels, 98% body occupancy and 99.5% seat occupancy. Open-neck
  outfits are not represented as full coverage; armour sets include a gorget.
- Full `scripts/verify.ps1` completed with exit 0. Known unrelated bridge missing
  `id`, malformed-Unicode and teardown diagnostics remain. The early overlapping
  verification hit a partial local artwork-cache write; that cache read now
  treats invalid/in-progress JSON as a cache miss, and the rerun passes.

Local evidence lives under `outputs/ostard-riding/`; the actual-render gallery
is `outputs/mount-integration/index.html` (97 frames). No local fixture is called
multiplayer evidence; only the disposable two-client server run establishes
world entry, permissions and replication.

## Reproduce and review

All review shortcuts now live under **`Reviews/`**. Start
`Reviews/Review-Mount-Riding.cmd`; its buttons select species and gaits. The
normal game/server launchers remain at the root.

```powershell
python -B scripts/prepare-distinct-mounts.py --templates-only
# Rasterise technical guides with the project Godot executable:
# Godot --headless --path Viewer --script "$PWD/scripts/render-mount-uv.gd"
# Author/save the replacement atlases separately, or retain the saved versions.
python -B scripts/prepare-distinct-mounts.py
# With the pinned free scan at work/skeletal-source/horse-skeleton.glb:
# Blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python scripts/prepare-skeletal-horse.py
./scripts/review-mounts.ps1 -Validate
./scripts/review-mounts.ps1 -Clothing
./scripts/test-horses.ps1 -Live -SkipContact -Ostards
./scripts/review-mounts.ps1 -Capture -Item 0x3EAD
./scripts/review-mounts.ps1 -Pack -Capture
python -B scripts/build-mount-gallery.py
./scripts/verify.ps1
```

The scan URL/checksum/licence are pinned in `scripts/skeletal-inputs.json`.
Capture all eight named form folders with `MountRidingReview.gd --item=<decimal>
--capture-dir=<absolute-folder>` before rebuilding the full gallery. Saved
atlases reproduce the import; fresh imagegen results are not deterministic.

This is finite category integration. Additional exact art refinement, every
possible outfit/action/terrain combination, historical aliases, all-creature
action coverage and distributable clean-client asset packaging remain separate
work. The other creature families continue in CREATURE_MODERNISATION.md.
