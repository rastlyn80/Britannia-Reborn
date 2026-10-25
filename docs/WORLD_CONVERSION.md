# World conversion

Supports Trammel map1 MUL or LegacyMUL UOP, staidx/statics, complete map/static diffs and last-duplicate precedence. Incomplete diff sets/verdata are refused; alternate map1x is not selected. Exact v1 conventions: ../IR.md.

Inputs remain in the user's OneDrive/Electronic Arts/Ultima Online Classic folder, opened read-only. Never edit, rename or redistribute them. Reading OneDrive may hydrate cache availability. build.ps1 -DataDir regenerates Viewer/local-world.json; synthetic data is Viewer/world.json. Both are ignored by Git.

Original crop: x1408–1455/y1664–1711, Trammel. 48×48 height samples yield 47×47 terrain quads. The current play crop is x1576–1639/y1568–1631 (64×64). Negative and stacked elevations remain intact. Optional tiledata metadata now classifies surfaces and statics; imported art uses separate, provisional reconstruction rules. See ART_AND_MOVEMENT.md for source anchors and remaining geometry limitations.

Next: extract parser/IR libraries, parameterise facet/profiles, hash all inputs including statics/diffs, deterministic seam-safe chunks, explicit mapping confidence and persistent overrides. Tiledata flags/names/heights and its file hash are implemented; the current first art pass includes floors, wall/roof modules, ground and water. Multis, exact architectural rules and client collision remain incomplete. Compare landmarks independently before claiming complete fidelity to a selected server world.
