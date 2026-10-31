# Optional mount art

These inputs and derived art remain local. Code is GPL-3.0-or-later; its licence
does not replace the art licences below.

## Skeletal horse geometry

**Horse Skeleton** by **Diego Luján García**, [original model](https://sketchfab.com/3d-models/horse-skeleton-eaca504567604e879b8ab2cf2763025e),
[creator](https://sketchfab.com/diegoluga), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

The original creator/licence were verified against the public model API:
`https://api.sketchfab.com/v3/models/eaca504567604e879b8ab2cf2763025e`.
The raw metadata snapshot stays at `work/skeletal-source/source-metadata.json`.
The model was acquired through the public [Renderlyst source page](https://renderlyst.site/models/horse-skeleton)
and its openly linked GLB, `https://renderlyst.site/library/models/horse-skeleton.glb`.
That mirror re-encodes its textures to WebP.

Acquired GLB SHA-256:
`08d6dc96f600318d34f42e1f718a61f897aa09a31fb963bbd59ab23d21091c88`.

Changes: orientation/floor calibration, uniform scale, decimation from 135,451
to 16,254 triangles, smooth normals, four-influence spatial skin transfer and
saddle/stirrup socket fitting against the scanned back. Recipe:
`scripts/prepare-skeletal-horse.py`; local output/provenance under
`Viewer/local-art/mounts/skeletal-horse.*`.

Rig and source locomotion reuse **Warhorse Lite** by Literock Ventures /
Literock Studios, subject to its separate free end-product licence and input
pins in `scripts/horse-inputs.json`. Generated reaction/death and fitting code
are project code. The combined derivative must retain both notices and the
Warhorse restrictions; it is not a CC0 asset. The client character-art credits
include the creator, original URL, licence and modifications.

## Third Dawn source creatures and authored replacement maps

Ostards, ki-rin and llama geometry/rig/clips derive from the pinned preserved
Third Dawn archive. Proprietary source and derivatives remain ignored/local;
no redistribution grant is claimed. No proprietary executable or DLL runs.

Ki-rin and llama maps were absent from that archive. The saved replacement
albedos were authored with built-in imagegen using technical UV templates,
not recovered from the original game. Exact prompt files, output hashes,
source/recipe hashes, alias mapping and any omitted unreferenced animation
subtrees are in `Viewer/local-art/mounts/*-provenance.json`.
The pack llama reuses the llama body with project-authored panniers; it remains
unrideable when the server says so. Ethereal appearances are item-only mount
routes, without invented loose mobile body IDs.
