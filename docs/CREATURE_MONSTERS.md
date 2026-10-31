# Monster expansion and original-action ledger

31 October 2026. The generic creature pipeline now has **47 source
models/variants across 20 filename groups**, with 57 body routes. Together with
the earlier horse/equine/llama/bovine pipelines, **73 of the 275 bounded native
literal body targets have presentations and native test evidence (26.5%)**.
This source audit is not an exhaustive census of dynamic constructors or the
modern client's complete body catalogue, and routing is not final art quality.
Human wearable coverage remains 732/1,126 (65.01%).

## What was added

Beyond the wildlife checkpoint: ogres and both lord variants; orcs, captain,
lord and shaman; ordinary/frost trolls; ettin, cyclops and titan; corpser,
reaper and swamp/Harrower tentacles; centaur, pixie and succubus; imp, shadow
fiend and mongbat. Distinctive source geometry and useful source rigs/clips
remain the starting point. The shadow fiend explicitly reuses matched imp
clips, not an invented original table reference.

The absent centaur/pixie/succubus maps were authored against saved technical
UV guides. All three comparison treatments use the replacement atlas and are
labelled accordingly; none is described as a recovered original map. Source
atlases and generated refinements have exact prompts, input/output hashes and
workspace paths in ignored `outputs/creatures/atlas-provenance.json`.
Generation uses the built-in image tool, with no CLI fallback. Assets and
game-derived comparison images remain local and ignored.

Bounded source fixes retain the original archive and strict defaults:

- The ettin's single unweighted visible vertex receives an explicit authored
  interpolation from adjacent vertices, limited to four normalised influences.
- Duplicate reaper animation names are omitted only for auxiliary subtrees
  absent from the target mesh. Retained joints and their ancestors cannot be
  discarded this way; ambiguous retained names still fail.
- Tentacle normals at coincident collapsed bind seams use adjacent incident
  surfaces. Potentially moving triangles, their vertices and weights remain.
- Fast tentacle/centaur clips bake floor corrections at 120 Hz, and their local
  Godot import settings preserve that rate. Source glTF hashes alone were not
  enough: acceptance now checks the import-setting hashes too.
- Sustained flight keeps source vertical motion with clearance; takeoff/land
  apply only a penetration-preventing envelope. Foot contact is disabled during
  airborne actions. These are declared presentation corrections, not native
  flight-physics certification.

## Evidence and its limits

Current generic regression: **30,144 pose/identity/support checks, 9,156 actual
deformed samples and 584 GPU checks**, zero failures. There are **752 core
comparison frames**, plus selected source cast/flight/secondary-attack views.
Terrain reports now distinguish measured stance soles from poses without any
measured stance. Toe descendants are included for ordinary hoof/paw soles;
walrus fore-flippers are not treated as weight-bearing forelegs.

The expanded wildlife/humanoid native run passed 3,086 checks. Separate native
runs passed: ettin/cyclops/titan 78 each; plant family 282; centaur 86; pixie 94;
succubus 94; imp/shadow fiend 180; mongbat 96. These use real two-client world
entry and original native constructors, never overwritten body IDs. Optional
constructor parameters use their declared defaults. Native rooted AI refuses
movement; ordinary movers exercise Mobile.Move. Corpses and native corpse
suppression are checked independently. One initial mongbat run disconnected
during the second test client's login, before creature checks; its fresh retry
passed. No production login implementation was changed.

The full `scripts/verify.ps1` exits 0, including 13 synthetic creature-reader/
rig tests and 11 existing Third Dawn tests. Existing unrelated diagnostics and
the headless corpse-cleanup null-material diagnostic remain. Native AI is
frozen between controlled samples; these runs do not certify autonomous AI,
taming, boss mechanics, full combat, every outfit or arbitrary terrain.

Visual inspection still finds coarse centaur torso anatomy and pixie wing
silhouette/material limitations. A passing finite-motion/render test does not
close those art tasks. Centaur stance samples currently have no measured sole
contacts and are explicitly not terrain-certified. Dedicated corpse, action,
hue and basic native routing evidence remains useful while those are refined.

## Action catalogue and continuation

`scripts/build-creature-actions.py` records the current renderer's actual
protocol maps, recovered source clips, prepared aliases, runtime substitutes,
authored categories and missing routes. It also decodes **211 original
AnimationSequence UOP records**, with zero parse blockers, retaining their
groups, mode transitions, movement and type/subaction choices. The source
archive's exact name/hash is recorded locally; sprite pixels are not copied.

Current generic protocol inventory: 1,221 slots, 950 routable and 271 missing.
These are **not** an original-action completion percentage. The original
metadata includes extended/internal groups and mode/subaction combinations
outside those slots; those remain visible separately. Frame availability,
MUL/DEF/UOP precedence, authentic choreography and equipment attachments need
further work. Earlier human and mount action catalogues remain separate.

Review `outputs/creatures/index.html` and `actions.html`. The source queue now
has 118 prepared generic trials and six remaining source blockers; trials do
not count as accepted replacements. Continue through arthropods, reptiles,
dragons, undead, daemons/other magical beings and elementals, then missing
modern native identities and other rideable bodies. Preserve recognisable
Third Dawn shapes where useful; use traced free alternatives or authored
replacements where the source is absent or unsuitable. No routine review gate
pauses this programme.

Reproduce the source/action inventories and the current regression:

```powershell
python -B scripts/build-creature-catalogue.py
python -B scripts/build-creature-actions.py
& ./scripts/test-creatures.ps1 -Families @('flails','centaurs','fey','succubi','imps','mongbats','bruins','canines','deer','felines','porcines','ruminants','rodents','walrus','ogres','orcs','trolls','ettins','cyclops','titans')
& ./scripts/test-horses.ps1 -Live -SkipContact -CreatureFamily flails
& ./scripts/verify.ps1
```

Replace `flails` with a selected accepted family for its own fresh native run.
The harness uses disposable runtimes/accounts on loopback 2594 and leaves the
running production world and saves alone. `CreatureReview.gd --capture
--family=... --kind=... --clips=Fly,Land` captures selected extra source actions;
the review buttons expose every available prepared clip.
