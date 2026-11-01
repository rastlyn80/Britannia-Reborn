# Domestic cat body 201

Cat uses an independently licensed Quaternius model, with its original 24-bone rig and two evaluated source actions. The Third Dawn model table has no body 201 row; the earlier small-panther comparison was not accepted because its proportions remained those of a large predator. Cat's native identity is confirmed from pinned `Projects/UOContent/Mobiles/Animals/Town Critters/Cat.cs`: `Body = 0xC9`, with the native random animal hue and gameplay attributes unchanged.

## Exact independent source

Source: [Quaternius, Animated Animales Low Poly / Animal Pack Vol.2](https://opengameart.org/node/78596), [CC0-1.0](https://creativecommons.org/publicdomain/zero/1.0/).

| Input | Bytes | SHA-256 |
|---|---:|---|
| `https://opengameart.org/sites/default/files/Animal%20Pack%20Vol.2%20by%20%40Quaternius.zip` | 2,069,972 | `6d8f6789d65dbdb352ebad98a4209f26b41b384e87d81bc05e9ca76139db1248` |
| `Animal Pack Vol.2 by @Quaternius/Blends/Cat.blend` | 813,748 | `e9836027dc8591fd2da03e6d8d6575972bc5c7aebaa17a0762b82f7bc37264de` |

`scripts/cat-inputs.json` pins the source; `prepare-cat.py` verifies the archive/member before use. Trusted Blender opens the blend with source scripts disabled. `blender-prepare-cat.py` captures evaluated source IK poses before removing authoring constraints and assigns explicit bone aliases for the project support adapter. The aliases are an authored integration contract, not recovered Third Dawn names or a new UO archive identity.

The source supplies **Idle and Walking only**. The recipe retains both and separately authors **Run, Gallop, Attack, Attack2, Hit, Eat, Fidget, Alert and Death**. Runtime LieDown still copies Death, and Death2 reuses Death; neither is a new rest/death choreography. The action ledger identifies that runtime lying copy explicitly. Two measured source leg segments plus the original paw joints support running; bone lengths and paw orientations are retained. The source's already extended hind rest paws are not treated as the centre of a running stride. Feeding lowers the actual muzzle; death collapses onto the side with actual-skin floor correction. No original UO choreography, complete mode/subaction recovery or autonomous AI certification is claimed.

The optional source comparison has 807 triangles. The refined body, six bone-weighted eye/iris/pupil details and twelve toe volumes total **6,006 triangles**, with all 24 original bones. Eye centres are recessed against ray intersections with the actual head surface, avoiding floating cheek spheres. Rest-space subdivision interpolates original UV-free skin assignments; up to six influences occur, and the export/import retains eight rather than silently truncating to four. All actual material surfaces participate in deformation and terrain tests. The presentation scale is 0.1: the standing head is approximately 0.27 m high and the upright tail about 0.45 m.

The source's Grey/White/Pink colours are read from its legacy Diffuse BSDF nodes; `Material.diffuse_color` is a default value and loses the original regions. The modern shader preserves those regions, adds an authored procedural coat and matte response, and keeps fixed gold/dark eye materials. This is not a photographic fur atlas or hair simulation. Full hues tint the body; partial hues protect white paws/chest and pink features. Eye colour remains fixed in both modes. The original UO partial-hue mask has not been recovered.

## Physical locomotion and support

The authored bound has two timings: a 0.18 m stance over 0.1 seconds at **1.8 m/s**, and a shorter stance at **6.8 m/s**. All actual exported limb lengths are tested, rather than allowing a stride to stretch the rig. Short gallop stance requires 240 Hz export/import and per-AnimationPlayer key optimization/compression disabled. Default Godot optimization caused an observed 8.7 mm paw penetration despite a correct Blender pose; preserving the keys fixes the imported skin. See [Godot's animation import optimizer documentation](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/advanced_import_settings.html).

Optional per-record locomotion metadata selects the preserved slow walk around its measured 0.192 m/s reference, the authored bound at 1.8 m/s and the gallop at 6.8 m/s. Existing creatures retain their previous thresholds, references and rate limits. For this small animal, a native walk packet presented at the client adapter's 1.8 m/s uses the bound, while a running packet at 6.8 m/s uses Gallop. The native flags and coordinates remain unchanged. Explicit classic action group 0 still reaches Walk, group 1 reaches Run and the other animal groups retain their declared action routes. Gallop loops explicitly instead of freezing after one short cycle.

The native harness now carries the declared gait expectations into its generated allow-list, preserving Walk/Run defaults for other records. The first Cat run failed because the fixture omitted this metadata; the corrected test passed without changing native gameplay. This does not certify that every world movement timing matches these two adapter reference speeds.

Cat's paws live on a different material surface from its torso. `CatGroundSupport.gd` merges only their CPU reference arrays, retaining all eight influences; the visible model remains one six-surface mesh. It measures four separately weighted soles and fits standing paws while preserving lifted swing paws. The larger animals' 16 cm support threshold would drag this cat's few-centimetre swing to the ground, so the cat has its own 8–24 mm transition. Native entity transforms remain outside the presentation adjustment. Small pick/camera bounds and the actual animated skull determine interaction and nameplate anchors.

## Focused evidence

- **1,974 motion checks / zero failures**, with **438 complete source/refined skin samples**. Actual imported stance speeds measure approximately **1.8000 / 6.8000 m/s**; bone lengths, normalized eight-influence weights, finite poses, feeding nose, loop closure and side-collapse bounds pass.
- **303 Forward+ presentation checks / zero failures**: real avatar, six material surfaces, fixed eye colours, native full/partial hue updates, coat/roughness response, measured interaction/camera/nameplate anchors, naturally continuing gallop, animal action routes and three static corpse hues.
- **30 finite terrain cases** across Idle/Walk/Eat/Run/Gallop, two facings and three raised/lowered flat/sloped planes. Standing paws stay within approximately **3.5 mm**, feeding paws **1.2 mm**; **24 actual lifted-paw cases** retain approximately **47–61 mm** clearance rather than being planted. These are bounded configured-plane tests, not arbitrary obstacle/crowd certification.
- **110 actual isolated-server/two-client checks / zero failures** for the real native Cat constructor on both test characters. Native movement flags/coordinates, declared speed-adapted gaits, hues, native hurt/actions, death and **0x2006 / amount 201** static corpse replication pass. Controlled fixture AI is frozen; taming and autonomous behaviour are outside this test.

Installed-public evidence repeats **303 Forward+ checks** and **110 actual native two-client checks**, and `test-cat-distribution.py` passes **477 clean checks** without private art, source imports, original game inputs or a server. The existing rat control passes **186 GPU / 110 native checks**, retaining its prior default gaits. The source-only cat check measures 219 complete six-surface skin poses, all declared clips, normalized eight-influence weights, physical-speed selection and its grounded static cadaver.

Final focused stage logs: `work/creatures/animals-vol2/prepare-cat-inset.log`, `cat-motion-final.log`, `cat-presentation-final.log` and `cat-native-stage-final.log`. Public/control logs: `cat-public-gpu.log`, `cat-native-public-final.log`, `cat-rat-gpu-control.log`, `cat-rat-native-control.log` and `cat-distribution.log`. Earlier failed shape, key-optimization and fixture probes remain local, clearly separate from passing evidence. The 38 accepted local source groups / 103 forms pass current receipt acceptance: 71,456 pose checks / 21,567 skin samples, 1,435 fresh standard GPU checks / 618 views and focused gesture gates. All 169 corpse variants pass 1,582 fresh rendered checks. Full `scripts/verify.ps1` exits 0 without script errors, including the new source-only cat check, 71 server-extension / 84 client developer-edit checks and clean final world startup. Existing Unicode/teardown diagnostics and two nullable compiler warnings in unchanged PreviewTools tests remain. Logs: `cat-shared-regression.log`, `cat-full-verify.log` and final installed-route `cat-public-corpses.log`.

Bounded native evidence reaches **137/279 tracked bodies (49.1%)**; 103 local forms plus five independent public forms give 108 generic records / 132 routes. Generic protocol connectivity reaches **2,310/3,108 (74.3%, including reuse)**, with 798 tracked slots missing; positive named body/constructor evidence reaches 118 pairs, with no complete class denominator claimed. Human action groups and 732/1,126 wearables remain unchanged.

The action ledger additionally separates original metadata entries lacking a generic model from missing categories on already routed bodies. Of 3,003 original mode/type entries, 590 currently have an inferred generic route, 530 on routed bodies lack one, and 1,883 have no generic model. The combined 2,413 counter is **generic-renderer coverage only**: specialized human/mount presenters are separate, and these figures do not measure global missing animations or original choreography completion. Canonical group/frame precedence, mode/subaction fidelity and dynamic body identities remain further work.

## Reproduction and remaining scope

```powershell
python -B scripts/prepare-cat.py --verify-only
./.tools/blender/blender-5.2.1-windows-x64/blender.exe --background --factory-startup --disable-autoexec --python-exit-code 1 --python scripts/blender-prepare-cat.py
# Import Viewer, run ConfigureCatImports.gd, then reimport.
# Run CatMotionTests.gd in Forward+.
python -B scripts/prepare-cat.py --verify-only --candidate
# Run CatPresentationTests.gd against the candidate.
python -B scripts/prepare-cat.py --verify-only --stage
./scripts/test-horses.ps1 -Live -SkipContact -CreatureFamily cats
python -B scripts/prepare-cat.py --verify-only --install
# Repeat CatPresentationTests.gd -- --public and the native test.
python -B scripts/test-cat-distribution.py
./scripts/verify.ps1
```

The independent public bundle belongs under `Viewer/Art/Creatures/Cat/`, with its GLB, configured import sidecar, exact provenance and notice. It includes no UO geometry, maps, rigs or motions. Source blend/comparisons, test state and captures remain ignored. Cadavers join the existing graphics catalogue through the accepted native body; no invented static graphic ID is added.

The donor remains stylized and its face, coat, paws and gait transitions can improve further. Final anatomy, arbitrary terrain, all original modes/subactions and the full creature programme remain unfinished. Continue Eagle body 5 next, then the configured occurrence queue. Preserve human/equine/llama work, production/saves and concurrent terrain/building changes.
