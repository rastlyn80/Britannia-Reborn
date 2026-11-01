# Wisp and CrystalWisp: independent animated energy actor

Native Wisp and CrystalWisp share body **58 / 0x3A**. The installed replacement is original project geometry: a luminous core, a soft halo and six separately skinned rays. It contains **7 bones, 8,100 vertices, 4,480 triangles and 16 explicitly authored action categories**. The complete scene is reproducible from code, without a donor model, game texture, source archive or external service. This is an authored replacement, not recovered Third Dawn geometry or original choreography.

## Source evidence and licence

The inspected Third Dawn table names `ethereals_wisp` for bodies58/165, but no correspondingly named model was found in that archive. Private primary-MUL body58 reference frames show the luminous star form. Those frames and the bounded source audit stay ignored under `work/creatures/sea-horse/`; they are not included in the replacement. This absence does not prove absence from every historical client, or resolve the original particle engine.

`Viewer/Presentation/PrepareWisp.gd` analytically constructs the core/ray topology, binds and animation tracks. `WispSurface.gdshader` supplies the procedural light surface. Both are original GPL-3.0-or-later project work. The public package is `Viewer/Art/Creatures/Wisp/`, with `wisp.scn`, `NOTICE.txt` and exact recipe/shader/model hashes in `provenance.json`. It contains no third-party model or game-derived mesh, rig, texture or motion. Root `LICENSE` applies.

Pinned native declarations remain authoritative: `Projects/UOContent/Mobiles/Monsters/Misc/Magic/Wisp.cs` assigns body58; `Projects/UOContent/Mobiles/Monsters/ML/Prism of Light/CrystalWisp.cs` inherits it and sets hue `0x482`. `prepare-wisp.py --candidate` checks the server revision and exact declarations/hashes. Source body165 DarkWisp/ShadowWisp identities remain separate work; they acquire no route or native credit from this checkpoint.

## Geometry, animation and presentation

The two core shells and six rays remain actual skinned surfaces, with one normalized bone influence per vertex. Explicit rest-pose initialization retains the six distinct directions. Root position keys include the absolute 0.95 m rest height; omitting it initially lowered the entire effect. Both corrections were measured against the actual saved scene, not only the generator's intent. A three-axis extent check rejects coincident upward rays.

Authored categories are Idle, Walk, Run, Attack, Attack2, Attack3, Hit, Death, Death2, Fidget, Fidget2, Cast, Eat, Pillage, Alert and LieDown. Idle/Walk/Run loop; the remaining categories stop. Root rotation/height/scale and individual ray scales supply the motion. Runtime loop settings explicitly preserve this intent after the shared presenter initializes. These are declared authored variations, not claims of recovered source clips or complete individual original modes. Unsupported bow/crossbow/throw/Cast3/Fly/Land categories remain visible in the action ledger.

Full native hues tint the rendered energy. Authored partial hues protect the core and tint the six rays. Raw hue bits are preserved, including `0x8000`. Original game palette files are needed for their exact native colours; without those files the standalone package keeps its default colour and raw bindings. No recovered original partial mask is claimed.

Shader phase follows normalized animation position, rather than a free-running `TIME` clock. The [AnimationMixer `mixer_applied` signal](https://docs.godotengine.org/en/stable/classes/class_animationmixer.html) also updates the material after a synchronous final-Death seek. The static-corpse freezer snapshots the actual uniform values. Both material phase and rendered corpse pixels are checked for immobility.

Finite ray queries place the effect above the actual ground while native entity coordinates remain unchanged. Camera height is 1 m. The nameplate follows the actual upper ray; conservative measured pick bounds include the model's terrain offset. Tests cover raised/lowered flat and sloped planes at two orientations. They do not prove arbitrary terrain, ceilings, multi-floor selection, dynamic lighting propagation or final visual polish.

Native corpse graphic `0x2006` retains amount/body58, raw hue and victim facing. The spent light freezes all eight surfaces from the final Death pose, with no live rig, animator or shader clock. Real native corpse replication and the actual world-item presenter are exercised; a successful metadata record alone is insufficient.

## Focused verified evidence

| Check | Result |
| --- | --- |
| Saved authored model and complete skins | 1,586 checks / 1,408 complete skin samples; zero failures |
| Actual installed public avatar | 566 checks / 72 finite terrain poses; zero failures |
| Native Wisp and CrystalWisp | 314 checks on two clients, both classes for both owners; repeated after public installation |
| Clean public distribution | 676 checks / 512 complete skin samples; zero failures |
| Static corpse | Eight real frozen surfaces, final shape within 1 mm, visible rendered pixels and unchanged later image |

Final focused logs are under `work/creatures/wisp/`: `motion.log`, `presentation-public.log`, `native-public.log` and `distribution.log`. Receipts are `outputs/creatures/wisp-trial/{motion,presentation}.json` and `outputs/creatures/wisps/live.json`. Earlier missing-rest, parse and empty-emission experiments stay ignored and are superseded by the passing actual-model/presenter reports. Shared regression, complete corpse catalogue and root-verification outcomes are recorded in the current PROGRESS checkpoint.

The native test creates each real constructor for both disposable owners. It proves real world entry, native Move/run flags, full/partial hues, controlled action/hurt/death packets, corpse replication/facing and actual character/world-item presentation. AI is frozen for controlled sampling. Autonomous AI/combat, dynamic states, exact original particles/choreography and all classes sharing other Wisp body IDs remain unfinished. No production runtime, accounts or saves are used.

## Reproduction and remaining work

Run Godot with `--headless --path Viewer --script res://Presentation/PrepareWisp.gd`, then `WispMotionTests.gd` with Forward+. Run `python -B scripts/prepare-wisp.py --candidate` and `WispPresentationTests.gd`. Only fresh passing evidence permits `prepare-wisp.py --stage`. Run `scripts/test-horses.ps1 -Live -SkipContact -CreatureFamily wisps` against the authorised disposable loopback2594 server. Only proof of both constructors for both owners permits `prepare-wisp.py --install`.

Repeat `WispPresentationTests.gd -- --public`, the native test and `python -B scripts/test-wisp-distribution.py`; run `prepare-wisp.py --verify-public`, the shared accepted-local-group regression, rendered corpse catalogue and full `scripts/verify.ps1` before publishing. Public art is self-contained; the recipe, materials and tests are source-controlled. All original client inputs/reference frames and generated captures remain ignored.

Continue AirElemental13, then Ghoul/Gorilla/HeadlessOne and the configured occurrence queue. The original AirElemental source retains a four-vertex `death_mote` quad and `Air_sparkle1` material. A bounded audit finds that texture in particle files5019/5023/5044, but does not establish their actor binding or full semantics. Preserve those sources; do not mistake the quad or guessed particle numbers for a recovered full actor. The all-creature goal remains active.
