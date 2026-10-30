# Horses and magical equines — first expansion

This batch reuses the existing **Warhorse Lite 1.0.0** geometry, 39-joint rig,
four publisher clips and the existing authored gallop/hit/death and rider contact
work. It adds category replacements for eleven more loose-body identities and
two item-only ethereal mounts. The original four horses remain in their existing
regression suite. The human wearable count stays **732/1,126 (65.01%)**.

The catalogue is `Viewer/Presentation/EquineRegistry.gd`. Of the **26 indexed
equine body IDs**, **15** now have routes; **11** remain explicitly deferred.
These counts are body identities, not species, bespoke models, final artwork or
complete animal animation libraries. All three nightmares share the current
mane and geometry. Faction coats are modern material interpretations; exact
native mane, barding and ornament remain art work.

Owner-authorized proportion changes give the pack horse a 9% broader, 3% shorter
build, nightmares a modestly larger frame, and unicorns/silver steeds slightly
slimmer/taller proportions. Fire steeds grow 2%. These are visual profile scales;
native coordinates, picking authority, stats and speed are unchanged. Accessories
use scaled bind space, hoof support scales with height, and both human riders
must still meet the existing saddle/stirrup tolerances.

| Loose body | Native ridden item | Replacement |
|---|---|---|
| 0xC8 / 0xE2 / 0xE4 / 0xCC | 0x3E9F / 0x3EA0 / 0x3EA1 / 0x3EA2 | Existing tan, grey, dun, brown horses |
| 0x74 / 0xB2 / 0xB3 | 0x3EA7 / 0x3EA9 / 0x3EB7 | Dark nightmare coat, fitted ember eyes |
| 0x75 | 0x3EA8 | Silver steed |
| 0xBE | 0x3E9E | Warm fire steed, bounded glow and neck-bound embers |
| 0x7A | 0x3EB4 | Ivory unicorn, original spiral horn bound to its head |
| 0x76 / 0x77 / 0x78 / 0x79 | 0x3EB2 / 0x3EB1 / 0x3EAF / 0x3EB0 | Four faction warhorse identities/coats |
| 0x123 | None | Pack horse with two spine-bound leather panniers; unrideable |
| No loose body | 0x3EAA | Ethereal horse, using ordinary horse rig proxy |
| No loose body | 0x3E9B | Ethereal unicorn, using unicorn rig proxy |

Ethereal statuettes **0x20DD/0x25CE are item IDs, not creature bodies**. Their
mounted item and server hue remain exact. The server's default spectral marker
**0x4001** selects spectral rendering instead of a `hues.mul` palette lookup.
Native full/partial hue flags remain intact. Ordinary opaque coats keep the
existing fur-region tint and original tack. Only ethereal profiles use the
transparent shader. Cosmetic effects do not grant abilities or affect gameplay.

Male/female art fixtures exercise fit, independently of server permissions.
ModernUO's Unicorn disallows male riders; the client never overrides that rule.
PackHorse remains a BaseCreature with an inventory, not a newly invented mount.
Ethereal dismount returns its item; no loose horse is fabricated.

## Deferred catalogue and free alternatives

