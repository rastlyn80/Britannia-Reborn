# Equipment and native appearance expansion — 28 October 2026

The second human batch adds long skirt, shortened kilt, gloves, two helmet
shapes, sword, war hammer and staff/sceptre to both fixed bodies. Together with
the first five pieces, this is 13 distinct equipment meshes, not 13 exact
replicas of every native item design. Native graphics map explicitly through
HumanWardrobe.gd. Some related sword, glove, helmet and staff IDs share category
art; two-handed poses and weapon-specific combat are not finished.

Five hair families plus bald are available: short, long, ponytail, pageboy and
afro. All seven native human beard IDs map to long/short/goatee/moustache meshes
and combinations. Unsupported native human styles such as mohawk, bun,
receding and pigtails retain their exact identity and are flagged as a short-hair
substitute. Beard/hair type and colour remain separate even when headgear hides
them. Player and NPC body 400/401 use the same rendering and native profile.

## Native state and creation

MobileAppearance.profile and GameSession.appearance_for retain serial/body,
skin hue, name, flags/notoriety, all native mobile fields, raw worn items,
hair/beard IDs and hues, and received statistics. Incoming remote status/vitals
are retained as well as the player sheet state; absent NPC statistics stay absent.
Presentation copies cannot mutate authoritative state. Removing a beard clears
only its layer. Full equipment snapshots replace stale layers.

The existing creation panel now sends supported hair, beard, independent
colours and skin selections in the native 0xf8 fields. The server validates
them and persists the resulting appearance. Female creation disables beard
selection according to the native human race rules. This remains the simple
creation panel, not the full graphical creator.

HumanHue uses the locally supplied native 32-entry RGB555 palette, including
partial-hue handling, instead of multiplying by a single end colour. Authored
albedo intensity selects palette entries; the modern texture is not the
original sprite. Missing palettes preserve authored colour instead of
inventing a native colour. Each instance has its own material; normal detail
is retained. Skin still uses three authored presets approximating hue groups,
which is a separate fidelity gap.

Hair/beard texture pigmentation is normalized independently before applying
the same native dye, so a dark source beard does not force silver back to
black. Colour labels follow the supplied palette: charcoal, dark brown,
blond, copper and silver. These are modern material interpretations of the
native palette, not pixel-identical reproduction of original hair sprites.

Native 0x6e and 0xe2 animation requests are now decoded, retained with the body
at receipt, and emitted as an action event. Action/frame/repeat/reverse/delay
values stay native. They are not yet mapped to complete action playback. An
authored right-hand grip from the bundled CC0 UAL sword stance closes the
fingers around held props; it does not establish a two-handed stance or combat.

## Fitting and sources

Source hashes and individual archive-member hashes are pinned in
scripts/character-expansion-inputs.json. Download-character-expansion.py only
reads archives; no downloaded scripts run. The official MakeHuman catalogues:

