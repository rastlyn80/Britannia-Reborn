# Ethical steeds repaired; bovine batch integrated

31 October 2026. The authorised holy/unholy riding blocker is resolved in the
reviewed local server build. Four native cow/bull presentations are also
integrated. Equine coverage remains 26 indexed body presentations (17 native,
nine client compatibility), plus three item-only ethereal forms. Human
wearables remain 732/1,126 (65.01%); bovines have a separate four-body count.

## Ethics fix and activation

The pinned ModernUO content returned a new empty ethics registry on each lookup.
Fresh enabled worlds also needed both ethical identities initialised, and saved
ethical players needed their mobile links restored after deserialisation. The
fix retains one registry, initialises missing identities when ethics is enabled,
initialises player lists on both construction paths, and restores player links
without duplicate list entries. Save fields/versions are unchanged. Native
faction, oath, allegiance and mounting conditions remain authoritative.

`Server/fixes/ethics-registry.json` is a small authored replacement recipe.
`scripts/prepare-server-fixes.py` verifies the exact dependency revision,
normalised source hashes and unique anchors. MSBuild substitutes two generated
content files under ignored `work/server-fixes/`; the original checkout is not
edited. No server engine changes, upstream report or upstream submission occur.

`scripts/build-server.ps1` produces a hash receipt. The installation helper
checks the receipt and runtime lock/listener before copying the content assembly.
**The running production server was left untouched: installation is deferred
until its next normal start through `scripts/start-server.ps1`.** Existing
accounts, saves, remembered-login location and feature settings are preserved.
Tests explicitly enable ethics and factions only in the disposable runtime;
this change does not enable those features in the production configuration.

Evidence from real loopback world entry with two clients and disposable accounts:

| Check | Result |
|---|---|
| Ethical riding matrix, both sexes | 403 checks, zero failures, 12 cases |
| Real world save and fresh process restart | 24 checks, zero failures, two saved mounted players |
| Full extended equine matrix | 1,242 checks, zero failures, 38 cases |

Players join the corresponding native factions, speak the normal ethical oath
at an ankh, then use ordinary upstream double-click mounting. Correctly aligned
riders succeed; neutral and wrong-allegiance riders are refused. Both clients
observe mount items, colours, movement and dismount. Duplicate ethical identity
construction preserves the originals. Restart evidence includes ethical player
links, single membership entries, saved steed references and native remounting.
The fixture assigns faction membership and the persistence sample's steed
reference; native ethical summoning powers are outside this test. No forced
rider assignment certifies ethical eligibility. These results close
the prior positive-rider blocker, not every possible server gameplay scenario.

Local reports: `outputs/ostard-riding/ethics-live.json`, `ethics-restart.json`,
`equine-completion-live.json`, and `ethics-runtime.json`. Runtime/configuration,
generated upstream code and saves remain ignored.

## Four bovine bodies

| Native class / appearance | Body | Source cage -> refined triangles |
|---|---|---|
| Cow, black/white | 0xD8 | 218 -> 3,488 |
| Cow, brown/white | 0xE7 | 218 -> 3,488 |
| Bull, brown | 0xE8 | 236 -> 3,776 |
| Bull, spotted | 0xE9 | 236 -> 3,776 |

`AnimalVisual.gd` registers loose bodies separately from ridden items. Cow and
Bull are native BaseCreature classes, with no invented mount item or riding
permission. Raw server hues, stats, control and coordinates retain their native
authority. Dead body IDs select their corresponding held source death art.
Cow.Tip's exact living-animal animation signature temporarily lies down and
recovers; it does not mark a living cow dead.

All four keep 32 bones and normalised four-influence skins. Eight imported
clips cover Idle, Walk, Run, Eat, Attack, Hit, Death and Fidget. LieDown reuses
Death as a recoverable pose. Cow and bull keep their species-specific brown
clip sets; spotted forms share the matching species clips. Bull Fidget reuses
the compatible cow clip, explicitly matched by bone name. Native Eat is retained
instead of replacing it with the older generic authored feeding loop.

