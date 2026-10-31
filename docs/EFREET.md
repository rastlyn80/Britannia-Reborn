# Efreet source modernization and hover

The original Third Dawn efreet model retains its rig, crossed-leg floating pose, source animations and native body 131 (0x83). Bounded mesh refinement increases 448 source triangles to 7,168. A generated atlas improves the original green skin, dark vest, turban and ornaments while retaining the source UV layout. Actual on-mesh comparisons were reviewed; exact prompts, original inputs and generated art stay ignored under `Viewer/local-art/creatures/`.

The raw bind geometry has a positive source-Z minimum around 0.439 units (about 0.527 m at native scale). Export preserves this source hover instead of subtracting it to pin the feet to the floor. Runtime foot fitting also skips explicitly declared floating actors, including those with genuine leg bones. Death retains its source motion and settles on the floor for static corpse handoff. Raised/lowered and sloped support adjusts only presentation height, preserving native coordinates, scale and raw hue.

Reproduce with the original local source inputs installed:

```powershell
python -B scripts/prepare-creatures.py --families genies --skip-index
./scripts/test-creatures.ps1 -Families genies -Capture
# Approved disposable server, loopback2594 and two test clients:
./scripts/test-horses.ps1 -Live -SkipContact -CreatureFamily genies
```

New bounded evidence: 703 pose checks / 189 skinned samples; 13 Forward+ GPU checks / 6 views; 16 comparison frames; 33 actual support checks / 6 collision-plane cases; 86 disposable-server/two-client checks, zero failures. The candidate static corpse passes 10 checks. Native Efreet construction, body/hue, movement, action and corpse routes are tested separately from the offline presentation checks. This is not a claim of every original action, final anatomy, arbitrary obstacle clearance or a redistribution license for source-derived assets.
