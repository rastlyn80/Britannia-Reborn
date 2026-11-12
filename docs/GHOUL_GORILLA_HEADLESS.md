# Ghoul/Bogle, Gorilla and HeadlessOne

These three native bodies use their recovered Third Dawn designs, refined private meshes/atlases, source motions plus declared missing gestures, measured limb support and matching static corpses. ModernUO remains authoritative for identity, statistics, movement, actions, hues and death. This is bounded integration evidence, not final anatomy, original-choreography or complete gameplay certification.

## Source and material history

Pinned archive: `work/third-dawn/uotdb.zip`, SHA256 `d872d59a4d3f92c82672bbadb98ae44772e42b44dacb4a28a1fdf39cf121dc0e`. Original inputs, derived meshes/maps, prompts and screenshots remain local and ignored; no redistribution grant for the original game art is claimed. Only original project code, notices and evidence notes are published.

| Native identity | Body | Bones | Original triangles | Refined triangles | Recovered categories |
| --- | --- | --- | --- | --- | --- |
| Ghoul / Bogle | 153 | 41 | 422 | 6752 | 8 |
| Gorilla | 29 | 35 | 250 | 4000 | 8 |
| HeadlessOne | 31 | 42 | 372 | 5952 | 7 |

Original cage comparisons stay separate from the rounded/modern treatments. Refinement preserves the source UV layout and bone hierarchy, with interpolated/smoothed four-influence skins. Ghoul and HeadlessOne require the existing affine-to-rigid conversion: original bind geometry/UVs and joint centres are retained, with proper polar rotations and resampled source joint motion. Exact native animated scale/shear skin fidelity is not claimed. Gorilla uses its original rigid source layout.

Source mesh and atlas pins:

| Archive member | SHA256 |
| --- | --- |
| `uotdb/uotd/Models/Monsters/walking_dead_ghoul_lod2.grn` | `e4cadc5684f9b0d569eb4337052065ecd147863305a2680931805968197fb6ad` |
| `uotdb/uotd/Models/Maps/Walking_dead_ghoul_v04.tga` | `f3e5b1f7244b33f378484eb687e408c2426372749102a2cb62dcba5c925decde` |
| `uotdb/uotd/Models/Animals/gorillas_silverback_lod2.grn` | `1fd5d08dbe470e42ab129282efa85dd0e5f46ce047eb4fdcba3c789caca60186` |
| `uotdb/uotd/Models/Maps/Gorillas_silverback_v01.tga` | `4eaf691ba201edf558c2de1126eecfd40ebd3102d99a5ab494e4ae1cdeff0d81` |
| `uotdb/uotd/Models/Monsters/headless_headless_lod2.grn` | `27f780289a2dc831fc979781e47b33cc18247c60d8c80ad64d9189544bd5ec3a` |
| `uotdb/uotd/Models/Maps/Headless_headless.tga` | `34b2d5101e8658b6271fbc98efe326498b4c0dfcc218d7d6c95063ea4faf5aa5` |

All source clips retain their exact member/hash records in each local preparation report. Ghoul has eight recovered categories and declared authored Cast, Attack3 and Pillage; HeadlessOne has seven recovered categories and authored Cast, Attack2, Attack3 and Pillage. The headless gesture uses its neck landmark without inventing a head. Gorilla retains eight source categories, including Stomp. Runtime Eat and Death-copy LieDown remain labelled synthesized compatibility poses, not additional recovered clips.

Each modern atlas is 1,254 square. The built-in imagegen tool edited the original atlas layout; it did not generate a new rig or captured choreography. Final local files and exact prompts:

- `Viewer/local-art/creatures/walking_dead_ghoul-albedo-v1.png`; SHA256 `0eb22da352e46fbb38e9dd026d2815f433d47bca226b0f7ddbb089a73ce12987`. Exact prompt: `Viewer/local-art/creatures/walking_dead_ghoul-albedo-v1.prompt.txt`.
- `Viewer/local-art/creatures/gorillas_silverback-albedo-v1.png`; SHA256 `2a39419d1bae8e0c8dc86cb092b3720a88875d4f1ea03213aca3c4499e705973`. Exact prompt: `Viewer/local-art/creatures/gorillas_silverback-albedo-v1.prompt.txt`.
- `Viewer/local-art/creatures/headless_headless-albedo-v1.png`; SHA256 `dff702193212767908f38a5959676a0d1ef7d9ec30429e0e934471a211f03bf2`. Exact prompt: `Viewer/local-art/creatures/headless_headless-albedo-v1.prompt.txt`.

Ghoul and HeadlessOne were prepared in this batch; Gorilla's earlier saved detailed atlas was reused. Original maps remain unchanged. The shared material uses matte shading and an albedo-derived relief approximation, not a sculpted normal bake. Native full dyes visibly recolour the rendered models; partial bits and shader binding are preserved, but no recovered original partial-hue mask or universal visible partial-dye coverage is claimed.

## Animation, terrain and bounds

The original Ghoul attack is a diving lunge. Support measures the current unmodified source sole lift in a flat reference frame, then adapts that same lift to the plane beneath each limb. Sloping terrain no longer makes a planted foot look like swing, and a real swing/lunge is not pulled down to stance. Joint rotations preserve limb lengths; presentation offsets do not move native entity coordinates. Gorilla measures both hands/knuckles and both feet. Existing Zombie support is unchanged.

Each used bone caches a local box of the vertices it influences. Transforming and enclosing those boxes bounds a normalized positive skin blend, so nameplates clear hair/claws and selection covers the actual animated body. This avoids reskinning the whole mesh every frame. Bounds update on animation application and render-stage support. Tests compare the conservative result with complete actual CPU-skinned vertices across every saved and compatibility category.

## Final evidence

