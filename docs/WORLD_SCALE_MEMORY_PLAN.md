# World-scale graphics memory plan

Goal: render every facet (Felucca, Trammel, Ilshenar, Malas, Tokuno, TerMur) at
final art quality on a mid-range GPU (reference: RTX 2070 Super, 8 GB) without
the per-region bake, disk cache or GPU memory growing with the size of the world.
Only what is near the player, and the distinct assets it uses, may cost memory.

## Where we are (measured 2026-10-28, Britain only, modern mode)

`scripts/test-streaming.ps1` now records GPU memory alongside CPU memory:

| Measure | Britain stress route |
|---|---|
| GPU video memory, peak | 3.72 GB |
| of which textures | 3.25 GB |
| of which buffers (meshes) | 0.40 GB |
| CPU (Godot static), peak | 0.89 GB |
| Frame time p95 / p99 / worst | 21 / 43 / 4,287 ms |

Architecture facts behind those numbers (file references in the 2026-10-28 survey):

- Streaming already bounds the scene: 64x64-tile districts, 3x3 near, a far ring
  of 16, up to 25 macro horizon tiles, threaded file and source loading.
- Every texture under `Viewer/Art` was imported lossless and uncompressed (RGBA8,
  about 5.3 MB per 1k texture with mipmaps), which is most of the 3.25 GB.
- Districts are baked offline into self-contained `.res` files: 1.7-1.8 GB per
  graphics mode for 88 Britain districts. Embedded meshes repeat per file.
- The bake holds the whole region in memory and refuses more than 128 districts;
  facet 1 (Trammel) and `outputs/britain` are hard-coded in streaming, minimap,
  world items and the bake.
- Materials are duplicated per instance in a few library paths, which also stops
  repeated props from instancing; static model caches are never released.
- Terrain is an unindexed mesh (up to ~131k triangles per district); there are no
  visibility ranges or occlusion culling; collision is built on the main thread.

## First expansion: Britain to Trinsic (measured 2026-10-29, modern mode)

`scripts/prepare-region.ps1 -Name britain-trinsic -Towns Britain,Trinsic` converts the union of the two native town regions: X 1088–2175, Y 1408–2943. That is 408 districts (Britain alone has 88), with 453,507 statics. The bake now accepts up to 512 districts. The client streams the region with `--region=britain-trinsic`; the default stays Britain.

| Measure | Britain (88 districts) | Britain to Trinsic (408) | Budget |
|---|---|---|---|
| Bake: joined-topology planning peak | not measured | 3.65 GB (about 4 min) | — |
| Bake: whole-run peak | not measured | 5.55 GB | — |
| Disk, modern cache | 1.8 GB | 14 GB | <= 8 GB per facet |
| GPU memory, peak (stress walk) | 1.26 GB | 1.52 GB | <= 3.0 GB |
| CPU memory, peak | 0.89 GB | 1.48 GB | <= 2.5 GB |
| Memory retained between identical laps | <32 MiB | +2 MB | <= 32 MiB |
| Frame time p95 / p99 | 17.5 / 48.9 ms | 24.8 / 26.6 ms | p99 <= 33 ms |

The stress walk (`scripts/test-streaming.ps1 -Region britain-trinsic -Route trinsic`) covers 54 stops, Britain to Trinsic and back twice, with 1,019 district installs. Its worst frames (2.8 s) come from 100-tile teleports between stops, not from walking. Runtime memory therefore does not grow with the region. What grows is offline: the bake holds the whole region (5.55 GB at 408 districts, so Phase B3 out-of-core baking is needed before a whole facet), and disk is over budget, with dense wilderness trees driving most of it (Phase B2 shared assets out of district files). The first bake attempt was stopped by Claude Code's low-memory reaper while other heavy processes ran (a local model server and two visual clients); it completed once they finished.

## Targets

| Budget | Target |
|---|---|
| GPU memory, any traversal of any facet | <= 3.0 GB (leaves headroom on 8 GB) |
| Texture memory | <= 1.5 GB |
| CPU memory | <= 2.5 GB |
| Frame time | p99 <= 33 ms; no hitch > 250 ms while walking or riding |
| Disk cache per facet and mode | <= 8 GB for the whole facet |

## Plan

### Phase A: cut what every scene pays (now)

1. GPU texture compression for all 3D art (BC1/BC3, BC5 for normal maps), keeping
   1k as the default size. Expected: textures from 3.25 GB to about 0.7-0.9 GB.
   Started 2026-10-28; owner GUI images stay lossless.
2. Measure GPU memory in the stress test and fail above the budget (added).
3. One material per look: tint, warmth and variant through instance uniforms,
   not duplicated materials, so repeated props instance (MultiMesh) again.
4. Visibility ranges by object size (small items fade at about 35 m, props at
   about 80 m, buildings stay) and shadow casting off for small items.

### Phase B: make districts cheap and facet-aware

1. Facet as a parameter everywhere (stream, bake, minimap, items, macro), with an
   output folder per facet: `outputs/<facet>/prepared[-modern]`.
2. Shared assets out of district files: districts reference library meshes and
   materials by path and store only their unique geometry (terrain, merged walls,
   placements). Expected: average district well under 5 MB.
3. Out-of-core bake: build each district from its own source rectangle plus a
   one-district apron, never the whole region; remove the 128-district cap; bake
   incrementally (only districts whose source or art fingerprint changed).
4. Indexed terrain with two LOD levels per district plus the macro horizon.

### Phase C: towns baked, wilderness generated

A full Trammel facet is 5,120 districts. Baking all of them at town density
would cost tens of GB per mode. Towns, dungeons and dense sites stay pre-baked;
open wilderness districts are generated on worker threads from source data when
approached (the live path already decodes source off the main thread), then kept
in an LRU disk cache with a fixed size. Collision is built off the main thread.

### Phase D: distance quality

Per-district hierarchical LOD (merged, simplified far meshes), generated mesh
LODs for every pinned scan, macro horizon beyond the near rings, and occluders
for city walls and large buildings.

## Rules for new art (from now)

- Every pinned model is reduced to a game budget (props usually 2-8k triangles)
  and its textures are capped at 1024 px and GPU-compressed.
- Variant sets are split into single-variant glTF files that share one texture
  folder, so a tile loads one plant and the set's maps load on the GPU once.
- The project's texture import default is GPU-compressed (`[importer_defaults]` in
  `Viewer/project.godot`); 2D interface images must be set to lossless explicitly.
- Coverage work and memory work are tracked together: the item catalogue reports
  coverage per facet, and the stress test reports GPU memory per route.