| Bodies/items | Reason / next action |
|---|---|
| 0x84 / 0x3EAD; ethereal item 0x3E9C | Ki-rin needs a distinct silhouette, mane/tail and fitted geometry. A horn alone is insufficient. |
| 0x319 / 0x3EBB | Both HellSteed and SkeletalMount use this native appearance. Requires real skeletal geometry and retargeting; class/stat guesses cannot distinguish the same wire identity. |
| 0x72, 0x73, 0xB1, 0xBF, 0xC0, 0x312 | Body.def horse substitutions are not verified species or ridden-item pairs. Audit before routing. |
| 0x11C, 0x57F, 0x580 | Client-comment identities (Mondain's steed, Horse_Unicorn_RB, Horse_Palomino); active pinned-server meaning and geometry remain unverified. |

Primary artist/library pages researched on 30 October 2026:

- [Warhorse Lite — Literock Studios](https://literock-studios.itch.io/warhorse-lite):
  reused, already locally installed. **Custom Warhorse Lite Free Licence**, not
  CC0. Game use/modification permitted; standalone raw-asset redistribution
  prohibited. Exact archive/member SHA-256 pins are in `scripts/horse-inputs.json`.
  The original GLB remains unchanged; existing region annotations are retained.
- [Horse Skeleton, Rigged, UnTextured — neurocase / Daz Petty](https://blendswap.com/blend/11233):
  artist declares **CC0**, around 7,000 faces, Blender 2.6x. The download page
  requires sign-in. **Not downloaded, not retargeted, not counted**. No claim
  about runtime quality from its description alone.
- [Low Poly Animated Unicorn — T Allen Studios](https://opengameart.org/content/low-poly-animated-unicorn):
  **CC-BY 4.0**, idle and walk offered. Not selected: reusing our existing rig
  retains its broader motion/contact work and a consistent visual baseline.
- [Ki-rin — Filip / Meshy](https://www.meshy.ai/3d-models/Fantasy-Highly-Detailed-High-resolution-Create-a-Kirin-mythological-creature-from-asia-v2-01955170-c7c2-7505-9f73-d75c4adb2801):
  this exact public listing declares **CC0** and identifies Meshy-4 generation.
  Candidate only: no source file acquired, topology/rig/animations not verified,
  and suitability for UO's silhouette not established. A licensed download plus
  static inspection must precede import. Paid/NC/Monster Hunter rip candidates
  were not used.

The horn, bags, straps, buckles and ember construction are original project
procedural code under GPL-3.0-or-later. There are no new downloaded art inputs in
this batch. Reuse does not relicense the underlying Warhorse. Generated art and
screenshots remain ignored; a Git clone still needs the documented asset setup.

## Reproduction and evidence

```powershell
./scripts/prepare-horses.ps1 -VerifyOnly
python -B scripts/audit-equines.py
./scripts/test-equines.ps1 -Gpu
# Approved disposable native server; never the production runtime:
./scripts/test-horses.ps1 -Live -SkipContact -Equines
./scripts/review-equines.ps1 -Capture
./scripts/verify.ps1
```

`Review-Equines.cmd` opens the interactive 17-panel review. The finite capture
mode writes **34 real rendered frames**, walking and running/side, to ignored
`outputs/equines/index.html`. Ethereal panels intentionally have only riders.
The native audit compares actual constructors, variant assignments, pack-horse
inheritance and ethereal IDs against ModernUO revision
`ab59efea86fd9e399d261bed9d188ab4d95ad4c2`, recording source and registry hashes.

Accepted evidence in ignored `outputs/equines/`:

- `validation.json`: **4,537 checks / zero failures**, **1,152 rider poses**
  across both human bodies, three outfits, all 16 supported ridden items,
  walk/gallop/rear and four phases. Seat error stays below 2 mm, stirrup errors
  below 25 mm; accessories follow actual animated bones. Fifteen additional
  physics samples cover all five scaled profiles on flat and modest slopes,
  with stance-hoof errors below 45 mm.
- `appearance-validation.json`: **158 GPU checks / zero failures**. Two angles
  and two full native dyes on all 15 opaque body routes; over 98% tack retention,
  visible horn/panniers, actual ethereal background transmission and restored
  opaque rendering. Raw partial hue/0x4001 retention also has runtime evidence.
- `live-validation.json`: **581 native checks / zero failures**, 26 class/sex
  cases on the disposable pinned server. Actual account creation/world entry,
  ordinary native double-click/casting, mount item and hue replication, rider
  contact, server-confirmed walk/run plus return routes, and dismount on both
  clients. Includes male Unicorn refusal, unrideable PackHorse, and item-only
  ethereals without a fabricated loose mobile. These checks do not certify
  taming balance, combat abilities or a populated production shard.
- `index.html` / `captures.json`: **34 actual Forward+ frames**, with loose
  animals and both rider/outfit examples, plus ethereal-only rider panels.
  These local visual fixtures are not themselves multiplayer evidence.
- `work/equine-full-verify.log`: full `scripts/verify.ps1` **exit 0**, including
  **2,468 original horse checks / 768 contact poses**, **267 horse-polish
  checks**, **1,759 human coverage checks**, and the new equine tests. Two existing
  TimberBridge fixture missing-`id` script errors, Unicode/fuzz/teardown and
  PreviewTools nullable diagnostics remain in the shared suite. Exit 0 is not
  a claim of a diagnostic-free run; new equine tests report no failures.

The review images are a finite prototype art review, not final native fidelity
or proof of every garment/horse triangle combination. No additional animation
categories are counted by this batch. The concurrent item pass already supplies
ordinary-horse corpse presentation; expanded equine corpse routing and the
remaining animal action library are separate work.

Remaining work: acquire/fit skeletal and ki-rin art, resolve historical aliases,
review exact coats/manes and pannier detailing, complete eat/lie/fidget and corpse
coverage, then package a versioned client with licensed assets and a clean-install
test. No world population, server core, taming/combat rules or original UO files
are changed here.
