# Sea serpent and deep sea serpent

Native `SeaSerpent` and `DeepSeaSerpent` share body 150 and now use the preserved Third Dawn sea-serpent model. Both native constructors are tested explicitly. The source table also associates body 145 with this mesh; it has no constructor evidence in the pinned native audit and remains presentation compatibility only.

The source is `uotdb/uotd/Models/SeaCreatures/sea_serpents_sea_serpent_lod2.grn`, SHA-256 `336e6e66ee04ab63d8ccf239f30cba060f57712a500132be5ffbafd60cf57f50`: 219 vertices, 435 triangles and 26 bones. The existing Third Dawn input archive has SHA-256 `d872d59a4d3f92c82672bbadb98ae44772e42b44dacb4a28a1fdf39cf121dc0e`. Conservative subdivision produces 6,960 triangles with interpolated weights. The original rig, UVs and seven source categories remain: Idle, Walk, Run, Attack, Hit, Death and Fidget. Corresponding source suffixes are `idle`, `walk`, `run`, `attack1`, `gethit`, `die1` and `fidget`. Alternate attacks and fidgets currently reuse their primary source categories; this is not distinct recovered choreography.

The original 128-square atlas is preserved independently for fin/edge alpha. A built-in image-generation edit supplies an enlarged slate/olive scale and ochre belly atlas. The exact prompt, colour image, source and output hashes remain in ignored `Viewer/local-art/creatures/sea/preparation.json` and the model's `-albedo-v1.prompt.txt` / `.png` siblings. Generated colour does not replace the original opacity mask. These are game-derived local assets, excluded from Git. No right to redistribute the original model or its derivatives is asserted.

The [aquatic policy](KRAKENS.md) retains the model's source-space water origin and submerged vertices. It bypasses lowest-vertex floor lifting, land/deck/seabed support rays and stance-foot IK. Wet PBR is explicit. The source scale is retained: approximately 3.05 m bind height / 18.57 m bind diagonal at the primary table scale. Original-client water offsets, practical world proportions, shore transitions and a stronger tail highlight still need art review.

## Correct native action semantics

Pinned ModernUO `Projects/UOContent/Items/Weapons/BaseWeapon.cs`, `PlayHurtAnimation`, emits classic group **7** for animal and sea bodies, **10** for monsters. The shared renderer previously treated animal/sea 7 as an attack. Horse, ostard, llama/bovine and generic animal routes now play a live hit reaction. A guarded disposable fixture invokes the actual native weapon method and verifies packets on two clients; it does not inflict damage or alter gameplay rules.

Sea groups have a separate map: 0 Walk, 1 Run, 2 Idle, 3/4 Fidget/Fidget2, 5/6 Attack/Attack2, 7 Hit and 8 Death. Classic 12 follows the comparison client's special attack compatibility route. Modern type 0 retains odd-mode alternate attack; type 11 uses the sea attack compatibility category. Unsupported sea 9/10/11 are not given animal lying/feeding categories. Per-model classic overrides support native dolphin breach groups 3/4 separately.

The primary comparison is the read-only pinned ClassicUO reference's `MobileAnimation.cs` and `AnimationsLoader.cs`, not a linked client dependency. `AnimationSequence.uop` canonical group numbers are not necessarily low/sea packet slots: dolphin swimming metadata includes 22..28. The catalogue now retains those mappings as unresolved rather than labelling them using the animal dictionary. Monster high-group interpretations are labelled inferences. Original modes/subactions and exact availability/precedence still need work.

## Evidence and reproduction

Focused results, all zero failures:

- 823 source/refined/modern pose checks and 189 actual skin samples.
- 20 standard Forward+ checks / six views, including raw dyes and source-alpha gaps.
- 48 aquatic Forward+ checks covering wet pixel response, water anchoring against eight finite collider/gait cases and a frozen static corpse.
- 278 actual disposable-server/two-client checks: both native classes on both test characters, native water-only movement, full/partial hues, actual weapon hurt packets, explicit classic/new categories, native death/facing and corpse replication.
- 13 asset-independent animal/sea/monster semantic routing checks.
- 2,914 mount/animal action checks across 1,116 skin poses after correcting group 7.

Current-runtime controls also pass: 110 actual native bird checks, 262 actual native kraken/Leviathan checks, 117 bird GPU checks / 12 support cases, and 547 water-elemental GPU checks. Full `scripts/verify.ps1` exits 0 with no script errors, 71 server-extension / 84 client developer-edit checks and a clean final world startup. The log retains existing teardown RID-leak diagnostics; this is not a claim of a diagnostic-free run. Control logs use the `work/creatures/sea-` prefix with `bird-native-control`, `kraken-native-control`, `bird-gpu-control`, `water-gpu-control` and `full-verify` suffixes.

The complete current shared regression passes 71,060 pose checks / 21,441 skin samples across 103 local source forms / 38 groups, plus 1,435 GPU checks / 618 views. All 166 available static corpse variants pass 1,545 rendered checks. Log: `work/creatures/sea-shared-regression.log`. The bounded native catalogue reaches 134/279 bodies (48.0%); 2,252/3,054 generic protocol slots have connected categories (73.7%, including reuse). Original choreography and final art are separate unfinished measures. Final editor import succeeds after the independent dolphin trial tools are added.

Static graphic **0x2006 / amount 150** resolves the matching final source death pose; 145 is a compatibility variant. No new wire graphic ID is invented. Exact submerged-death-to-floating-corpse vertical continuity remains a gap because the generic frozen-corpse presenter settles its minimum vertex onto the support plane.

From the repository root, using the existing ignored archive and trusted tools:

```powershell
python -B scripts/prepare-creatures.py --families sea
./scripts/test-creatures.ps1 -Families sea -Jobs 1 -Capture
./scripts/test-horses.ps1 -Live -SkipContact -CreatureFamily sea
python -B scripts/build-creature-catalogue.py
python -B scripts/build-creature-actions.py
./scripts/verify.ps1
```

The native command uses an isolated loopback 2594 server and disposable accounts/saves; production is untouched. Exact final logs: `work/creatures/sea-current-checks.log`, `sea-native-final.log`, `sea-animal-action-control.log` and `sea-routing.log`; reports/captures are under ignored `outputs/creatures/sea/`. Tests cover bounded routing and presentation, not autonomous combat-AI, taming/fishing/rewards, complete original choreography or arbitrary shoreline behaviour.

## Subsequent dolphin integration

The original 51-vertex dolphin source trial remains unaccepted and retained for comparison. The independent Innerscene CC0 bottlenose candidate has now passed its native and public-distribution gates and is installed. Its authored nine-bone rig / 14 clips, marine PBR, native breach variants, wet movement, hues and static corpse are documented in [DOLPHINS.md](DOLPHINS.md), with exact source, licence, receipts and reproduction steps. It contains no original UO mesh, rig, animation or map. The sea-serpent checkpoint counts above are historical; current programme totals are in PROGRESS.md.
