# Eagle body 5

The independent eagle replacement includes a refined mesh, preserved donor rig/flight, authored grounded and airborne actions, native hues and a static corpse. It uses Quaternius's [Animated Animals Vol.2, published under CC0](https://opengameart.org/node/78596). No original Ultima Online art is included in the public bundle.

## Source and transformation

Exact inputs are pinned in `scripts/eagle-inputs.json` and the public `Viewer/Art/Creatures/Eagle/provenance.json`:

| Input | Exact identifier |
| --- | --- |
| Archive | `https://opengameart.org/sites/default/files/Animal%20Pack%20Vol.2%20by%20%40Quaternius.zip` |
| Archive SHA256 | `6d8f6789d65dbdb352ebad98a4209f26b41b384e87d81bc05e9ca76139db1248` |
| Member | `Animal Pack Vol.2 by @Quaternius/Blends/Eagle.blend` |
| Member SHA256 | `ca9d09c805d51d0df063bd25ebe3f85bc67b4e2ecc2fef174aa72f29b85e9e93` |

The source cage has 1,532 triangles and 24 bones. The source object's offset is normalized while preserving its mesh-to-rig bind transform. The donor subdivision modifier is removed before measurements/export; the modern cage receives one explicitly applied subdivision and six head-weighted eye/iris/pupil pieces. The resulting 7,544-triangle model retains all source bones, their asymmetric wing hierarchy and up to eight skin influences.

The donor's `Idle` is an airborne idle with hanging wings, not landed art. `AirIdle` and `Fly` preserve evaluated donor motion/timing. Seventeen grounded/action/airborne variations are authored, and `Run` adapts Flying with a declared 14/120-second closing interval. The twenty exported categories are not twenty original UO animations. The private source comparison uses the original cage; only its two donor clips are source animation, and its other categories are explicitly authored too.

Perched wings use an authored, coherent compressed feather fan instead of alternating 180-degree bends that collapse the donor's blended panels. Additional wing/tail closing supports the cadaver. This is not recovered anatomy or feather simulation. Flight retains the full donor span, with a constant clearance measured over the complete donor cycles; the current lowest feather never drives per-frame torso height.

The donor has no UV atlas. A matte procedural feather shader preserves its four material regions, with fixed gold/dark eye surfaces. Full dye tints body regions; partial dye protects white head/tail and yellow beak/feet. This is an authored mask, not original UO mask recovery or photographic feather texturing.

## Runtime and native identity

ModernUO's pinned `Eagle.cs` constructs body 5, and `Distribution/Data/bodyTable.cfg` classifies it as Animal. Its `CanFly` property does not establish an animation packet or authorize changing server Flying state. Low flight is explicitly inferred presentation for movement. Native coordinates, running flags, body, hue and statistics remain authoritative.

The actual avatar plays TakeOff before looping flight and Land before perched Idle. Native walking/running both use the low-flight replacement at their received speeds. Explicit animal group 0 retains the authored short wing-assisted hop. Airborne hit/attack/death variations preserve flight height; feeding/fidgets/rest queue landing first. `current_clip` identifies the native replacement category, while `assigned_animation` and `rendered_action_clip` expose the actual airborne/transition clip.

The corpse uses native graphic `0x2006`, amount/body `5`, and is automatically included in the existing graphics catalogue. Both grounded and airborne deaths end at the same static geometry and floor height. No synthetic corpse graphic ID is introduced.

## Evidence

Final focused results are local under `work/creatures/animals-vol2/`:

| Check | Result |
| --- | --- |
| Imported source/refined motion | 3,865 checks, 1,000 complete seven/four-surface skin samples, zero failures |
| Installed public Forward+ presentation | 129 checks, 18 raised/lowered flat/sloped terrain cases, zero failures |
| Actual native server | 112 checks on two disposable characters; installed public repeat also passes |
| Clean public distribution | 1,128 checks without local art, donor inputs or a server |
| Cat control | 303 rendered checks; 110 actual native checks |
| Existing local groups | 38 groups / 103 forms; 71,456 current pose checks / 21,567 skins and 1,435 fresh standard GPU checks / 618 views |
| Whole corpse catalogue | 170 variants / 1,597 fresh rendered checks |

Full `scripts/verify.ps1` exits 0 with no script errors, 71 server-extension checks, 84 client developer-edit checks and clean final world startup. Existing teardown/Unicode diagnostics and two nullable warnings in unchanged PreviewTools tests remain. Final focused logs are `eagle-motion-final.log`, `eagle-public-presentation.log`, `eagle-native-public-final.log`, `eagle-distribution.log`, `eagle-shared-regression.log`, `eagle-public-corpses.log`, `eagle-cat-control.log`, `eagle-cat-native-control.log` and `eagle-full-verify.log`.

Actual standing claws are within 0.97 mm of the flat plane; the feeding beak reaches approximately 54 mm. The measured flight span is about 1.87 m, with perched width about 0.32 m. Final corpse height is 0.213 m; airborne and static bounds agree within the 1 mm gate. Tests inspect all material surfaces and skin influences, not only the first mesh surface.

Private/public native checks use an authorized disposable ModernUO server and genuine constructors, Move, hue, hit/action and death/corpse packets replicated to two clients. AI is frozen for controlled sampling. These are not autonomous AI, taming or complete gameplay certification. Production and its accounts/saves are untouched.

Native fixtures follow the renderer's validated last-record-wins precedence: a local revision of a public body creates one fixture. Two isolated real-source CLI cases prove public/private precedence and rejection of an unvalidated override without changing the canonical registry.

## Reproduction

From the repository root, acquire/verify inputs with `python -B scripts/prepare-eagle.py`, then run trusted Blender with `--background --factory-startup --disable-autoexec --python-exit-code 1 --python scripts/blender-prepare-eagle.py`. Original blend scripts stay disabled. All original inputs, source comparisons and captures remain under ignored local folders.

Import Viewer with the repository's Godot console, run `res://Presentation/ConfigureEagleImports.gd`, and reimport. This sets 120 Hz animation imports and disables per-asset key optimization/compression. Run `EagleMotionTests.gd`, `python -B scripts/prepare-eagle.py --verify-only --candidate`, then `EaglePresentationTests.gd` with Forward+.

After successful trial evidence, `--stage` enables the private candidate for `scripts/test-horses.ps1 -Live -SkipContact -CreatureFamily eagles`. `--install` copies only the independent public model/notices/provenance and removes the private route. Repeat `EaglePresentationTests.gd -- --public`, the native command, and `python -B scripts/test-eagle-distribution.py`. Finish with `scripts/verify.ps1` and `scripts/build-corpse-catalogue.ps1 -Render`.

The independent public GLB, import sidecar, notice and provenance ship with the client. Original UO inputs, derived zombie trials, source comparisons, screenshots, tools/caches and saves remain excluded. Remaining work includes final art/anatomy refinement, arbitrary obstacles/terrain, original choreography/extended modes and broader native identities. The eagle's movement-derived visual flight is not proof of server flight-state parity.
