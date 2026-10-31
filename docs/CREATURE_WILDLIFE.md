# Creature pipeline and wildlife checkpoint

31 October 2026. The all-creature programme continues across families without
requiring a review decision at each routine batch boundary. Prepared trials,
validated presentations and actual server evidence are counted separately.

## Accepted wildlife

The first generic batch contains 26 source forms and 30 body routes: four bears,
eight dogs/wolves, two deer, four cats, two pigs, four goats/sheep, a giant rat
and a walrus. Of these routes, 27 are found in the bounded native source audit;
the other three are source-table identities rather than newly certified server
species. Existing humans, equines, llamas and bovines remain integrated.

The combined disposable-server test passed 2,366 checks in 54 cases covering
27 native bodies, with two actual clients entering the world. It exercises
declared native constructors, body/hue replication, native movement and running
flags, classic/new animation packets, actual death and corpse replication.
Familiars receive a control master as fixture setup, and their native corpse
suppression remains intact. Arena relocation is setup, not movement evidence.
These checks do not certify autonomous AI, taming or complete combat gameplay.

Art checks sample original/refined/modern deformation, finite weights and
source timing, plus flat ground and two slopes where compatible stance chains
exist. There are 4,914 deformed samples, 320 GPU checks over 156 views, and
416 actual comparison captures. GPU checks establish visibility and dye
response; anatomy, exact UV fidelity and arbitrary terrain remain distinct.
Some headless corpse cleanup produces a dummy-renderer null-material
diagnostic despite passing functional and separate GPU checks.

## Sources and explicit approximations

The preserved Third Dawn 2.0.4 Alpha Build 35 archive is read statically;
no proprietary game executable or DLL is run. Its SHA-256 is
`d872d59a4d3f92c82672bbadb98ae44772e42b44dacb4a28a1fdf39cf121dc0e`.
The original model table supplies body, scale and shared-animation links.
Including SeaCreatures, the archive contains 150 mesh candidates in 54 filename
groups. This is an early archive, not the full modern UO creature catalogue.

The generic importer retains UVs, skin weights, bone names and hierarchy,
prunes only unreferenced points, and bounds subdivision displacement to 35 mm
in final units. Uniform exporter units are folded into translations.
Nonuniform/sheared rigs use an explicitly recorded affine-to-rigid rebind:
joint centres and polar rotations are sampled, but exact native dynamic
scale/shear skinning is not claimed. Optional corrupt clips remain rejected.
Source aliases and authored recoil/lunge/death fallbacks are recorded per
model rather than labelled recovered choreography. Rigid multipart artwork
and other unresolved source failures stay blocked.

New coat atlases were made with built-in image generation from inspected
source atlases. PNGs and exact prompt sidecars live under ignored
`Viewer/local-art/creatures/`; the local work board records paths and hashes.
These derived assets and captures are not committed or granted redistribution
rights. A Git clone still needs separately authorised local asset preparation.

## Reproduction and catalogue

From the repository root in PowerShell, after supplying the preserved archive
at `work/third-dawn/uotdb.zip` and the configured pinned native server:

```powershell
python -B scripts/audit-creature-sources.py
python -B scripts/prepare-creatures.py --families bruins canines deer felines porcines ruminants rodents walrus
& ./scripts/test-creatures.ps1 -Families @('bruins','canines','deer','felines','porcines','ruminants','rodents','walrus') -Capture
& ./scripts/test-horses.ps1 -Live -SkipContact -CreatureFamily all
python -B scripts/build-creature-catalogue.py
& ./scripts/verify.ps1
```

Native tests use fresh disposable runtimes and accounts on loopback port 2594;
the running world, production accounts and saves are excluded. Acceptance
requires passing pose/GPU evidence for the exact asset hashes. Source trials
are never activated just because extraction succeeds.

Review through `Reviews/Review-Creatures.cmd` or ignored
`outputs/creatures/index.html`. Detailed evidence is in each family's
`validation.json` and `appearance.json`, plus `all/live.json` and
`atlas-provenance.json`. The native work board currently audits 275 literal
nonhuman body IDs, of which 50 have routes and native evidence. This bounded
source scan excludes dynamic constructor results and is not an exhaustive
denominator for every UO body.

Continue with ogres/orcs/trolls and other original monster families, remaining
source repairs and sea creatures; then audit missing modern native identities,
reuse suitable models or trace free alternatives. Other rideable bodies need
separate rider fitting and native mount tests. Exact anatomy/choreography,
broader outfit/terrain combinations and distributable asset packaging remain
open work; prepared monster exports do not count as completed replacements.