- [Skirts](https://static.makehumancommunity.org/assets/assetpacks/skirts01.html):
  MargaretToigo long full skirt; the kilt is a shortened, less-flared derivative.
- [Gloves](https://static.makehumancommunity.org/assets/assetpacks/gloves01.html):
  MargaretToigo short gloves.
- [Helmets](https://static.makehumancommunity.org/assets/assetpacks/hats02.html):
  grinsegold Corinthian helmet and javherre Templar helmet. Current official
  catalogue and archive author metadata list CC0; original MakeClothes AGPL3
  template headers are retained unchanged and noted in the pin manifest.
- [Weapons](https://static.makehumancommunity.org/assets/assetpacks/equipment01.html):
  Joel Palmius crude sword, culturalibre war hammer and magic sceptre.
- [Beards](https://static.makehumancommunity.org/assets/assetpacks/bodyparts05.html):
  RehmanPolanski beard/moustache and culturalibre faun beard. A shorter beard
  is derived around each body's chin height.
- [Official CC0 system assets](https://static.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html):
  bob02, long01, ponytail01 and afro01 hair. The already approved short hair
  remains in the base. Previously rejected GLB ponytail fitting is not reused;
  this pass fits the original static proxy to the current body.

The skirts use the project's already traced CC0 woven linen and fabric normal
map from MedievalKit/ambientCG, pinned by hash with its existing notices.
An unsuitable crown-like helmet was rejected in visual review. Texture pixels
from new source archives are retained; linen is a documented material swap.

The fitter recovers hm08 vertex identities from unchanged UV topology, fits
barycentric proxy geometry and transfers normalized weights. Cosmetic meshes
bind to the head; weapons have rigid right-hand bindings. Existing body/rig
geometry is not modified. Glove coverage is orthogonal: 32 hand-free versions
of the existing body masks, rather than an exponential set for every extra
garment. Skirts retain complete underlying legs and share the established
garment controls; the kilt has bounded flare and 8 mm radial ease.

## Checks and reproduction

Run scripts/prepare-human-batch.ps1 to fetch pinned inputs and build both base
and expansion batches; -VerifyOnly checks prepared assets and animated skirts.
The isolated expansion build is Blender with scripts/prepare-character-expansion.py,
optionally followed by -- --female. Use --python-exit-code 1 for shell automation.

Review-Human-Batch.cmd opens the exact renderer with outfits and hair/beard
controls. Direct review arguments also accept --hair-id=203d --hair-hue=1147
--beard-id=204d --beard-hue=1102, --head and --varied. The preview's female is
clean-shaven; the shared runtime still honours facial hair if a server supplies it.

Evidence under ignored outputs/third-dawn and work/character-expansion:

- Actual exported asset validation: 16 expansion pieces plus 32 glove masks per
  sex (96 GLBs). Joint identities/rest layout, UVs, finite positions, normalized
  weights and rigid head/hand assignments are independently checked. A second
  float32 import/export introduces only bounded numerical rest differences;
  the report records the measured maximum.
- Skirt validation: 192 poses across both sexes, both skirts and native
  Idle/Walk/Run; no reported enclosure/floor failures above the actual open
  hem. Physical hem boundaries are found from position-welded topology, not
  from a guessed minimum-height band. This is sampled coverage, not cloth
  physics or arbitrary-action validation.
- CharacterExpansionTests.gd checks native profiles, creation offsets, live
  update/removal semantics, raw action packets, all 32 glove combinations,
  hair/beard combinations, independent hue palettes, attachments and grip.
- scripts/test-human-batch.ps1 -Live -Visual -Cosmetics uses dedicated local
  styled characters, checks server appearance and reconnect persistence, and
  verifies another client's female body/hair/robe updates. Existing owner
  characters and saved login are not changed.
- scripts/verify.ps1 and scripts/test-login.ps1 cover combined project and login
  regressions. A world prop without vertex colours exposed a nil-array error
  during live entry; a bounded empty-array guard preserves its geometry.

CharacterCoverage.gd writes the measured native-ID gaps separately. The full
goal, NPC contract, body/action families, quality requirements and unfinished
work are recorded in CHARACTER_PORT_PLAN.md. The stiff baseline gait remains
an explicit quality issue. This batch does not complete non-human mobiles,
all wearable designs, mounted play or server-requested combat/action playback.

## Verified checkpoint and artistic limits

The local audit records 80 category mappings out of 1,126 wearable-flag graphics
in a 36,527-item catalogue, with the catalogue SHA-256 in its output. Only human
body arts 400/401 have these replacements. This denominator is not all server
equipment classes, and these category mappings are not exact original designs.

All 96 exported models, 192 skirt poses, five source-free proxy parser tests,
19 baseline human checks and 39 expansion checks passed. Dedicated styled
male/female native creation/re-entry, appearance persistence after reconnect,
second-client hair/body agreement and robe changes passed. Native login's
eight protocol checks and local login/relay smoke passed.

The shared working tree's full verification encountered bottle-colour checks
in concurrent world/art edits. No such changes were reverted. Full
scripts/verify.ps1 subsequently passed against an isolated archive of commit
69fb534 with only this character overlay and the two-line colour-array guard,
prepared character assets, local world data and prepared surface arrays.
Log: work/character-expansion/isolated-verify-prepared.log (exit 0; no script or
engine errors). This verifies integration against committed world code; it
does not certify the other editor's unfinished changes.

Reviewed Forward+ and Compatibility captures include kilt walking, both
helmet shapes/weapon attachment, hammer/afro, sceptre/robe and head cosmetics.
The weapons are visibly simple; the sceptre substitutes for staff categories.
Headgear and bob/pageboy silhouettes are category substitutes. Hair cards,
facial-hair edges, metal/texturing and exact native silhouettes need further
artistic refinement. The current weapon posture is a grip demonstration,
not a natural armed stance. Functional tests are not artistic approval.
