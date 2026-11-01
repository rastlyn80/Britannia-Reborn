# AirElemental, SummonedAirElemental and CrystalVortex

Native body 13 has an independent cloud/vortex replacement, retained CC0 rig/actions, full/partial native hues, terrain-relative support and a dry-dust static corpse. ModernUO remains authoritative for identity, movement, actions, summoning and death. This is bounded integration evidence; original choreography, original particle simulation and final visual quality remain incomplete.

## Independent public asset

`Viewer/Art/Creatures/Air/air-elemental.scn` contains 7,825 vertices, 14,016 triangles, a retained 65-bone rig and fifteen saved action categories. `AirCloudGeometry.gd` authors twenty overlapping ellipsoid cloud puffs and a tapered vortex. It replaces the carrier's body mesh completely. The dry-dust footprint reuses the project's original radial Puddle geometry from the independently licensed Water carrier; this is explicitly retained project geometry, not a recovered original UO effect.

The carrier is `Viewer/Art/Creatures/Water/water-elemental.scn`, SHA256 `6b0856ae574b5571cbd79cb2682a0904ce1cb59a54da24f51b9e4d29b7e49bd8`. Its rig and UAL1 motions are Quaternius CC0-1.0 inputs, with exact source hashes and carrier recipe recorded in Air's `provenance.json` and Water's source history. Sources: [Universal Base Characters](https://quaternius.itch.io/universal-base-characters), [Universal Animation Library](https://quaternius.itch.io/universal-animation-library). New cloud geometry, shaders and conversion code are original GPL-3.0-or-later project work. No original human/Water body mesh, UO mesh, atlas, rig or clip is inside the public scene.

Non-death categories retain the carrier's source joint poses; measured maximum translation difference is zero, with matching sampled rotations. Death/Death2 are explicitly authored uniform wind dissipation and settling dust, not recovered source motion. Runtime additionally supplies its existing synthesized Eat and Death-copy LieDown compatibility poses; those are not extra unique recovered clips. The preparation's historical phrase "no water geometry retained" in non-death clip metadata refers to the replaced body; the dry radial footprint is retained as described above.

`AirElementalSurface.gdshader` uses explicit cyclic animation phase, with no free-running shader clock. The cloud displacement is bounded below the measured 50 mm envelope margin. Synchronous final-Death seeks update the material before corpse freezing. The final cadaver contains one visible dust surface and no live skeleton, hidden cloud or original marker.

Full and partial raw hue values remain authoritative. Partial tint uses authored dense-cloud regions, not a recovered UO mask. Native spectral value `0x4001` retains its bits and default wind appearance instead of accidentally becoming ordinary dye one. Ground anchoring changes the visual offset, not native entity coordinates. Nameplates follow the highest relevant animated head/arm landmark; conservative selection bounds include the visual offset.

## Original Third Dawn evidence stays private

The preserved archive `work/third-dawn/uotdb.zip` has SHA256 `d872d59a4d3f92c82672bbadb98ae44772e42b44dacb4a28a1fdf39cf121dc0e`.

| Member | SHA256 |
| --- | --- |
| `uotdb/uotd/Models/Monsters/elementals_air_elemental_lod2.grn` | `c49be74adda6058b934d3775bbe294127276dd06a0b495b775c3711d7ce43111` |
| `uotdb/uotd/Particles/air_sparkle1.tga` | `69e43bcd9507bc38bfa05c8e1761c7bdb4faaeefcce978a576fbd93a3f5a4765` |

The named mesh is only four vertices/two triangles and a two-bone `__root`/`death_mote` hierarchy, with zero vertex skin weights. Declared rigid object/tie mapping binds it to bone 1. The dedicated rigid importer preserves that quad, UVs and hierarchy as an optional private marker, using a labelled 0.2 m inspection scale. No original animation is recovered for this marker. The opaque-black source atlas is displayed additively during an explicitly authored death cue; original blend mode, timing and particle-to-actor binding are unproven.

The bounded source audit found `Air_sparkle1` references in particle files 5019, 5023 and 5044. Texture references alone do not prove actor binding or effect semantics. The private marker lives at `Viewer/local-art/air/source-marker.gltf`, outside the public model, is excluded from corpse freezing and is optional at runtime. Original inputs, generated source-derived files, prompts and screenshots remain ignored. The public model loads and works without any of them.

## Focused evidence

| Gate | Result |
| --- | --- |
| Saved topology, weights, retained poses and complete skins | 54,004 checks / 255 complete skins; zero failures |
| Actual installed-public avatar, colours, bounds, death and finite planes | 544 checks / 72 raised/lowered flat/sloped poses; zero failures |
| Actual two-client native constructors/actions/death | 462 checks / six body/class/owner records; zero failures |
| Clean source-only distribution | 293 checks / 136 complete cloud/dust samples; zero failures |
| All accepted local source groups | 40 groups / 105 forms; 72,692 current pose checks / 21,945 complete skins; 1,461 fresh standard GPU checks / 630 views |
| Whole rendered static corpse catalogue | 176 variants / 1,659 checks; zero failures |

Full `scripts/verify.ps1` exits 0 with no script errors and clean final world startup, 71 server-extension tests and 84 developer-edit client tests. Existing Unicode/teardown diagnostics and two nullable warnings in unchanged PreviewTools tests remain. Shared/full logs: `work/creatures/air/{shared-regression,full-verify}.log`; corpse log: `work/creature-checks/corpses.log`.

The refreshed bounded catalogue reports 144/279 tested native bodies (51.6%), 129 positive named body/constructor pairs, 114 generic model records / 138 routes and 2,423/3,252 connected generic slots (74.5%, including reuse), with 829 missing. Original metadata remains separate: 630/3,003 inferred generic routes, 560 category misses on routed bodies and 1,813 entries without a generic model. Specialized human/mount presenters are separate; no overall original-choreography/final-art completion percentage is claimed.

The GPU gate measures occupied pixels against projected complete skin bounds plus the shader margin, verifies visible source-marker pixels separately, and checks an actual rendered final corpse. Final corpse dimensions match the posed final Death within 1 mm; the dust occupies rendered pixels and remains unchanged in later frames. Spectral/default/full/partial cases and raw identity bits are covered.

Native tests instantiate AirElemental, SummonedAirElemental and CrystalVortex on both disposable clients. SummonedAirElemental uses ModernUO's own `BaseCreature.Summon` API, with a real master, follower accounting, summon lifetime and native corpse suppression. Both other constructors retain their native corpses. No game/core logic was changed. Actual world entry, native Mobile.Move, action/hurt/death packets, identity and corpse replication are exercised; AI is frozen for controlled sampling. These are not autonomous AI/combat, taming or complete gameplay tests. Production port 2593, accounts and saves remain untouched.

The clean project copies only the owned source dependency closure, public index and Air folder. Private art, original game data, the Water carrier itself, Quaternius source files and server are absent. It loads the actual avatar, all fifteen saved and two synthesized categories, complete cloud/dust geometry, native colour flags and the one-surface static corpse.

## Reproduction

1. Use the pinned independent Water carrier; run Godot headless with `res://Presentation/PrepareAirElemental.gd`, then `res://Presentation/AirElementalMotionTests.gd`.
2. Run `python -B scripts/prepare-air-elemental.py --candidate`, then the actual Forward+ `res://Presentation/AirElementalPresentationTests.gd` candidate gate. To reproduce the separate preserved-source comparison, run `python -B scripts/prepare-air-marker.py` against the pinned local archive and copy its embedded-image `work/creatures/air/original-marker.gltf` to `Viewer/local-art/air/source-marker.gltf`. The private marker is an optional runtime input, never part of the scene recipe; the pre-publication comparison gate requires it.
3. Run `python -B scripts/prepare-air-elemental.py --stage`, then `scripts/test-horses.ps1 -Live -SkipContact -CreatureFamily air` against disposable loopback 2594.
4. Run `python -B scripts/prepare-air-elemental.py --install`, repeat the presentation gate with `-- --public`, repeat the native test, then `--verify-public`. Gates reject stale geometry, shaders, runtime sources or mismatching native identities/state.
5. Run `python -B scripts/test-air-distribution.py`, all accepted local creature groups, the rendered corpse catalogue and `scripts/verify.ps1`. The full verifier includes the clean Air distribution gate.

Focused receipts are under `outputs/creatures/air-trial/{motion,presentation}.json` and `outputs/creatures/air/live.json`; logs under `work/creatures/air/`. Shared/full regression outcomes and current coverage are recorded in PROGRESS.md and ROADMAP.md. Final anatomy/material polish, exact original particles/choreography/masks, arbitrary terrain and all remaining creature identities remain active work. Continue Ghoul/Bogle, Gorilla and HeadlessOne in occurrence order without routine approval stops.
