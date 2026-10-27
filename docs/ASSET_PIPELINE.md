# Asset pipeline

Current implementation: static-catalog.json contains explicit rules for every ID in the current crop; per-source coverage preserves grouping, source coordinates and confidence. All 2,689 records are accounted for, including procedural/semantic substitutes, not 2,689 exact model matches. See GRAPHICS_PASS.md. Kenney Furniture Kit is now imported only for furniture gaps, with its bundled CC0 notice and hashes in Viewer/Art/Kenney. Quaternius remains primary. Local-only source art contact sheets support review and must never be packaged.

Selected Quaternius CC0 Standard art is imported with archive/file hashes and bundled licenses in Viewer/Art/Quaternius. See ART_AND_MOVEMENT.md for the first reconstruction, character assembly, tests and limitations. Exact source placement does not imply finished or independently verified building geometry.

See [ASSET_SHORTLIST.md](ASSET_SHORTLIST.md) for the original survey and Britain-specific priorities. The selected free archives have now been audited and integrated; paid editions remain unpurchased.

Record author, original URL, exact version/hash, license text, attribution and modifications before import. Quaternius, Kenney, Poly Haven, suitable Fab assets and Mixamo are candidates for per-asset audit, not preapproved inventories. No paid assets without explicit approval.

Planned mapping record: original tile ID/classification, confidence, modern asset reference, deterministic variant seed, orientation/scale, biome and persistent override. Preserve canonical data; regenerate rendering from pinned source/config/assets. Ambiguous roofs/doors/stairs require confidence reporting and rules, not invented architecture.

Automated import/material/collision/LOD processing follows tiledata classification and seam-safe terrain. No original UO art redistribution.


RegionalRules and CityProps now extend the audited crop catalogue to every graphic ID in the prepared city of Britain. The original procedural models are GPL-3.0-or-later project code; no new third-party assets were imported. Existing pinned CC0 Quaternius/Kenney models and Poly Haven material provenance remain unchanged. Generated city coverage, raw reference art and all map-derived geometry remain local/ignored. Rules report semantic substitutes and inferred orientation rather than claiming exact artwork equivalence. See BRITAIN_MAPPING_AND_SEAMS.md.

## Original item catalogue (local reference)

`scripts/build-item-catalog.ps1 [-DataDir DIR] [-NoOpen]` decodes every item graphic, its tiledata entry and world placement counts from your own UO installation into ignored `outputs/item-catalog` (art PNGs, `catalog.js`, `index.html`). Families are ranked by placements in the world, Felucca excluded. Everything in that folder is original artwork or derived from it: use it only as a private reference. Never commit, upload or trace it into shipped assets.
