# Horse colours and riding polish â€” 29 October 2026

Delivered the owner's expansion batches 1 and 2: four server-selected ordinary horse coats, native hue handling, improved riding motion/contact, an authored leg-over mount/dismount sequence and fitted riding clothing. This is a functional polish milestone; the remaining animal/action and art-quality gaps are recorded separately in `Viewer/Presentation/horse-catalogue.json`.

## Appearance follows the server

| Loose body | Ridden mount graphic | Modern coat |
| --- | --- | --- |
| `0xC8` | `0x3E9F` | Golden tan |
| `0xE2` | `0x3EA0` | Dapple grey |
| `0xE4` | `0x3EA1` | Dun |
| `0xCC` | `0x3EA2` | Dark brown |

The mapping was matched to actual private primary-MUL stand frames, decoded by `scripts/inspect-horse-reference.py`. Its ignored JSON records archive and entry hashes, index offsets and frame dimensions. This is visual evidence from those selected frames, not a claim to have resolved every DEF/UOP override. The body/mount pairs and hue propagation come from pinned ModernUO `Horse.cs` / `BaseMount.cs` at `ab59efea86fd9e399d261bed9d188ab4d95ad4c2`.

No client randomness chooses coats. Body/mount identity and the full raw hue (including the partial flag) are retained. Zero hue uses the corresponding base coat. Full hue recolours the coat region; partial hue respects grey regions, including the grey body. These are modern PBR interpretations, not identical copies of the original pixels. Default, changed and partial hues have been tested while riding, after dismount and on observer re-entry.

`prepare-horse-regions.py` creates an ignored derived GLB with coat/tack **vertex annotations**, using the pinned source's ORM/albedo and tail weights. It does not repaint textures or alter positions, UVs, bindings, joints or source clips. Static validation verifies the original binary prefix byte-for-byte and preserves node/skin/animation/material/image records. The shader retains fur detail, dark lower legs/mane/tail and the original leather/metal response; grey dappling is subtle procedural detail. Region boundaries remain an artistic interpretation of a single combined source mesh.

The source licence, exact hashes and commercial-game/standalone-redistribution distinction remain as documented in [HORSE_RIDING.md](HORSE_RIDING.md). Raw and derived art remain ignored. No new downloaded asset or third-party animation licence was introduced in this batch.

## Motion, contact and clothing

- Gait switches preserve cycle phase, use hysteresis and blend starts/stops; pace changes ease rather than jump. Turn lean and acceleration balance affect the visual model, not the authoritative root.
- Four hoof chains sample real collision support, fit stance height and bounded sole tilt, and retain swing clearance. Body slope tilt is bounded. Tested surfaces include flat ground, approximately Â±6.9Â° pitch and Â±5.7Â° roll; steep faces are rejected. Large steps, cliffs, all terrain and universal hoof locking are not claimed solved.
- A 1.45-second authored procedural climb steps into a stirrup, lifts the free foot, swings it above/behind the saddle and settles the rider. Dismount reverses that path. Human limb reach was explicitly checked, including the shorter female body. Both foot targets must remain within 25 mm in sampled poses.
- Only a server-confirmed equip/unequip starts these transitions. An initial already-mounted world appearance seats directly. Movement can shorten a transition; on-foot actions interrupt dismount immediately; a remount updates the same visual safely. Low ceiling/side clearance skips the cosmetic climb while retaining the confirmed server state.
- ModernUO returns the loose horse at the rider's native tile. The dismounted human therefore stands beside it with a small visual offset, which eases away when moving. Camera, nameplate and picking follow that displayed body. Native coordinates, ownership, collision authority, movement pacing and equipment state are unchanged. The retired mounted horse is invisible while its sockets support the dismount; the real returned mobile supplies the visible horse.
- Free hands retain reins; occupied hands keep equipment grips. Reins transfer to the available hand or the pommel during ranged/both-hands-occupied poses. Crossbow support hands are no longer pulled away to a rein target.
- Robe/skirt/kilt now have a continuous fitted waist, narrower eased panels, small folds and a clean cut instead of disconnected old belt fragments. The riding robe keeps continuous cloth torso lining and trousers, preventing exposed skin during flexion. Native item identity/stats and robe/lining hues remain linked. Standing garments and original body/bind/UV inputs remain unchanged. These remain prototype cuts, not cloth simulation.