| Actual avatar | Checks | Terrain poses | Complete action skins | Largest planted gap | Largest lifted-height error |
| --- | --- | --- | --- | --- | --- |
| Ghoul/Bogle | 2,089 | 156 | 221 | 1.71 mm | 1.71 mm |
| Gorilla | 2,326 | 138 | 170 | 2.49 mm | 5.41 mm |
| HeadlessOne | 2,089 | 156 | 221 | 5.19 mm | 3.00 mm |

All rows have zero failures. Cases include raised/lowered finite flat/sloped planes, two orientations, Idle/Walk/Run and supported Attack/Cast/Pillage/Stomp phases, full/partial hues, camera/nameplates, exact bounds and actual rendered static corpses. Corrected soles/segments are captured at the modifier's render-stage signal, before Godot restores the source pose. The Ghoul cast/reach/sweep's separate 252-sample source-space experiment also retains segment lengths and stance anchors; it is not a new animation capture.

Saved-model checks pass: walking family (Ghoul plus Zombie) 1,503 / 462 complete skins; Gorilla 686 / 210; HeadlessOne 883 / 273. Standard Forward+ checks pass 25, 13 and 13 respectively. The unchanged Zombie control passes 838 checks / 102 terrain poses.

Actual disposable two-client native checks pass: walking family 402 (both Ghoul and Bogle, with Zombie control), Gorilla 112, HeadlessOne 160. Native constructor bodies/statistics, raw hues, genuine Mobile.Move, action/hurt/death packets and corpse replication/facing are covered. The static item remains graphic `0x2006`, amount/body 153, 29 or 31. AI is frozen for controlled sampling; this is not autonomous AI/combat/taming or complete gameplay certification. Production port 2593, accounts and saves are untouched.

All 42 accepted local groups / 108 forms retain exact current pose evidence: 75,144 checks / 22,701 complete skins; 1,499 fresh standard GPU checks / 648 views plus focused gates. All 179 corpse variants pass 1,686 fresh rendered checks. Full `scripts/verify.ps1` exits 0 with clean final world startup and no script errors, 71 server-extension / 84 developer-edit client checks. Existing Unicode/teardown diagnostics and two nullable warnings in unchanged PreviewTools tests remain. All 24 existing Orc/Ettin/deer/serpent GLTFs regenerate byte-for-byte unchanged after recipe/selector metadata refresh. Public Air's current-registry control passes 544 GPU / 462 native checks; its provenance is refreshed.

Focused/shared/full logs: `work/creatures/ghoul/`. Receipts: `outputs/creatures/<family>/<kind>-presentation/validation.json`, family `validation.json`, `appearance.json` and `live.json`; whole-corpse log `work/creature-checks/corpses.log`. Earlier failed nameplate/terrain probes are superseded by the final successful exact-input reports.

Bounded counts: 147/279 tested native bodies (52.7%), 133 positive named body/constructor pairs without a complete class denominator; 108 local plus nine independent public forms, 117 generic records / 141 routes. Generic slots: 2,485/3,327 connected (74.7%, including reuse), 842 missing. Original metadata stays separate: 668/3,003 inferred generic routes, 578 category misses on routed bodies, 1,757 entries without a generic model. Specialized humans/mounts are separate. Human classic 35/35, foot 28/28, ordinary-horse 7/7 replacement categories and 732/1,126 wearables are unchanged.

## Reproduction and remaining work

Prepare selected forms with `python -B scripts/prepare-creature-kind.py walking_dead_zombie walking_dead_ghoul`, then `gorillas_silverback` and `headless_headless` separately. Existing accepted family forms must be retained. Run `scripts/test-creatures.ps1 -Families @('walking','gorillas','headless')`; it imports, validates all skins, runs each measured avatar gate, checks source recipes and actual GPU results, and tests static cadavers before accepting routes. Real native tests use `scripts/test-horses.ps1 -Live -SkipContact -CreatureFamily <family>` on disposable loopback 2594. Then run all accepted groups and `scripts/verify.ps1`.

The acceptance gate requires current asset/import/preparation/runtime/recipe hashes, every declared category, the full gait/combat terrain matrix, both stance and swing and matching cadavers. Native allow-lists explicitly test both classes sharing Ghoul's body. Assets are regenerated locally from the user's pinned inputs; they are not included in the public source commit.

Continue Bogling 779, FireElemental 15, IceSnake, Chicken, Snake and the complete measured/unmeasured occurrence queue. Bogling has no matching mesh/table row in this archive; no fire GRN exists either. A separate independent flame prototype is unaccepted and adds no coverage; it needs a credible fire silhouette/material, full pose/GPU/native/death/distribution gates and exact provenance. Full original choreography, final anatomy/material polish, arbitrary terrain, all dynamic identities and autonomous behaviour remain active work. Preserve concurrent terrain/building/UI work and all source/licence exclusions; no routine approval stop.


## Headless One on split treads

The normal client selects the original Third Dawn Headless One for body 31, with separate decoded Classic collapses and the two fitted Enhanced gestures. The existing randomized native skin hue and full or partial dye reach the original materials and the final static corpse. The Enhanced vertebrae retain the hand and neck endpoints. The geometry test measured the same link transforms used by the renderer and found a minimum gap of 154 mm on the tested 22 cm step.

The Headless One passed 6,510 Classic and 7,378 Enhanced living poses. The decoded death test passed 64 Classic and 80 Enhanced handoffs, with a largest measured first-pose change of 0.14 mm. The final frozen meshes cleared the tested support by about 2 mm. Two disposable native server clients passed 44 Classic and 48 Enhanced checks, including walking and running after an idle packet, the stock melee and reaction packets, both fitted Enhanced gestures, dye and the static body-31 corpse. The highest step can still produce a noticeable vertical correction during attacks and lie-down.
