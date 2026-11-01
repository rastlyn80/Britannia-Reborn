# Snake, IceSnake and LavaSnake

Native body52 now reuses the retained Third Dawn giant-serpent design at18% scale. This is an explicitly authored small-snake assignment: the inspected pinned archive has no matching named small-snake mesh/table52 row. The existing body21 giant serpent remains unchanged. The native body classification is **animal**, verified against the pinned/runtime ModernUO body table, despite all three constructors using melee AI.

## Source and conversion

The donor is `serpents_snake_giant`, with its retained18-bone hierarchy, own UVs/atlas, compatible silver-serpent motions and existing refined treatment. [Original giant-serpent evidence](GIANT_SERPENTS.md) records that earlier source recovery and atlas work. This batch retains237 original triangles and3,792 refined triangles. Source meshes, skin bindings, accessors and original buffer bytes remain unchanged; a common scene ancestor supplies the0.18 scale. Local self-contained original/rounded/modern exports retain the existing source payloads; source geometry is not independently remeshed or rerigged.

`scripts/prepare-small-snakes.py` pins the three existing donor exports and the current native source files. The local preparation report includes exact archive members/hashes, original texture prompt/history, source-rig reuse contract, scale recipe and resulting asset/import hashes. All original game data, derived local models/maps and captures remain ignored. This batch publishes original project code/tests/evidence, not proprietary source artwork or a redistribution grant. The independently licensed Chicken work is separate and unaccepted.

The initial coiled modern skin measures approximately0.370m wide,0.111m high and0.409m deep; striking/uncoiling spans a larger volume. A fixed inherited selection box missed97/297 skin samples. An enlarged union still missed two off-grid samples. Weighted-bone envelopes now update nameplates and selection from the actual animated skin rather than a coiled rest box. The private holdout passed171 complete skins without misses, followed by the current170-sample actual-avatar action gate.

## Movement, colours and corpse

The scaled donor's original Run has little backward belly movement:the private observed median is0.072m/s, versus0.337m/s in Walk. Accelerating that old Run alone looked unsuitable. The active Walk remains intact; an authored fast slither reuses its curves at60% duration, while the former Run remains separately named **SourceRun**. Runtime reference rates use declared square-root size scaling, with a3.2 rate ceiling. Actual native walking1.8m/s and running6.8m/s select the intended clip/rate without clamping. This is an authored visual cadence, not recovered original UO timing or a no-slip physical simulation.

All three constructors retain body52 and their real hue policies:IceSnake uses0x480; LavaSnake selects0x647/0x650/0x659/0x662/0x66B/0x674; Snake uses `Utility.RandomSnakeHue`. The renderer preserves raw native full/partial flags; partial colouring remains the existing generic neutral-pixel heuristic, not a recovered original mask. No fake leg chains are added. Existing legless plane support retains the source mesh's grounded underside, and camera height matches the smaller visual.

Static corpses use native graphic0x2006 with body52 and the victim hue/facing. They freeze the actual final source Death pose, drop the live rig and are automatically included in the graphics-ID/corpse catalogue for future models as well.

## Focused evidence

| Gate | Result |
| --- | --- |
| Original/rounded/modern poses, normalized skins, timings and identities |682 checks /210 complete skins; zero failures |
| Actual dynamic envelopes and size-scaled gait selection |516 checks /170 off-grid complete skins; zero failures |
| Actual Forward+ avatar, full hues/partial bits, support and corpse |2,645 checks /432 terrain poses; zero failures |
| Native Snake/IceSnake/LavaSnake on both disposable owners |324 checks /six class-owner records; zero failures |

Measured underside gaps stay below5.11mm across the focused finite flat/sloped, raised/lowered and two-orientation cases. The native test exercises each actual constructor rather than treating a shared body as proof of every class. AI is frozen for controlled sampling; autonomous poison combat, taming and full gameplay are not certified. Production/accounts/saves remain excluded. No core/gameplay source was modified.

All43 accepted local groups/109 forms pass75,826 current pose checks/22,911 complete skins and1,512 fresh standard GPU checks/654 views plus focused gates. All182 corpse variants pass1,713 rendered checks. Current Air/Fire/Bogling public controls pass their actual-avatar, native and clean-distribution gates. Full `scripts/verify.ps1` exits0 without script errors, with71 server-extension/84 developer-edit tests and clean final world startup. Existing Unicode/teardown diagnostics and two nullable warnings in unchanged PreviewTools tests remain.

Bounded native bodies150/279(53.8%);139 positive named constructor pairs, without a complete class denominator. There are109 local plus11 independent public forms:120 generic records/144 routes. Connected generic animation slots2,548/3,402(74.9%,including reuse),854 missing. These are integration metrics, not original choreography/final visual polish or autonomous gameplay completion.

Local current receipts: `outputs/creatures/small_snakes/{validation,appearance,actions,live}.json` and `presentation/validation.json`. Logs: `work/creatures/small-snakes/{shared-regression,full-verify,presentation-final}.log`; whole rendered corpse evidence: `work/creature-checks/corpses.log`.

## Reproduce

1. Prepare and validate the existing giant-serpent inputs with the project's established source-first pipeline. Run `python scripts/prepare-small-snakes.py`; original body21 and its donor files must remain unchanged.
2. Import `Viewer`, run `python scripts/configure-creature-imports.py small_snakes`, then reimport. Small-snake imports use240Hz and disabled animation/mesh optimization/compression to keep the retimed floor correction coupled to the bones.
3. Run `scripts/test-creatures.ps1 -Families @('small_snakes')`. This exercises pose, full action-envelope/rate, actual rendered terrain/hue/corpse and ordinary GPU gates before local acceptance.
4. Run `scripts/test-horses.ps1 -Live -SkipContact -CreatureFamily small_snakes`; its isolated loopback2594 server tests Snake, IceSnake and LavaSnake on both owners. These are real native world entry/movement tests, not offline fixtures labelled multiplayer.
5. Refresh affected public controls, run all accepted local groups, render the whole corpse catalogue and run `scripts/verify.ps1`. Keep source-derived models/maps/captures out of Git.

Remaining work includes the missing generic extended casting slot, full original per-class choreography/masks, arbitrary terrain and autonomous gameplay. Chicken208, then Lich and the remaining occurrence queue continue separately; no overall creature-port completion is claimed.
