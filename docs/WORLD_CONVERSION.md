# World conversion

Supports Trammel map1 MUL or LegacyMUL UOP, staidx/statics, complete map/static diffs and last-duplicate precedence. Incomplete diff sets/verdata are refused; alternate map1x is not selected. Exact v1 conventions: ../IR.md.

Inputs remain in the user's OneDrive/Electronic Arts/Ultima Online Classic folder, opened read-only. Never edit, rename or redistribute them. Reading OneDrive may hydrate cache availability. build.ps1 -DataDir regenerates Viewer/local-world.json; synthetic data is Viewer/world.json. Both are ignored by Git.

Crop: x1408–1455/y1664–1711, Trammel. 48×48 height samples yield 47×47 terrain quads. Static bases use exact x/y/z; dimensions are arbitrary. ID-modulo colors do not classify terrain. Negative and stacked elevations remain intact.

Next: extract parser/IR libraries, parameterise facet/profiles, hash all inputs including statics/diffs, read tiledata flags/heights, deterministic seam-safe chunks, explicit mapping confidence and persistent overrides. Add multis/materials/water/collision only with supported rules. Compare landmarks independently before claiming complete fidelity to a selected server world.
