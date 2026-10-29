# Ordinary horses and human riders — 29 October 2026

**Latest milestone:** four matched native base coats, full/partial hues, leg-over mounting/dismounting, gait/ground/rein improvements and fitted riding garments are implemented. See [HORSE_POLISH.md](HORSE_POLISH.md) for the current evidence and remaining gaps. The first-batch account below is retained as the baseline and source/licence record; its shared-coat and simple-transition limitations are superseded by that milestone.

Ordinary horses now render as genuine skinned 3D animals, alone and under male/female human riders. Mounting, dismounting, ownership, speed and world position remain controlled by pinned ModernUO. Double-click an owned horse to mount; double-click the rider to dismount. The client consumes native mobile/equipment updates and the layer-25 mount item; it never invents ownership or a successful mount.

## Implemented scope

| Native horse body | Native mount graphic | Presentation |
| --- | --- | --- |
| `0xC8` | `0x3E9F` | Shared dark-bay warhorse |
| `0xE2` | `0x3EA0` | Shared dark-bay warhorse |
| `0xE4` | `0x3EA1` | Shared dark-bay warhorse |
| `0xCC` | `0x3EA2` | Shared dark-bay warhorse |

These identities follow `Horse.cs` in ModernUO revision `ab59efea86fd9e399d261bed9d188ab4d95ad4c2`. Exact coat variants are still missing. Native full/partial hues pass through the existing hue palette. Unknown mount graphics remain explicitly deferred; they are not silently replaced with this horse.

The animal uses its actual idle, walk, canter and rear source clips. Faster travel uses a paced canter, not a separately authored gallop. The human's seven prepared rider groups (classic 23–29: walk, run, idle, attack, bow, crossbow, pat/slap) are connected when this horse art is installed. The rider follows the animated saddle socket; two-bone fitting holds feet at calibrated stirrup targets and free hands at reins. Occupied hands retain equipment grips. The rider's visual offsets never move the authoritative world root. Camera height, nameplates, picking and remote interpolation account for mounted bodies. Server timing is 200/100 ms mounted walk/run, with the existing small client pacing guard.

Mount/dismount currently use short pose/position blends, not an authored leg-over/climb sequence. Rear-up is available in the review, not claimed as a native server command for every horse. Horse jump, hit, death and a full gait/transition library remain future work. Other mount families, exact coats, detailed tack, slope/hoof fitting and further rider action polish are not complete.

Robe/skirt/kilt use six separately generated riding variants, preserving their existing upper garments and adding split leg-following panels. Robes retain opaque trousers beneath them; hard leg plates are represented by that lining while covered. Native item identity, stats and hue remain unchanged. These are functional prototype riding cuts, not final tailoring or cloth simulation. Standing garments and original body UVs/binds remain intact.

## Source and licence

