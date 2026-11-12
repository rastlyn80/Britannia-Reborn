# Bogling: independent tree-creature replacement

Native ModernUO body **779** uses an independent licensed tree-creature model, with its donor rig and motions, calibrated new gaits, native colours, terrain contact and a matching static corpse. This is an explicitly labelled substitute: the inspected pinned Third Dawn archive has no matching named Bogling mesh/table row. No recovered UO mesh or original UO choreography is claimed.

## Source and licence

Author: **Tennessippi**. [Official Free Treant Pack](https://tennessippistudios.itch.io/treant-pack) explicitly declares CC0, supplies two rigged FBX models and ten motions, and lists 2048-square diffuse/normal maps. Tree02 is the shorter, stockier donor. Source mesh, rig, maps and ten motions remain CC0; original project conversion, new motions and shaders are GPL-3.0-or-later.

- Official download filename: `Treant Package.7z`; local archive: `work/creatures/bogling/source/Treant-Package.7z`.
- Archive: 46,456,071 bytes; SHA256 `1fcddcbd1fbbc8ec84f6001b2192d22794a927c9be2a929457a537e908862cd8`.
- Exact FBX/albedo/normal file names, lengths and SHA256: `scripts/bogling-inputs.json`.
- Inspected signatures: FBX `Kaydara FBX Binary`, version 7400; albedo PNG `89504e470d0a1a0a`, 2048-square RGB8 with no alpha; public GLB `glTF`, version 2, 10,821,792 bytes, SHA256 `8a9c88b8ca649bf43bfcf9bc697682356739a14fdef32f8fc14d0fddb0468c68`.
- Download used the author's zero-price option, upload 4907296. Anonymous session/CSRF tokens and expiring download URLs remain private. There is no permanent archive URL asserted here.
- Built-in Windows `tar` statically extracted the archive. No downloaded executable or archive script ran. Trusted Blender 5.2.1 imports the FBX with automatic execution disabled.

The public package is `Viewer/Art/Creatures/Bogling/`: converted GLB, import settings, artist maps, NOTICE and exact provenance. The model contains its maps, and the clean-install check copies only GLB/import/NOTICE/provenance before import. Neither the source archive/FBX nor private client art is required. Godot may extract its embedded textures during import. No game mesh, texture, rig or animation is included.

## Conversion and motion

Tree02 retains 33 bones, 3,672 source vertices and 7,340 triangles. Face triangulation preserves source points/UVs; no subdivision is needed. Idle height is 1.15 m. A common internal ancestor corrects negative complete-skin penetration while retaining positive source clearance.

All ten donor actions remain separate: Idle, three attacks, three deaths, SourceRun, Dance and Fidget. The project adds Walk, Run, Cast, Pillage and Hit. Runtime also supplies its labelled Eat/LieDown compatibility categories: **17 runtime categories**, not 17 recovered source clips. Feeding compatibility is not a new native feeding choreography. Non-looping Taunt/Dance are not forced into seamless loops.

New gaits retain the source upper-body motion, solve fixed-length legs and keep planted feet travelling backwards at 1.8 m/s walking and 5.5 m/s running. Runtime adjusts those reference rates to server movement speed. Constant gait lowering keeps both limbs within reach; swing feet lift naturally. Original SourceRun remains available separately.

Three source vertices exceed eight influences. A nonnegative, sum-preserving fit across all evaluated clips replaces naive truncation; its fitting-stage maximum is below 0.001 mm. The independent original-FBX/imported-skin comparison below measures the actual conversion rather than treating that fitting result as whole-model proof. Baking and import both use 240 Hz, with animation optimization/compression disabled: the default 30 Hz import caused measurable stance-speed errors.

The shader binds the original dark albedo and actual normal map, normal strength 0.65, roughness 0.9 and zero metal. Full native hues colour the body; an explicitly authored brown-bark selection protects green ivy under partial hues. This is not a recovered UO partial-colour mask. Weighted-bone envelopes keep nameplates and selection above/around animated branches. Two measured eight-weight soles preserve lift and limb lengths on finite planes. No native entity coordinates change.

## Evidence

| Focused gate | Result |
| --- | --- |
| Actual imported normalized skins, source normal map, fixed real sole velocities and gait closure | 38,226 checks; zero failures |
| Independent original-FBX full-influence skins versus imported eight-weight surfaces | 341 checks / 170 complete skins; zero failures; maximum bidirectional surface difference 0.120 mm |
| Installed-public avatar, normal-map lighting, hues, full action bounds, terrain and corpse | 2,295 checks / 289 complete action skins / 156 terrain poses; zero failures |
| Native Bogling constructor, two disposable clients, movement/actions/hues/death/corpse | 160 checks; zero failures, repeated on installed public route |
| Clean distribution without donor/private art/game palette/server | 473 checks / 153 complete action skins; zero failures |
| Existing public AirElemental control with the current registry | 544 Forward+ checks / 72 planes and 462 real native checks; zero failures |

Actual planted sole gaps stay below 1.94 mm in the measured cases; 90 lifted-foot and 210 planted-foot cases are covered. The original normal map changes 14,807 sampled rendered pixels. Full and partial dyes each change visible pixels and remain distinct. The surface comparison checks both directions over complete point clouds, not per-vertex identity. Native fixtures freeze AI for controlled sampling; these are real native movement/action/death tests, not autonomous combat/taming/gameplay certification.

Local receipts and renders: `outputs/creatures/bogling-trial/`; native records: `outputs/creatures/boglings/live.json`. Logs: `work/creatures/bogling/{prepare-canonical,motion-public,source-public,presentation-public,native-public,distribution,shared-regression,full-verify}.log`. Shared/root results and updated whole-catalogue totals are recorded in the current progress entry after those gates finish.

## Reproduce

1. Obtain the author's free archive from the official page; verify its hash above. Extract into `work/creatures/bogling/source/extracted/` and retain the `Treant Package/Treant 2/` directory. Run `python scripts/prepare-bogling.py --verify-inputs`.
2. Run the trusted Blender executable with `--background --factory-startup --disable-autoexec --python-exit-code 1 --python scripts/blender-prepare-bogling.py`, then the same flags with `scripts/blender-reference-bogling.py`. Check both exit codes.
3. Run `python scripts/prepare-bogling.py --candidate`. Import `Viewer` using the pinned Godot editor, run `python scripts/prepare-bogling.py --configure-imports`, then reimport. This preserves 240 Hz and precise skins/animation.
4. Run Godot `--headless --path Viewer --script res://Presentation/BoglingMotionTests.gd`, then `BoglingSourceTests.gd`; run `BoglingPresentationTests.gd` with rendering enabled. Current public routes take precedence over the local candidate.
5. On a first installation only, `--stage` on the preparation script requires current candidate evidence; `scripts/test-horses.ps1 -Live -SkipContact -CreatureFamily boglings` uses a disposable loopback2594 server. Production2593, accounts and saves are excluded. `--install` requires native proof. Import/configure/reimport the public asset and repeat the actual public tests, native test and `python scripts/test-bogling-distribution.py`; finish with `python scripts/prepare-bogling.py --verify-public`.
6. Run the accepted local creature groups through `scripts/test-creatures.ps1`, the rendered whole corpse catalogue and `scripts/verify.ps1`. Never replace current evidence with stale receipts.

The shipped package can be tested by `scripts/verify.ps1` without original source inputs; the source-comparison tests additionally require the pinned donor. Remaining gaps include final art/anatomy polish, original UO choreography/masks, arbitrary terrain, autonomous native gameplay, six unsupported generic extended action slots and separate unimplemented plant bodies such as BogThing780. No overall creature-port completion is claimed.


## Tread contact and displayed collapse

Body 779 keeps the licensed eight-influence bark rig. Each foot now checks its own tread from the skinned sole before the complete body receives any remaining vertical correction. The same native anchor supports the neck and branch gestures. On the 22 cm step, the largest sampled run correction fell from 298 mm with the initial whole-body correction to 219 mm with the local foot solve. It remains visible on the highest step.

The tested client cleared 6,944 Classic and 7,812 Enhanced living poses. Decoded death preserved the displayed pose across 72 Classic and 88 Enhanced handoffs. The Enhanced checks include the fitted Sprout and Branch Alert. Isolated native runs passed 46 Classic and 50 Enhanced checks, including movement after an idle packet, stock action packets, constructor and custom hues and a static body-779 corpse. The native corpse held four logs and a seed.
