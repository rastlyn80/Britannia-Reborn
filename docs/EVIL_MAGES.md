# Original Evil Mage preparation and equipment

2 November 2026. **Accepted locally after exact graphics, corpse and two-client native gates.**
Native EvilMage uses body 124 in the currently configured Core.UOR branch.
EvilMageLord randomly chooses 125/126. The older-era human-body branch remains
separate. Six actual constructor cases cover both disposable owners. The final native
graphics run passes595 checks and the separate native behaviour run181 checks. The literal-only body
census misses 125/126; these must not be counted inside its 279-body denominator.

## Preserved sources

Exact cabinet/member/native-source hashes are in
[source-mage-inputs.json](../scripts/source-mage-inputs.json). The preservation
archive is `https://zuluarchive.com/static/files/uoaos.zip`, not an independent
official authenticity proof or redistribution grant. Fourteen members from
client7/10/11 provide the model table, two meshes, two original maps and nine
motions. No downloaded executable ran. All source/derived art stays ignored.

Each mesh retains 221 source points, 442 triangles, its own UV/128-square opaque
atlas and all 36 joints. Refinement yields 7,072 triangles. The Master retains
its own texture coordinates; motion reuse requires exact normalized weighted
geometry/hierarchy, allowing only the declared unweighted scene-label alias.
Affine normalization uses proper-rotation rebinding; exact original affine/shear
skinning is not claimed. Original Idle, Walk, Run, Attack, Attack2, Hit, Death,
Fidget and Cast2 remain. Pillage is an explicitly authored crouch/reach using
measured source limbs, stance anchors and original wrist/finger poses.

## Equipment and support

Native constructors equip a randomly neutral robe and sandals; the Lord also
equips a wizard hat with the robe's colour. The modern source costume has
integral clothing. Authored vertex attributes bind robe (layer22), original cap
(layer6), shoes (layer3) and exposed body to independent palettes. Full/partial
hue bits remain intact. Removing an item restores the integral base costume;
it does not invent a naked mesh or remove the original cap/shoes.

Source-face garment roles repeat across sixteen subdivision children. Exact
child UV coordinates are checked, including degenerate faces; original geometry,
UV, skin and animation buffers remain unchanged. Whole source-face roles prevent
foot-weighted robe hems inheriting shoe dyes. The shoe rule is source maximum
Z<0.135m plus mean distal weight>0.5. Cap height/dark-texel classification is
authored. Surface relief is procedural, static and matte; no remastered bitmap
or original normal-map recovery is claimed.

The actual avatar passes worn records to opt-in renderers. Death snapshots keep
their own copy; native 0x2006 corpses use their received clothing, preserve every
semantic colour value when frozen, and refresh following colour/loot changes.
Ordinary non-equipped creature corpses remain outside clothing refresh.

A first terrain probe failed four Run cases by up to 16.161mm because world-Y
shoe minima differed from slope-distance minima. The mage-specific modifier now
solves actual signed-plane clearance by rotating original joints. Leg lengths
and source swing heights are retained. A 120-case support-only measurement was
about 0.92ms mean /1.61ms maximum under concurrent checks; not whole-game timing.

## Evidence and reproduction

Private reports/captures are under `work/creatures/evil-mages/` and
`outputs/creatures/mages/`. Current prepared-source evidence:

- 6,922 action checks, 2,220 complete skins, 1,480 source/refined pairs and
  63 native category/timing/restart cases. Relative joint/basis errors zero;
  maximum sampled floor error 3.273mm.
- Both actual source avatars pass 2,737 checks each /210 finite-plane poses
  each, including Pillage, preserved source foot lift/segment lengths, actual
  selection colliders/nameplates, raw body hues and static corpses.
- 97 actual avatar/death/world-item equipment checks cover all three bodies,
  zero/full/partial slot colours, independent snapshots, decoded 0xAF/0x89,
  exact frozen colour attributes, unchanged-item caching and hue/loot refresh.
  Recorded native clothing is used; this is not another live server test.
- Two independent source-free mask regressions check foot-weighted hem versus
  shoes, exposed skin, exact payload preservation and changed-UV rejection.

```powershell
python -B scripts/prepare-source-mages.py --check-inputs --prepare
$godot=(Get-ChildItem .tools/godot/*console.exe | Select-Object -First 1).FullName
$env:APPDATA=Join-Path $PWD '.godot-user'; $env:LOCALAPPDATA=$env:APPDATA
& $godot --headless --path Viewer --editor --import
python -B scripts/configure-creature-imports.py mages
& $godot --headless --path Viewer --editor --import
python -B scripts/test-creature-mage-masks.py
& $godot --headless --path Viewer --script res://Presentation/SourceMageActionTests.gd
& $godot --path Viewer --script res://Presentation/SourceMagePresentationTests.gd -- --kind=mages_evil_mage
& $godot --path Viewer --script res://Presentation/SourceMagePresentationTests.gd -- --kind=mages_evil_mage_master
& $godot --path Viewer --script res://Presentation/SourceMageEquipmentTests.gd -- --output=res://../outputs/creatures/mages/equipment
./scripts/verify.ps1
```