[Warhorse Lite 1.0.0](https://literock-studios.itch.io/warhorse-lite), Literock Studios / Literock Ventures, free publisher upload `19716484`. Optional credit: **Warhorse by Literock Studios**. The publisher describes a Meshy-generated base produced on its paid plan, followed by rigging and animation work. This is not a CC0 or hand-sculpted asset claim.

The custom **Warhorse Lite Free Licence** permits modification and commercial game/end-product use. It prohibits standalone asset redistribution/re-upload; distribution must be inside the permitted packaged/compiled end product. Raw ZIP, GLB, textures and licence copy therefore remain in ignored local folders, not the public source repository. Source retrieval, the full local licence and the input manifest remain part of the reproducible setup.

| Input | SHA-256 |
| --- | --- |
| `Warhorse_Lite_v1.0.0.zip` | `39cf8dcbe73290fc015bbdbb8ad34e8a8e55ba3f40b2f8410dc14f5d57122f08` |
| `Warhorse_Lite/Warhorse_Lite.glb` | `745ccfa9dc9fa390496e7147d258fc390a791c914653779194a26da7e1386fcc` |
| `Warhorse_Lite/LICENSE.txt` | `d712b245c62affbbe3acc7be55f0056799e8512d447136aa5a4ff91846ae0698` |

Static GLB inspection measured **10,607 vertices, 9,916 triangles, 39 joints**, normalized skin weights and four animation clips. The publisher's advertised triangle total is 9,938; our count is the actual selected GLB primitive indices divided by three. The original clips are `idle_loop`, `walk_loop`, `canter_loop`, `rear`; Godot imports their usable names as `idle`, `walk`, `canter`, `rear`. Saddle, mouth and stirrup bones are used directly. Only pinned static data/text members are extracted; no bundled executables or scripts run.

Exact archive/member hashes are in `scripts/horse-inputs.json`. Riding garment body/mesh/linen hashes are in `scripts/horse-riding-inputs.json`; the existing CC0 provenance chain is preserved. Generated files record their input and recipe hashes under each ignored `riding/provenance.json`.

## Reproduction and review

From the repository root in PowerShell, after the existing male/female body and wardrobe setup:

```powershell
# Retrieve the free archive, inspect pinned members, prepare riding garments.
./scripts/prepare-horses.ps1
# If the publisher rate-limits direct downloads, download its free ZIP in a
# browser and pass its actual location instead:
./scripts/prepare-horses.ps1 -Archive 'C:/path/to/Warhorse_Lite_v1.0.0.zip'
./scripts/prepare-horses.ps1 -VerifyOnly
./scripts/test-horses.ps1
./scripts/test-horses.ps1 -Live
./scripts/review-horses.ps1
```

`Review-Horses.cmd` opens the local visual review. Controls cover stand/walk/travel/run, rear, mounted sword/bow/crossbow/pat, robe/armour, mounting and camera angles. This stage uses local fixtures; it is not evidence of multiplayer by itself. `HorseClothingTests.gd` requires actual GPU rendering (run without `--headless`). The standard `scripts/verify.ps1` also runs horse contact tests when the licensed art is present. `CharacterCoverage.gd` followed by `scripts/build-human-catalogue.py` refreshes the local human catalogue.

The live test builds a small separate fixture extension and a disposable ModernUO runtime at `work/horse-session/server`, listening only on loopback port **2594**. It copies server binaries/Data and expansion selection, not production accounts, saves, journals or credentials. It creates two ordinary test characters in the actual world, uses genuine owned upstream Horse mobiles and native double-click requests, then stops only its own process. The fixture command requires an explicit isolated-test setting, a loopback connection and the test-account prefix. It is never installed into the production runtime. Port **2593**, remembered login, ModernUO source and the original UO installation are unchanged.

## Evidence and limits

Local, ignored evidence is under `outputs/horse-session/` and `work/horse-session/`:

- `asset-validation.json`: hashes, actual geometry/rig counts and four source clips; zero failures.
- `contact-validation.json` / `contact-final.log`: **2,468 checks pass**, including **768** sampled saddle/stirrup poses across both sexes, four identities, three outfits and eight rider/horse combinations. Seated pelvis tolerance 2 mm; stirrup target tolerance 25 mm. Measurements are taken inside the skeleton modifier after fitting.
- `clothing-validation.json` / `clothing-gpu.log`: **384 GPU views pass**, both sexes, plate/robe/skirt/kilt, six mounted action pairs, two phases and four angles. A magenta-skin probe and independent full-body opacity reference check body/seat coverage. This is finite visual coverage evidence, not proof that every pair of garment/horse triangles never intersects.
- `live-validation.json` / `native-test9.log`: **270 native checks, zero failures**. Both sexes and all four horse identities: real world entry, mount mobile removal/layer-25 equip, mounted walk and run with changed server positions, rider actions, dismount/horse return, and corresponding updates received by the second client.
- `horse-riders-walk.gif`, `horse-riders-final.png`, `rear.png`, `riding-robe-final.png`: actual Godot Forward+ renders. The GIF contains 48 captured frames from the local animation review, not generated imagery.
- Existing human coverage remains **761/761**; catalogue now records **35/35 connected classic categories**, including **7/7 ordinary-horse rider categories**, **28/28 on-foot**, and unchanged **234/1,126 wearable graphics (20.78%)**. This measures category replacements, not exact per-item art or every server action variation.

Project verification and native login/relay checks were also run. The shared front-end/fuzz tests pass their assertions but still emit resource-leak diagnostics during shutdown; those diagnostics are separate from the horse tests. The login/relay smoke alone is not called a world-entry or multiplayer test. The separate 270-check horse run supplies that evidence. Remaining visual approval and full mount/action coverage are still open.
