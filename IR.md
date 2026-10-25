# World IR v1

Engine-independent UTF-8 JSON. No Godot types, textures, meshes, or art payloads.

| Field | Meaning |
|---|---|
| schema | 1 |
| facet | explicit Trammel/map1; no map0 fallback |
| provenance | synthetic flag or local base map + local diff profile/counts |
| originX, originY | absolute UO crop origin |
| width, height | number of terrain samples, inclusive lower/exclusive upper bounds |
| elevationScale | 0.2 viewer units per signed UO elevation unit |
| terrain | x, y absolute integers; z signed integer; id uint16 value |
| statics | x, y absolute; z signed; id and hue uint16 values; duplicates retained |
| mapSha256 | SHA-256 of source map container (MUL or UOP) |

One tile step equals one horizontal viewer unit. Godot position = `(x-originX, z*0.2, y-originY)`. East is +X, south is +Z, up is +Y. Proxies use this position at their base. An optional vertical exaggeration is a viewer concern; raw z remains unchanged.

Terrain records are height samples. The viewer joins adjacent samples into triangles, so a 48×48 sample crop contains 47×47 quads. No smoothing, interpolation changes, or invented height samples are exported. Terrain colors are diagnostic ID modulo 3; they are not terrain classifications. Static boxes have arbitrary dimensions; geometry fidelity is not claimed.

MUL: 8×8 blocks, 196 bytes each (4-byte header, 64 × ushort ID + signed byte Z). Block index = `(x/8)*(mapHeight/8)+(y/8)`; in-block index = `(y%8)*8+x%8`. Static index: signed offset, byte length, extra (12 bytes); static record: ID, local X/Y, signed Z, hue (7 bytes). Little endian throughout.

UOP: linked directories, filename hash lookup, 4096 MUL blocks per logical chunk, header offsets and compression 0/uncompressed or 1/zlib. Directory order is not map order. Other compression is rejected. Complete mapdifl1/mapdif1 and stadifl1/stadifi1/stadif1 overlays are applied; list position selects the replacement record, last duplicate wins, and statics are replaced rather than appended. Incomplete sets and verdata are rejected. Profile is explicitly the base map plus all local diffs; extended map1x variants are not selected. Server-specific patch counts or alternate extended-world modes require a future explicit profile selector. No dynamic/server objects, multis expansion, tiledata semantics, or collisions in this milestone.
