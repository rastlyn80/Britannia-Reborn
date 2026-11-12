# FireElemental and SummonedFireElemental

Native body15 uses original project flame-ribbon geometry and a procedural fire/ash shader on a retained independently licensed rig. It preserves separate ordinary and summoned server identities, native colours, actions, finite-plane support, selection/nameplates and static ash for ordinary corpses. Summoned actors use ModernUO's actual summoning API and retain native corpse suppression. The pinned Third Dawn archive contains no matching named fire GRN; no recovered original particle binding or original UO choreography is claimed.

## Source and licence

The carrier is the existing public `Viewer/Art/Creatures/Water/water-elemental.scn`, SHA256 `6b0856ae574b5571cbd79cb2682a0904ce1cb59a54da24f51b9e4d29b7e49bd8`. Its original source notices/pins remain in `Viewer/Art/Creatures/Water/NOTICE.txt` and `provenance.json`. The retained rig and selected UAL1 actions originate with Quaternius under CC0: [Universal Base Characters](https://quaternius.itch.io/universal-base-characters) and [Universal Animation Library](https://quaternius.itch.io/universal-animation-library).

`FireFlameGeometry.gd` replaces the carrier body entirely with original crossed ribbons:1,836 vertices /1,632 triangles on65 bones. No human or Water body mesh remains. The existing project-authored radial footprint becomes ash. Geometry, shader, conversion and authored death are GPL-3.0-or-later, with the retained rig/motion CC0 exception. No additional downloaded executable, paid asset, game texture, original rig or original clip is included.

The self-contained public scene is `Viewer/Art/Creatures/Fire/fire-elemental.scn`, with NOTICE and exact source/preparation provenance. It loads without the carrier model, original source files, private art or server. Renderer source and shaders are included with the client. Original client inputs and local test captures stay ignored.

## Presentation

Fifteen saved categories retain selected carrier motions and explicitly authored flame dissipation/ash. Runtime adds labelled Eat/LieDown compatibility poses; these are not additional recovered native animations. Skeletal action phase also drives the procedural shader. No `TIME` clock or independent flicker timer is used, so seeking the final Death freezes exactly the final appearance.

Each flame component uses one material override. A per-surface override version produced a reproducible null-material warning in Godot's headless renderer during temporary death cleanup. The component override removes it without changing the shader or colour behaviour. Clean-distribution tests repeat four actual `CreatureDeaths` transitions and reject renderer errors.

Full native hues recolour fire and ash; partial hues use smooth authored hot-core and inner-ash regions. These are not recovered UO masks. Native body/hue/partial bits remain unchanged. An8cm shader-displacement envelope contains actual rendered flame pixels. Cached weighted-bone boxes follow all visible action skins, giving conservative selection and upper nameplates. Hover support changes only model elevation relative to finite sampled planes; authoritative entity coordinates remain untouched. Arbitrary terrain, overlapping floors and final lighting remain open.

## Focused evidence

| Gate | Result |
| --- | --- |
| Saved scene and retained non-death carrier joint centres |14,623 checks /255 complete ribbon skins; zero failures |
| Installed-public actual avatar, colours, phases, complete actions, terrain and corpse |1,416 checks /289 complete action skins /72 finite-plane poses; zero failures |
| Real two-client ordinary constructor and summoned actor |308 checks /four class-owner records; zero failures, repeated after the material fix and on the public route |
| Clean independent distribution and transient death cleanup |291 checks /136 component-skin samples /four temporary death lifecycles; zero failures |

The private procedural trial additionally passes152 actual Forward+ checks across75 rendered states, with visible motion, zero changed pixels after a full shader cycle, visible final ash and no pixels outside the declared displaced-skin envelope. The actual avatar gate checks default/full/partial corpse colours remain visibly distinct, final Death and static ash dimensions agree within1mm, final shader phase equalsTAU and subsequent corpse frames remain unchanged.

The native harness calls `BaseCreature.Summon` for SummonedFireElemental, establishing the real master, follower accounting, lifetime and summon state. Both owners exercise the ordinary and summoned classes. Native death suppresses the summoned corpse; the client does not invent a persistent ash item. AI is frozen for controlled sampling. Autonomous combat, spellcasting and complete gameplay are not certified. Existing production runtime/accounts/saves are excluded from these disposable loopback2594 tests; no game/core edit was made.

Current local receipts/renders: `outputs/creatures/fire-trial/`; native records: `outputs/creatures/fire/live.json`. Logs: `work/creatures/fire/{prepare-canonical,motion-canonical,presentation-public,native-public-fire,distribution,shared-regression,full-verify}.log`. The current progress entry records final whole-catalogue/shared/root results after those gates finish.

## Reproduce

1. Use the pinned Godot executable with `--headless --path Viewer --script res://Presentation/PrepareFireElemental.gd`, followed by `FireElementalMotionTests.gd`. Run `python scripts/prepare-fire-elemental.py --candidate`.
2. Run `FireElementalPresentationTests.gd` with rendering enabled. On a first installation only, `python scripts/prepare-fire-elemental.py --stage` requires current saved-scene and actual-avatar evidence.
3. Run `scripts/test-horses.ps1 -Live -SkipContact -CreatureFamily fire` against its disposable server. `python scripts/prepare-fire-elemental.py --install` requires actual constructor/summon/death evidence.
4. Repeat the rendered avatar test with `-- --public`, the native test and `python scripts/test-fire-distribution.py`. Run `python scripts/prepare-fire-elemental.py --verify-public`; it checks current source/runtime/scene hashes and exact native/distribution records.
5. Refresh affected Air/Bogling controls, run all accepted local creature groups and the rendered corpse catalogue, then `scripts/verify.ps1`. The normal verification includes the independent Fire package and transient-death regression without requiring the carrier model or game inputs in the clean project.

Remaining work includes unsupported generic action groups, original choreography/particle recovery, arbitrary terrain/overlapping floors, dynamic lighting and autonomous native gameplay. This is bounded integration evidence, not full creature-port completion or final visual polish.


## Split treads, flame phase and Fireball

The client measures the visible weighted flame ribbons and the rigid ash separately. The split-tread test accounts for the flame ripple around the tread edge. The 22 cm test found about 218 mm of vertical correction at the sharpest sampled moment of the Enhanced Kindle and Rise.

Both profiles retain the original authored flame-to-ash timing. The complete skin and ash tests passed 8,680 Classic and 9,548 Enhanced living samples, and 88 Classic and 104 Enhanced decoded corpse handoffs. The final ordinary corpse keeps the static ash shape and native hue. The summoned elemental sends a native death packet and its short-lived corpse is removed in both clients.

The two disposable native runs passed 94 Classic and 102 Enhanced checks. They verified stock movement, dye, the presence of the native light, the Fireball target cursor and projectile, delayed damage, native sulfurous ash loot and the two fitted Enhanced gestures. The Enhanced gesture packets were controlled test inputs.
