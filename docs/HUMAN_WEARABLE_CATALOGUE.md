# Human clothing and action worklist — 28 October 2026

Latest checkpoint: **HUMAN_CIVILIAN_BATCH.md** adds doublet, cloak, low shoes and
sandals, bringing equipment to **20 categories / 86 of 1,126 indexed graphics**.
Long hair/ponytails now retain their tails over garments and headwear, with
cloak-specific bindings. Current replacement part names appear in the worklist
and item/action CSV. Full project verification and sampled checks pass; current
live re-entry is blocked by connections aborting before login. Details below
describe the preceding skirt/shirt/headwear batch unless stated otherwise.

Current scope is human players and human NPCs, bodies 400/401. Monsters and
animals are outside this batch. ModernUO remains authoritative for identity,
equipment layers, item serials, graphic IDs, hues, hair/beard fields and stats.

## Review and tracking

Run `Reviews/Review-Human-Catalogue.cmd` to rebuild/open the local searchable worklist.
Its source data stays in ignored `outputs/human-catalogue/`:

- `index.html`: classic actions, extended sequence rows and wearable graphics.
- `human-animation-groups.csv`: all 35 classic PeopleAnimationGroup entries.
- `human-extended-actions.csv`: installed human/equipment UOP mode/type/subaction rows.
- `human-wearables.csv`: 1,126 wearable-flag graphics with layers, animation
  references, equipment conversions, category coverage and eligibility caveats.
- `wearable-action-matrix.csv`: 39,410 item/action review rows. Pending review is
  explicit; a fitted family is not individual item/action acceptance.
- `human-port-catalogue.json` / `human-uop-sequences.json`: archive SHA-256s,
  structural MUL evidence, decoded UOP metadata, counters and limitations.

The public registry `Viewer/Presentation/human-animation-catalogue.json` keeps
action names, priorities and fidelity notes. The worklist obtains current
replacement mappings directly from HumanActions and HumanWardrobe. Update the
mapping and registry with each accepted batch, rebuild, and record actual
validation here and in PROGRESS/ROADMAP.

The preceding audit had 84/1,126 graphics mapped to category art. This denominator
includes racial candidates and is not a complete census of ModernUO item
classes. Names identify obvious non-human candidates, but server class/race
restrictions still require an audit. Native IDs are never rewritten to match art.

## Preceding skirt/shirt/headwear batch

Adds three fitted categories for both bodies: knitted civilian shirt, soft cap
and cloth hat. Shirts 0x1517/1518 and fancy shirts 0x1efd/1efe now use the civilian
shirt instead of mail; cap 0x1715 and floppy hat 0x1713 use the two headwear
substitutes. Together with the existing wardrobe this is 16 equipment meshes,
five hair families plus bald, and four beard components covering seven IDs.
The new garments are category substitutes, not faithful replicas of the native
shirt collars or floppy brim. A bodice candidate failed the doublet/layered
review and is not installed; doublets retain their prior category fallback.

Shirts are concealed beneath the existing mail/robe layers. Headwear conceals
hair without changing its native identity/colour. The new parts use the same
61-joint live skeleton and per-instance native 32-entry dye palettes, including
partial-hue handling. Received NPC/player tint updates preserve walk phase and
independent hair/beard colours. Skin remains the existing three approximate
presets; this batch does not solve full native skin-tone fidelity.

Two original fidget groups now have finite replacements: classic 5 uses
Fidget_Talk (UAL1 Idle_Talking_Loop), classic 6 uses Fidget_Look (UAL2 Idle_No_Loop).
Both bodies now carry 45 prepared clips; 23 of the 35 classic groups have
category playback. Ranged attacks, turn, salute and the third fidget remain
pending; seven mounted rider groups are catalogued and deferred. Several
connected groups share a substitute, including two-handed readiness and the
two death directions. A connected group is not proof of original pose fidelity.

## Skirt fitting

Robe, long skirt and kilt use anatomical pelvis/leg samples for the static fit
and motion envelope. A height-only selection had included A-pose fingertips,
which could inflate cloth when arms moved alongside the thighs. Fitting now
excludes those samples, narrows the thigh section, compresses excessive pleats,
retains the waist join/sleeves, and rebakes the eight existing garment controls.
UVs, the native body/bind and retained leg geometry remain unchanged. In the
matched Idle thigh band, skirt widths fell 28.3% (male) / 35.8% (female), and kilt
widths 23.4% / 36.9%. The female robe fell 10.8%; the male robe stayed within
0.4% of its previous width rather than being squeezed unnecessarily. Deformation
is fitted skinning, not cloth simulation or arbitrary-body support.

The independent checks include a bounded Idle thigh-width measurement as well
as leg enclosure, floor clearance and female sleeve landmarks identified by
arm weights. Source geometry at similar height is not automatically a cuff.
Visual review is still necessary: vertex enclosure alone cannot certify cloth
drape, triangle intersections, every layer combination or all 45 actions.

