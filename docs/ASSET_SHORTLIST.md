# Britain asset shortlist — 25 October 2026

Status: selected free Quaternius environment, character, animation and fantasy-outfit packs are now downloaded, audited and integrated. No purchases. See ART_AND_MOVEMENT.md and Viewer/Art/Quaternius/manifest.json for exact editions, hashes, modifications and remaining fidelity limits. The table below records the initial selection rationale.

User selection: Medieval Village MegaKit for architectural statics, Stylized Nature MegaKit for nature, and Kenney only where something is missing. Use the two Quaternius kits as the primary visual family. Begin with their free editions; expanded editions have not been purchased or authorized for purchase.

| Candidate | Intended use | License / edition |
|---|---|---|
| [Quaternius Medieval Village MegaKit](https://quaternius.itch.io/medieval-village-megakit) | Preferred architectural starting point: modular walls, floors, roofs, stairs, doors and windows | Publisher declares CC0. Standard is free; Pro and Source are paid. The advertised 300+ pieces describe the full kit, not necessarily Standard. Engine projects/custom collisions belong to Source. |
| [Quaternius Stylized Nature MegaKit](https://quaternius.com/packs/stylizednaturemegakit.html) | Trees, bushes, rocks, grass and flowers for classified nature statics | Publisher declares CC0; free subset, extra models and engine-ready Source are distinct editions. Audit the free archive before promising specific models. |
| [Kenney Fantasy Town Kit](https://kenney.nl/assets/fantasy-town-kit) | Alternative for missing architecture or rapid mapping experiments | Free CC0; official page lists 160 files. Simpler appearance: evaluate against the intended richer stylized fantasy direction before mixing it with Quaternius. |

Prefer glTF imports and one coherent art family. Do not purchase an upgraded edition without authorization. Retain the downloaded license and record archive SHA-256, exact filenames and modifications in an asset manifest.

## Mapping priority

Read-only inspection of the current 64×64 Trammel crop and modern tiledata identifies grass, dirt, cobblestones, wood and brick surfaces. Common statics include wooden shingles, slate roofs, plaster/stone walls, wooden boards and water. The local aggregate inventory is ignored at `outputs/validation/local-asset-inventory.json`; it is not a redistributable art pack.

1. Replace diagnostic terrain colors with coordinated grass, earth, paving and floor materials while retaining the original terrain mesh/elevations. Preserve unknown and NODRAW classifications explicitly.
2. Reconstruct one building with modular wall, floor and roof pieces. Validate dimensions, pivots, orientations, openings and elevation against source tile placements. Roof slopes and wall directions require explicit rules; names alone cannot determine them.
3. Combine contiguous water tiles into water surfaces, preserving height and boundaries.
4. Add vegetation and props only where classified source placements justify them. Keep decorative fill separate from canonical statics.

Do not place a complete prefab house over each static: UO statics often describe individual wall/roof segments, and whole buildings would distort footprints. Preserve canonical IDs/XYZ in the intermediate representation and keep replacement rules in a separate deterministic mapping layer. Server movement remains authoritative.

## First acceptance target

One recognisable Britain building and its surrounding paving, grass and water, with visible missing-mapping diagnostics, no moved source coordinates and no proprietary UO art copied into the project. Capture a before/after view and verify coordinate/elevation regression checks after implementation.