`HorseMotion.gd` also adds an authored **canter-derived fast gait**, a recoil and a fold/roll/hold death pose. The fast gait re-phases the limb chains and adds suspension; it is not merely a faster playback rate, and is not a newly captured gallop. Hit/death routes have runtime checks and local renders; final combat/corpse presentation and biomechanical/transition polish remain open. The source's four clips are unmodified. Eating, lying down, distinct native fidgets, jumping and other mount families are not counted complete.

## Reproduce and review

```powershell
./scripts/prepare-horses.ps1 -Archive 'C:/path/to/Warhorse_Lite_v1.0.0.zip'
./scripts/test-horses.ps1 -Gpu
./scripts/test-horses.ps1 -Live -SkipContact
./scripts/review-horses.ps1 -Coats
./scripts/review-horses.ps1 -Coats -Hue 53
./scripts/review-horses.ps1 -MountCycle
```

`Reviews/Review-Horses.cmd` opens the interactive local stage, now with coat and hue preview buttons. Those controls are fixtures, not controls that override a live server. Optional source-reference decoding needs Pillow. All downloaded/prepared assets and private evidence stay under ignored `work`, `outputs` and `Viewer/local-art` paths. Production port 2593, remembered login, ModernUO source, original UO installation and concurrent terrain/building work are preserved.

## Evidence

- `work/horse-polish/native.log`: **414 native checks, zero failures** on the disposable pinned ModernUO world at loopback 2594. Both sexes, all four identities, changed/default/partial hues, observer packets, acknowledged observer logout and real re-entry, dismount hue retention, rider actions and server-confirmed walk/run. Its fixture extension is not installed into production.
- `outputs/horse-polish/appearance-validation.json`: **134 GPU checks, zero failures**, 48 hue/angle comparisons plus 16 complete-human silhouette checks through mount/dismount/rebuild/remount. Four coats render distinctly; full/partial hue behaviour is checked; over 98% of independently identified unmasked tack pixels must retain colour (observed 100%). This does not certify every ambiguous region of the source mesh.
- `outputs/horse-polish/runtime-validation.json`: **267 checks, zero failures**, including 132 sampled mount/dismount poses across both sexes and three outfits, actual limb-target reach, safe interruptions, clearance and real slope support. Finite samples do not prove universal interpenetration freedom.
- `outputs/horse-session/contact-validation.json`: **2,468 checks**, including the existing **768** saddle/stirrup poses. `clothing-validation.json`: **512 GPU views**, now including mount/dismount, both bodies, plate/robe/skirt/kilt, two phases and four angles, with magenta skin and an independent full-body opacity reference. The continuous lining fixes the female waist gaps found while tightening the robe.
- Existing human category checks remain **761/761**. Catalogue denominators remain unchanged: 35/35 connected human classic categories for supported bodies/mounts, 28/28 on-foot and 234/1,126 mapped wearable graphics (20.78%). Animal quality and remaining actions have a separate mount catalogue.

`scripts/verify.ps1` and `scripts/test-login.ps1` were run. The shared verification exits zero and passes its assertions, but reports two script errors in the concurrent uncommitted `TimberBridge.gd:41` path for fixture dictionaries without `id`, plus the existing front-end/fuzz shutdown resource diagnostics. A read-only copy of the committed reconstruction passes the same 43 street tests without those script errors. That separate bridge work was left intact. The native login/server-list/relay smoke passes; actual world/observer evidence comes from the separate 414-check horse test, not the relay smoke.

The animation recorder now waits for the normal completed render frame. Forcing a draw inside the scene update could capture newly rebuilt skins before their render buffers were ready; the corrected recorder and the 16 silhouette checks cover that transient capture artefact.