## Sources and reproduction

All selected inputs remain private/local and hash-pinned. Code, source URLs,
licences and archive/member hashes are tracked; artwork and rendered evidence
are not committed.

Evidence for this checkpoint: 102 exported part/mask models; 90 prepared clips
with unchanged 61-joint binds and body error below 0.000001 m; 816 modern cloth
poses plus 192 native skirt/kilt and 96 native robe poses; eight synthetic UOP
parser tests; 20 new wardrobe/dye checks and 60 motion checks. Full project
verification passes. Dedicated local server re-entry, robe removal/re-equip,
underlying female shirt/kilt, reconnect, observer updates, war/peace and bow
playback pass; native login/relay checks pass. These were existing test characters,
not a new creation run. Logs are `work/human-wardrobe-batch/verify-accepted.log`,
`live-accepted.log`, `asset-checks6.log`, `shirt-final.log` and `final-motion7.log`.
The catalogue has 17 selected sequence records, 39 body mode/action rows and
293 equipment mode/action rows, with no structural parse blockers. Opaque fields
are still opaque. The fast rebake path was checked on isolated copies: 7,155
native animation curves per body survive with at most 0.0000015 numeric error.

- [Official MakeHuman shirts01 catalogue](https://static.makehumancommunity.org/assets/assetpacks/shirts01.html):
  MargaretToigo, Fisherman sweater, CC0. The rejected bodice source remains
  pinned as research evidence and is not an accepted runtime part.
- [Official MakeHuman hats01 catalogue](https://static.makehumancommunity.org/assets/assetpacks/hats01.html):
  jujube newsboy cap and Aethelraed_Unraed cloche hat, CC0. Their floral/default
  material is replaced with the project's traced CC0 linen/fabric maps.
  The cap proxy contains a legacy AGPL3 template header; the official pack and
  per-asset metadata classify this selection as CC0. Input headers are preserved.
- `scripts/character-expansion-inputs.json` pins the exact archives and members;
  `download-character-expansion.py` verifies/extracts static inputs only.
- Existing skirt/robe/body/skin sources: CHARACTER_EQUIPMENT_EXPANSION.md and
  CHARACTER_FOUNDATION_POLISH.md. Motion sources: `human-motion-inputs.json`.
- [Pinned ClassicUO animation reference](https://github.com/ClassicUO/ClassicUO/blob/ee79d7ebc1cc0e53ff84fe6cae17d389e2737f93/src/ClassicUO.Assets/AnimationsLoader.cs):
  PeopleAnimationGroup enum, People MUL offset and LoadUop layout commentary.
  This is a read-only reference, not a linked dependency.

Prepare both sexes with Blender factory startup, running
`prepare-free-equipment.py` then `prepare-character-expansion.py` (append
`-- --female` for the second body), followed by `prepare-human-motion.ps1`.
For later fitting-only iterations, `rebake-human-cloth.py` rebakes the eight
garment tracks in already prepared motion; it does not retarget the human joints.
Run `prepare-human-motion.ps1 -VerifyOnly`, `validate-character-expansion.py`,
the Blender robe/skirt validators, and `scripts/verify.ps1` afterward.

`HumanWardrobeCatalogue.gd -- --jobs=<absolute JSON path>` renders the actual
shared runtime bodies/materials into paired review images. Jobs specify output,
camera height/centre, dimensions, body/skin, native equipment/hues, action and
phase. The current local jobs and rendered evidence are under
`outputs/human-wardrobe-batch/`; no artwork is embedded in the source registry.

The UOP inspector validates directory/payload bounds and compression, decodes
sequence replacement/mode/action records, and reports unknown tails/blockers.
Only bodies 400/401 and references declared EQUIPMENT in installed mobtypes.txt
are selected. Unknown flags and skipped opaque fields are not interpreted;
fallback/mode meanings follow the reference commentary rather than verified
server behaviour. Primary MUL counts are structural evidence, not final
DEF/bodyconv/UOP precedence. AnimationFrame archives are inventoried, not
converted. The current input has a human sequence record for 400 and none for
401; no aliasing explanation is asserted from that absence.

## Next batches

Current visual limits include deep/source fold creases and mail/skirt waist
overlap in some layered poses. A narrow silhouette and sampled enclosure do
not establish natural cloth drape. Exact per-handle grips, two-handed/ranged
motion, additional body shapes and full native skin hues remain open.

Prioritize proper doublet/vest and shirt designs, cloak, sandals/shoes, leather
torso/arms/gorget, shields and ranged weapons. Accept a small batch only after
male/female fitting, native layer/hue updates, walking/armed/casting checks and
rendered review. Resolve two-handed/ranged/turn/salute actions in parallel with
the relevant equipment category. Then audit exact per-item silhouettes,
racial eligibility and every garment/action row. Mounted riders remain a later
human dependency; monster and animal families remain out of this workstream.