Two bounded refinement levels soften useful geometry while preserving UVs and
skin weights. Refined cows have 1,750 geometric vertices; bulls have 1,905.
Nominal heights are 1.48m and 1.62m. The importer retains its in-place root
adjustment and sampled flat-floor correction; arbitrary slopes, exact source
root motion and universal choreography are not certified.

Source is the existing locally acquired Third Dawn archive `work/third-dawn/uotdb.zip`,
SHA-256 `d872d59a4d3f92c82672bbadb98ae44772e42b44dacb4a28a1fdf39cf121dc0e`.
Mesh members are `uotdb/uotd/Models/Animals/bovines_{cow|bull}_{brown|spotted}_lod2.grn`;
source maps are `Models/Maps/bovines_bull_{brown|spotted}.tga`. Exact member hashes,
matched tracks, refinements and atlas hashes are saved in each local
`Viewer/local-art/animals/bovine_*-provenance.json`. Original game executables
and DLLs were not run.

The brown and spotted atlases were edited with **built-in imagegen**, without a
CLI fallback, against the extracted maps. Workspace outputs are
`Viewer/local-art/animals/bovine-brown-albedo-v1.png` and
`bovine-spotted-albedo-v1.png`; adjacent `.prompt.txt` files preserve the exact
final prompts. `outputs/bovines/atlas-provenance.json` records absolute paths,
full prompts, hashes and generation mode. Both modern cows use the spotted
atlas on their matching source UV cages; 0xD8's shader darkens the patches.
Approximate albedo-derived relief and restrained roughness improve the surface.
Exact UV registration, finer horn/hoof anatomy and coat detail remain visual
review work. These proprietary-derived experiments carry no redistribution grant.

## Bovine evidence and reproduction

| Check | Result |
|---|---|
| Source skins, timing, routes, tipping, corpses and support | 3,206 checks, zero failures; 972 sampled skin poses and 12 flat/slope support cases |
| Actual Forward+ visibility and dye response | 48 checks, zero failures; 24 views |
| Actual disposable server / two clients | 358 checks, zero failures; eight body/sex cases |
| Original / refined / modern review | 128 real Godot comparison frames |

Live movement uses native Mobile.Move, with both clients verifying actual changed
coordinates and source gaits. Flat arena relocation is fixture setup, not
movement evidence. Native tipping/recovery, attack/reaction/eat/rest packets,
real death and corpse replication are exercised. Owning-player Cow.TryMilk API
tests establish four servings followed by exhaustion; they do not certify a
complete eligibility audit or the normal client beverage-item target flow.
Control assignment is fixture setup, not a taming gameplay test. Autonomous AI
and pathfinding are outside these finite samples.

```powershell
./scripts/build-server.ps1
./scripts/test-horses.ps1 -Live -SkipContact -Ethics
./scripts/test-horses.ps1 -Live -SkipContact -EquineCompletion
python -B scripts/prepare-bovines.py --modern-atlases
./scripts/review-bovines.ps1 -Validate
./scripts/test-horses.ps1 -Live -SkipContact -Bovines
./scripts/review-bovines.ps1 -MaterialTest
foreach ($body in @(216,231,232,233)) {
    ./scripts/review-bovines.ps1 -Body $body -Capture
}
python -B scripts/audit-bovines.py
python -B scripts/build-bovine-gallery.py
./scripts/verify.ps1
```

Preparation requires the private pinned archive and saved local atlases. Use
`Reviews/Review-Bovines.cmd` for the interactive comparison, or open
`outputs/bovines/index.html`. JSON evidence is beside that gallery and under
`outputs/ostard-riding/`. No root review launchers or generated art are added
to Git. Full verification exits 0; existing unrelated bridge missing-id,
malformed-Unicode fuzz, nullable and teardown diagnostics remain visible.

Next creature batch: bears, then canines/deer/felines and smaller animals,
before the distinctive monster families. Keep original-source trials, visual
approval, animation evidence and native integration as separate checkpoints.
Clean-install distribution and rights for the local generated asset pack remain
separate unfinished work.
