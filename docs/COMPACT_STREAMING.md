# Compact streaming cache — the storage rule (adopted 31 October 2026)

Owner decision, 31 October 2026, when the whole-Trammel bake was estimated at 60–120 GB: the prepared streaming cache stores every model **once** and places it **by reference**, compressed. Merged, uncompressed per-district geometry is no longer an accepted bake output. This applies to every facet: Trammel first, then Felucca, Ilshenar, Malas and Tokuno.

## Why

The facet itself is small. Trammel converts to 138 MB of source data (7,168 districts of 64×64 tiles; 4,164 of them empty ocean or void; 2.95 million statics). The cache was large only because of how the bake stored it.

| Prepared cache (measured 31 October 2026) | Near districts | Near total | Median district | Largest district | Far total |
|---|---:|---:|---:|---:|---:|
| Britain, classic | 88 | 2.33 GB | 22.9 MB | 72 MB | 0.24 GB |
| Britain, modern | 88 | 2.23 GB | 22.3 MB | 72 MB | 0.24 GB |
| Britain to Trinsic, modern | 408 | 15.99 GB | 27.9 MB | 204 MB | 0.92 GB |

On 26 October the same 88 Britain districts took about 299 MB with instancing (see [STREAMING_AND_MINIMAP.md](STREAMING_AND_MINIMAP.md)). Later bakes drifted into storing merged geometry instead. The largest district near Trinsic is a single 204 MB ArrayMesh: every tree, rock and wall copied out vertex by vertex. At that density all of Trammel would need roughly 60–120 GB, and the five facets several times that.

## The rule

1. **Models once, placements by reference.** A district file holds placements (model id, transform, hue/variant) and points at shared model resources stored once for the whole dataset. It must not hold copies of model geometry. Repeated meshes are MultiMesh instances, with their CPU transform arrays exported as before.
2. **Only what is unique is baked per district:** the terrain mesh, merged connected architecture that genuinely differs per place (walls, roofs, floors), and collision.
3. **Collision is compact.** Repeated props use shared shapes placed by reference. Only terrain and unique architecture carry baked triangle collision, still in slices of at most 2,000 faces for the frame budget.
4. **Compressed.** Resources are saved compressed (`ResourceSaver.FLAG_COMPRESS`). Mesh data uses Godot's vertex compression where precision allows.
5. **One cache per graphics mode is optional.** If classic and modern share models, they share the files.
6. **A size budget, enforced:**
   - near district at most 2 MB median and 8 MB maximum;
   - all of Trammel at most 5 GB.
   - The bake reports sizes, and verification fails a cache that breaks the budget.

## Expected size

- Trammel: about 1–3 GB (about 200 MB of placements for 2.95 million statics, about 1 GB of terrain for the about 3,000 land districts, plus shared models and collision).
- Felucca: the same map as Trammel; it can reuse Trammel's models and most of its terrain.
- Malas, Ilshenar, Tokuno: much smaller.
- Whole world: target under about 10 GB.

These are estimates until the first compact bake is measured; the measured figures replace them here.

## Status

- Trammel is converted (`outputs/trammel`) and its server world is populated (`scripts/populate-trammel.ps1`).
- The full Trammel bake waits for the compact format.
- Existing Britain caches stay usable until they are rebaked compact.