Set APPDATA/LOCALAPPDATA to the workspace `.godot-user` before Godot. Equipment
tests require the separately recorded native identity report. All test registry
entries are process-local; preparation installs no accepted routes.

## Crossfades, native behaviour and acceptance

The first flat mixed-pose probe found722 misses in2,304 skins, up to132.981mm.
Temporary complete-skin support during actual blends fixes that without changing
source clips. The final flat suite passes11,520 checks/3,840 skins at30/60Hz and
slow/fast rates; maximum error0.049mm. The first render-stage slope probe found
208 whole-skin and72 foot-lift misses. The final ankle-inclusive signed-plane
solve, retained death tilt and coplanar common support balance pass13,828 checks
in2,304 actual rendered skins, with all original tolerances unchanged. Complete
skin clearance, source swing heights, segment lengths, picking and labels pass.
The bounded common correction is at most2cm; steps/separate ledges still need
specific volume proof. All ordinary/action/equipment evidence was rerun on the
final inputs, with start/end stability guards.

A later Juka reproduction exposed a control mistake: native BaseAI.Deactivate
leaves timers running in active sectors. The owned isolated fixtures now use
explicit AITimer.Stop, wire acknowledgements after actor preparation/movement,
and before-callback state checks. Caster map changes stop the timer again. Both
mage native suites were rerun successfully on those corrected controls; earlier
native receipts/logs remain historical. No native core/gameplay code changed.

Both native owners exercise unmodified EvilMage124 and EvilMageLord125/126:
595 checks prove constructors, native clothes, raw hues, Mobile.Move walk/run,
eleven classic/new action requests, both actual avatars, death snapshots and
matching static corpses. Another181 checks prove real Lightning.Cast, its timer,
Target.Invoke and actual damage, without assigning skills, mana or deadlines.
Native Ogre.Kill supplies each corpse and actual native Rummage uses Lift/Drop.
Trammel refuses the loot because the mage has no native corpse loot rights;
explicit fixture travel to Felucca permits the same callback and inventory
acquisition. Six cases retain both refusal and success evidence. Stack merging
is counted by inventory amounts as well as new item identities. No gameplay
rule was changed and the native core/content checkout was not edited.

The initial test incorrectly expected unrestricted looting on Trammel; those
failed diagnostics remain private. Facet transfer, target placement, frozen AI
and direct API invocation are declared fixture setup. These tests do not certify
autonomous combat/rummage scheduling, automatic NPC Cast2/Pillage packets,
random rates, persistence or complete gameplay. Native Spell.Cast excludes NPC
monster hand-movement packets and Rummage emits an emote without Animate; neither
is disguised as an automatically received animation. Integral cap/robe/shoes
remain a fixed source costume, and texture registration/final art can improve.

Earlier Windows Application Control failures are historical. The later full
root verification passed without changing security policy. Final
`scripts/verify.ps1` exits0, including71 server-extension/84 client-overlay
checks and clean world startup. The initial private log is `root-publish-verify.log`;
the corrected AI-control revision also passes the full root suite in
`work/creatures/juka/ai-stopped-root-verify.log`. Production2593/accounts/saves remain
untouched. All51 previously accepted groups passed current regressions. Final
corpse rendering passes203 variants/1,908 checks, including all three mage bodies.

Strict acceptance runs `python -B scripts/check-source-mages.py --native` and
`scripts/accept-creatures.py mages`. The normal mage batch runs all focused gates
and, with `-Live`, the authorised isolated2594 server tests before activation:

```powershell
./scripts/test-creatures.ps1 -Families mages -Live -Capture
python -B scripts/check-source-mages.py --native
./scripts/build-corpse-catalogue.ps1 -Render
./scripts/verify.ps1
```

The accepted bounded census is166/279 (59.5%). Lord125/126 are positive native
constructor witnesses outside that literal-only census, not extra successes
inside279. Exact source/expansion semantics select the current mage branch in
the occurrence queue; older-era body400 remains recorded separately. Sparse
witnesses never erase unreviewed branches for other constructors. There are124
accepted local source forms plus12 independent public forms,165 generic routes
and2,995/3,975 connected generic animation slots (75.3%, including reuse).
These are integration measurements, not complete art/choreography/gameplay or
redistribution rights. All original/derived meshes, atlases and captures stay
private. The full creature goal continues occurrence-first with Juka/Savage/Mummy
and every remaining family; no routine visual approval stop.
