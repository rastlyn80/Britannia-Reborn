# Ordinary bird: occurrence-first replacement

Bird is first in the configured Trammel occurrence order (253 spawn locations). Body 6 now uses a distributable licensed replacement at `Viewer/Art/Creatures/Birds/small-bird.glb`, registered by the public creature manifest. Other families' original game-derived artwork remains local.

The yellow-billed shrike is by **pistachio / Al Stachio**, released under **CC0-1.0** on [the author's page](https://opengameart.org/content/bird-yellow-billed-shrike). `scripts/bird-inputs.json` pins the download URL, archive SHA-256 and all six original members. The original 996-triangle mesh, 65-bone rig, diffuse, normal and roughness maps are retained. The source supplied no animation actions. Its embedded Blender text is never executed: conversion uses factory startup, disabled automatic scripts and `use_scripts=False`.

Sixteen authored categories cover idle, wing-assisted hopping, low flight, take-off/landing, feeding, attacks, reactions, fidget/alert, call/cast and two death directions. Runtime LieDown explicitly reuses the authored collapse. These are category replacements, not recovered original UO choreography. The folded wing is a packed feather fan rather than individual feather simulation; species-specific crow/raven anatomy and more natural feather articulation remain art improvements. This route covers ordinary body 6, not eagle body 5 or every bird species.

Seven active source weights per vertex are retained through an eight-influence export. Obsolete non-bone/control weight groups are excluded. The latest four-weight trial lost up to 6.74 mm; eight influences differ by less than 0.0001 mm over 80 Blender comparison samples. Source dual-quaternion preview is deliberately disabled before authoring floor clearance to match linear glTF/Godot skinning. These measurements concern weight reduction against that linear reference, not equivalence to the source's dual-quaternion preview.

Native hues pass through unchanged, including the partial-colour bit. Feather normal/roughness maps drive the actual shader. Full colours and the native dark bird hue affect the rendered surface. Partial colour uses an authored feather-zone interpretation of the licensed translucency map; it is not a recovered UO sprite-grey mask. Measured animation bounds supply a small selection box, terrain-following selection height, a bird-sized camera and a head-following overhead label. Support aligns to a sampled collision plane without inventing leg chains from independent foot controllers.

Evidence in ignored `outputs/creatures/bird-trial/`:

- 2,068 motion checks  / 336 actual skin samples: topology, eight weights, support clearance, loop endpoints, leg stability, flight torso, root stability and frozen death geometry.
- 117 Forward+ presentation checks: actual normal/roughness response, three raw hues, 13 classic animal groups/four modern action types, selection/camera/label bounds and 12 raised/lowered flat/sloped collision cases.
- 102 disposable-server checks, zero failures, using two real connected clients: native Bird constructor/body, full/partial colours, native movement and action packets, death, facing and static corpse. Report: `outputs/creatures/birds/live.json`; log: `work/birds/native-tests.log`. This is isolated native integration, not a production or whole-world multiplayer claim.
- Nine clean distribution checks in a separate project containing only the public bird bundle and 50 compile-time source dependencies, with no local-art directory, game inputs or server. The actual avatar, movement/call clips and frozen static corpse load there. `python -B scripts/test-bird-distribution.py` reproduces this; full verification includes it.

The public mesh and maps are included in Git with provenance and notices. Embedded textures use Godot's Basis Universal scene import to avoid duplicate extracted images; the public import and actual GPU checks were rerun. [Godot import semantics](https://docs.godotengine.org/en/4.7/classes/class_gltfstate.html). All original inputs/tools, test accounts/saves and captures remain ignored. No production server or original installation is changed.

Reproduction from the repository root:

1. `./scripts/prepare-birds.ps1 -Install` verifies/downloads the exact CC0 source, authors the asset with Blender, runs skin/GPU checks, measures interaction bounds and installs only after fresh receipt verification. Local Blender/Godot tools must already be available.
2. Import the project, then run `BirdMotionTests.gd -- --asset=res://Art/Creatures/Birds/small-bird.glb` headlessly and `BirdPresentationTests.gd` with Forward+ to check the installed bundle. `scripts/verify.ps1` includes the public motion check.
3. `./scripts/test-horses.ps1 -Live -SkipContact -CreatureFamily birds` uses the existing guarded disposable loopback server 2594. Never point it at production. `./scripts/build-corpse-catalogue.ps1 -Render` checks the native graphic 0x2006/body 6 variant with the other available cadavers.
4. Rebuild the work board and action ledger with `scripts/build-creature-catalogue.py` and `scripts/build-creature-actions.py`. Public licensed routes and local source routes are both counted; integration evidence and final art/action completion remain separate.

Finite collision planes do not certify arbitrary steps, obstacles or every terrain edge. The global occurrence order, unresolved identities, anatomy and original-action gaps remain active. Orc reviews are next, then the common water/sea creatures.

Shared regression:101 existing source forms/36 groups pass68,115 motion checks/20,664 skin samples and1,395 GPU checks/606 views. All162 available corpse variants pass1,509 rendered checks. Fresh full `scripts/verify.ps1` exits0 with no script errors, including79 developer-edit checks and final world startup (`work/birds/full-verify-clean.log`). A street-test fixture needed its required terrain graphic ID; its43 checks now pass cleanly and verification rejects a script error even when Godot exits0. No terrain runtime was changed.
