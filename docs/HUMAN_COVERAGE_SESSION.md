Latest expansion: [HUMAN_TAILORING_BATCH.md](HUMAN_TAILORING_BATCH.md), 246/1,126 mapped graphics (21.85%) and 72 categories. The milestone table below is historical.

# Human coverage and armour correction - 29 October 2026

The requested category targets are reached on both existing human bodies, using
the unchanged catalogue denominators. This measures available replacement
categories; it does not certify every original design at final art quality.

| Measure | Before | Current |
| --- | --- | --- |
| Original action groups with prepared replacement clips | 23/35 | 35/35 (100%) |
| Connected on-foot groups, excluding deferred mounted actions | 23/28 | 28/28 (100%) |
| Indexed wearable graphics with category meshes on both bodies | 86/1,126 | 234/1,126 (20.78%) |
| Equipment categories | 20 | 65 |
| Prepared clips per body | 45 | 59 |

Seven human rider clips are explicit previews. Live mounted playback is disabled
by default; horses, saddles and mounted gameplay remain deferred. Unknown items
do not receive arbitrary category fallbacks to inflate the wearable count.

## Changes

- Added bow/crossbow attacks and aiming stances, turn, salute and a third fidget.
  Pinned free KayKit CC0 timing is retargeted to the accepted rig with grip-target
  arm fitting and stable ranged wrists. Existing walking, running, cloth-safe
  attacks and authoritative mobile transforms remain intact.
- Added 45 category parts: weapons/tools, shields, leather/studded/plate/mail
  torso/arm/leg layers, gorgets, jewellery and headwear. These add 148 native
  graphic mappings, with full IDs and independent item/cosmetic hues. Aliases
  share category geometry; these are not 148 unique designs.
- Replaced the owner's rejected glossy, body-derived armour shells. Complete
  tailored trousers cover the seat, crotch and inner legs. A separate charcoal
  woven undercoat and wrist overlaps cover gaps between manufactured plates.
  Cuirasses, pauldrons, joint cups and overlapping waist lames have thickness,
  beveled edges and rigid bone bindings. Steel has a brushed metallic surface;
  leather is dark and matte; mail has generated interlocked-ring colour/normals.
  Textile backing retains its own colour when the metal receives a native dye.
- Fitted ankle boots avoid tall boot shafts intersecting greaves. Updated glove
  masks include the wrist transition; independent GPU opacity checks guard
  against hiding the body underneath an actual clothing hole.
- Long hair and ponytails fit outside the broader armour/pauldron envelope.
  Cloak-specific surface bindings and original hair UV/alpha silhouettes remain.
- Retired outfit parts are freed before rebuilding, correcting material lifetime
  errors during rapid native-ID/hue changes.

## Reproduction

Start with the existing traced body/wardrobe foundation. Source URLs, licences
and exact hashes are in HUMAN_COVERAGE_SOURCES.md and
`scripts/human-coverage-inputs.json`. Downloads and generated art remain ignored.
Only static data/text members are extracted from the free archive; no downloaded
executable or bundled Blender script is run.

```powershell
./scripts/prepare-human-coverage.ps1
./scripts/prepare-human-coverage.ps1 -VerifyOnly
./scripts/build-human-catalogue.ps1 -NoOpen
./scripts/verify.ps1
./scripts/test-login.ps1
./scripts/test-human-batch.ps1 -Live -Cosmetics -Motion
./scripts/review-human-coverage.ps1 -Python <python-with-Pillow>
```

Additional Blender checks use `validate-human-coverage-poses.py` and
`validate-expanded-skirts.py -- --motion`. Run the actual GPU scripts
`HumanArmourCoverageTests.gd` and `HumanHairLayerTests.gd` through Godot without
`--headless`. The rendering harness forces frame submission and has a watchdog
so review generation also works when the window loses focus.

## Evidence

- 94 new exports: 45 category parts plus undercoat/ankle-boot support per body;
  valid geometry, normalized weights, compatible 61-joint identities and traced
  source hashes/licences. Support parts do not raise category coverage.
- 118 motion clips: original body UVs, weights and bind preserved; maximum
  body-coordinate export difference below 1.2 micrometres. Eight garment-only
  controls remain on the unchanged 61-joint rig.
- 761 focused runtime checks: native mappings, both rigs, server timing, all
  prepared groups, rider gating, holding hands, ranged wrist stability, steel
  dye properties, separate backing and existing clothing/hair layering.
- 1,152 robe/skirt/kilt pose samples, including the new on-foot actions.
- 2,400 armour pose samples: finite geometry, floor clearance, and manufactured
  rigid-edge length preservation within 0.1% (maximum measured 0.0293%).
- Actual GPU armour checks cover both bodies, four full armour families, five
  actions at two phases and four angles: 320 samples. The bare head/neck are
  identified from source bone weights. Covered body skin is marked magenta;
  an independently rendered complete body supplies the opacity reference.
  Requirements: at most four skin pixels, at least 98% body silhouette coverage
  and 99.5% seat coverage. All 320 samples pass; minimum measured seat retention
  exceeds 99.7%. Final results are in the local coverage report.
- 400 GPU hair-depth samples across both bodies/styles, ten outfits and five
  actions: all 400 pass, retaining at least 98% of reference tail pixels.
- 62 real-engine review views and five contact sheets. These are engine renders,
  not generated concept images. The catalogue keeps 39,410 item/action review
  rows and 332 separate installed UOP mode/action metadata rows.

Ignored evidence folders: `outputs/human-coverage-session/`,
`outputs/human-armour-correction/`, `outputs/human-catalogue/` and
`outputs/human-wardrobe-2/`. Logs are in `work/human-coverage-session/`.
Earlier body-shell renders/contact numbers are superseded by the armour
correction; they are not evidence for the current manufactured construction.

Full project verification passes without script/engine errors in
`verify-final2.log`. The first rerun caught a type-inference error in concurrent
editor work; the shared directory correction preceded the successful rerun.
Native login protocol/server-list/relay checks pass in `login-final.log`.
`live-final.log` additionally proves dedicated male/female world re-entry,
equipment removal/re-equip, reconnect identity, war/peace, bow and player plus
second-client action playback. A relay alone is not counted as world entry.
Armour, hair and rigidity results are respectively in `armour-final-gpu.log`,
`hair-last-gpu.log` and `armour-final-poses.log`; 761 focused checks pass in
`runtime-armour10.log`. Remaining uncommitted world/editor edits are separate.

## Remaining work

Armour is still category prototype art. Manufactured silhouettes, shoulder/joint
layer overlaps, seams, fastenings and exact original designs need further art
review. Finite pose/projection tests do not prove universal triangle collision,
arbitrary combinations, body shapes or cloth simulation. Coverage is distinct
from owner approval and final per-item fidelity.

Ranged string/arrow/reload detail, exact support-hand contact and weapon-specific
two-handed stances remain. Shields do not reproduce every original crest.
Jewellery needs close-up review; exact partial-hue masks for every design and
extended protocol variation fidelity remain separate worklists. Rejected
dress/apron/surcoat experiments are not mapped or counted. Server race-class
audits, monsters/animals and mount integration remain outside this human batch.

Concurrent world/editor work, original prototype, installed UO data, credentials,
server core and saves are excluded from this character change.
