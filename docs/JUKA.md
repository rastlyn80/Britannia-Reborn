# Original Juka Warrior and Mage

2 November 2026. Two source forms are accepted locally after source, actual
rendering, native protocol/behaviour and corpse gates. Native JukaLord766 remains
an unresolved graphics route. Testing its server buff does not finish its model.

## Sources and preserved data

[source-juka-inputs.json](../scripts/source-juka-inputs.json) records31 exact
source members, four cabinet hashes/member names, three native class sources
and every explicit human-motion binding. Preservation archive:
https://zuluarchive.com/static/files/uoaos.zip . This is not an independent
original-publisher authenticity proof or redistribution grant. No downloaded
installer/executable ran; all original/derived artwork stays ignored.

The additional human cabinet is `uoaos/UOTD/models/humans/client9.cab`,
8,758,386bytes, SHA256
`a5e12b77fd933c97b2a8cf266d1864b3fbe222624055ceae7ebc95ccce3fd8b7`.
It contains378 directory members. The preserved model table gives Warrior764
human motion body400 and Mage765 human motion body401, both monster-type bodies.
Warrior retains34 original mesh bones/470 source triangles, refined to7,520;
Mage retains39 bones/559 triangles, refined to8,944. Their own256-square UV
atlases remain; no remastered bitmap or exact original affine/shear rendering
is claimed. These are large, distinctive Juka bodies, with their original table
proportions, rather than replacement player humans.

Thirteen selected original human motions each cover Idle, Walk, Run, Attack,
Attack2, AttackBow, Hit, Death, Death2, Fidget, Cast, Cast2 and Pillage. The exact
source files are recorded. This is an explicit replacement assignment, not
recovered original per-category choreography. Classic14 selects the second
source cast; newer2/5/14 select Hit/Fidget/Pillage. Bare-handed Warrior/Mage
constructors have no equipped weapon; testing their extra bow category is not
proof of the missing Lord's bow attachment.

## Bounded exporter repair

Seven exact male motion files contain a duplicate `master_h_female` exporter
label. The strict reader still rejects them by default. An explicit animation-
only opt-in renames auxiliary leaf43 by its original object identity, retaining
primary ancestor1 and all44 parsed joints, transforms and animation tracks.
Checks require the exact label, distinct identities, common parent0, identity
rest transforms, a childless auxiliary object and a real primary rig ancestor.
Only the seven pinned source hashes receive this opt-in. The existing target-
mesh filter then retains the joints actually present on each original Juka mesh.

Twelve source-free importer tests pass, including default rejection, both track
identities/data, invalid labels and attempted intermediary replacement. Actual
seven-file comparison preserves every parsed field against the separate private
research reader. That duplicate research reader is not shipped.

## Terrain and transition corrections

SourceJukaVisual reuses the measured source-leg/blend machinery, with its own
source support and the ordinary body-hue shader. Integral Juka clothing has no
mage robe/cap/shoe dye slots. Native backpack records still survive the actual
avatar/death snapshot. No player wardrobe or Lord weapon compatibility is claimed.

A broader flat transition probe found two Warrior forward-death misses of9.532mm.
Uncompressed imports reduced this by only about3micrometres, so key compression
was not the fix. Complete-skin Death2 support after the blend resolves it while
preserving relative joints, source lengths and native coordinates.

The first mixed-plane sweep then found12 failures, all at one Mage walk/run phase
across six planes/yaws. Independent full-vertex measurement showed both original
feet and the entire source skin briefly rise19.240mm. Forcing that source pose
to the floor conflicts with retaining its foot lifts. The Juka-specific support
now preserves independently measured two-foot airborne clearance. The unchanged
8mm skin-clearance,9mm foot-lift and1mm segment-length tolerances apply around
that measured source clearance. No blanket tolerance increase or excluded case.
Both the failed diagnostics and independent airborne probe remain private.

## Evidence

- Source poses:8,681 checks/2,886 complete skins/1,924 paired poses. Relative
  source joint/basis differences are zero; maximum sampled floor error1.407mm.
- Each actual source avatar:3,250 GPU checks/246 raised/lowered/sloped finite-
  plane poses/255 source and compatibility action skins. Original atlas,
  full/partial hues, actual picking/nameplates and static corpses pass.
- Flat transitions:15,856 checks/5,280 skins at30/60Hz and slow/fast rates,
  including measured airborne source clearance; maximum error1.719mm.
- Actual render-stage mixed transitions:23,620 checks/4,032 complete skins,
  seven action pairs, two rates and six slope/yaw cases per form. Six airborne
  source cases survive; maximum skin-clearance and foot-lift error3.719mm.
- General source checks:2,031/630 skins; standard GPU25. Current exact input
  capsules bind all treatments/imports, runtime/test files and preparation.
- Real native actors:439 checks/four constructor cases on both disposable
  owners. All13 requested classic/new action groups select the same intended
  source category on both actual avatars. Native hues, equipment, Mobile.Move,
  second death action, real Kill/death snapshots, facing and static corpses pass.
- Native behaviour:281 checks/four cases. Unforced Warrior post-melee callbacks
  produce a real random special. Mage Lightning.Cast/timer/target causes damage;
  natural OnThink eligibility applies the native Lord75%hit/50%strength/dexterity
  buff and its native20-second timer restores values/action eligibility. Both
  measured recoveries were19.996/20.003seconds from the first observed boosted reply.
  Native corpse Lift/Drop refuses loot on Trammel without rights and succeeds
  after explicit fixture travel to Felucca. No native stats, skills, mana,
  deadlines or random outcomes are assigned.
- Candidate corpses:two bodies/17 checks. All205 current corpse variants pass
  1,926 fresh rendered checks. Thirty-two fresh comparison frames are private.

The first integrated reproduction exposed a flaky unrestricted-loot assertion.
Inspection found a fixture-control error: native BaseAI.Deactivate is conditional
on sector activity, so it had not reliably disabled these nearby NPCs. The owned
helper now explicitly stops the AI timer, with wire acknowledgements after actor
preparation/movement and before-callback state checks. Map changes stop it again.
The corrected complete integrated Juka batch exits0, using exact unchanged
graphics evidence plus fresh captures/native/corpse checks. Its native totals
above supersede the earlier427/293 controlled-intent receipts. Both mage suites
were also rerun on the corrected helper. The exact cause of the earlier single
loot refusal was not captured; uncontrolled AI was a real setup fault, not a
proven unique cause. Failed diagnostics remain private.

AI scheduling is explicitly stopped and checked. Placement, Lord combat target, direct callback
invocation and facet travel are declared fixture setup. This does not certify
autonomous fights, actual weapon swings/proc rates, automatic NPC casting
animation packets, buff particle rendering, persistence, complete gameplay or
final artwork. Native Lord766 is present only as the unmodified support actor
for the buff, not a completed visual. Existing humans/equines/llamas and the
production server/accounts/saves are untouched.

## Reproduction and current scope

```powershell
python -B scripts/prepare-source-juka.py --check-inputs --prepare
./scripts/test-creatures.ps1 -Families juka -Live -Capture
python -B scripts/check-prepared-juka.py --native
./scripts/build-corpse-catalogue.ps1 -Render
./scripts/verify.ps1
```

`test-prepared-juka.ps1` runs the graphics stages without accepting routes.
The full batch verifies those stages, then uses the authorised disposable2594
server, strict native gate and candidate static corpses before activation. The
preparation's exact integration marker is discharged only in the accepted-index
copy; source preparation/proofs stay unchanged. Old pose receipts are archived
only after a fresh general run, then independently rechecked against actual
assets/imports and current runtime. No proof hashes are rewritten to bless edits.

Accepted bounded native bodies are168/279(60.2%). There are126 local plus12
independent public source forms:138 generic records/167 routes,3,045/4,033
connected generic slots(75.5%, including reuse),988 missing. This is bounded
integration coverage, not final art/choreography/gameplay completion. The
corrected full `scripts/verify.ps1` exits0, including71 managed server-extension
and84 client-overlay tests and clean final world startup. The root and integrated
reproduction logs are under `work/creatures/juka/`. Owned source is published
with this revision; original/derived art and private evidence stay local. Other old fixtures using sector-sensitive Deactivate still need a case-specific control audit; familiar lifecycle tests intentionally require running AI and must not be mechanically stopped. Continue with
Savage, Mummy and every remaining family in occurrence order.
