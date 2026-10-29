# Human accessories batch — 29 October 2026

Seven additional human equipment families are connected on both accepted bodies: bonnet, feathered hat, tricorne, jester hat, chain coif, spellbook and handheld lantern. These fill actual indexed catalogue gaps. The result is **246/1,126 graphics (21.85%), 72 categories**, up from 234/1,126 and 65 categories. The thirteen identities below include twelve previously missing graphics and one corrected mapping. Human actions remain 35/35 classic categories, 28/28 on foot and seven supported ordinary-horse rider groups; this batch adds no action categories or monsters.

| Family | Native graphics | Rendering / layer |
| --- | --- | --- |
| Bonnet | `0x1719` | Cloth cap, gathered rim and chin ties; head |
| Feathered hat | `0x171A` | Turned brim, band and solid feather vanes; head |
| Tricorne | `0x171B` | Three folded brim sections and bound edge; head |
| Jester hat | `0x171C` | Three drooping points and metal tips; head |
| Chain coif | `0x13BB`, `0x13C0` | Face opening and neck cowl; head. `0x13C0` incorrectly selected a tunic before this batch. |
| Spellbook | `0x0EFA`, `0x0E3B` | Bound covers, page block, spine bands and corners; native right hand |
| Lantern | `0x0A15`, `0x0A17`, `0x0A18`, `0x0A22`, `0x0A25` | Metal frame, handle and candle; native left hand. `A15/A17/A22` select an emissive flame, `A18/A25` select the unlit model. |

ModernUO remains authoritative for identity, equipped layer and hue. The pinned `Lantern.cs` explicitly distinguishes these lit/unlit identities; `BaseEquipableLight` uses TwoHanded (the native left-held layer). The standard spellbook uses OneHanded; the legacy `0x0E3B` entry shares the installed catalogue's spellbook animation reference 984 with `0x0EFA`. Other book schools and unreviewed lantern graphics remain gaps. No server mechanics, item statistics, spell contents, light radius or world lighting are invented by these models. The flame is emissive art only.

## Construction and sources

All new accessory topology is original parametric geometry in `scripts/human-tailoring.py`. No proprietary model, texture or animation is copied. Original generator code and authored accessories follow the project's GPL-3.0-or-later terms; selected CC0 foundation/material inputs retain their notices. Exact consumed-input hashes and upstream reference paths/revision are in `scripts/human-tailoring-inputs.json`.

- The accepted body/rig is CC0 MakeHuman art from [CharacterCreator revision 852e48f](https://github.com/kblood/CharacterCreator/tree/852e48f316b90a0937234886630e4fb4cdfd1f78). Existing body vertices, UVs, binds and the 61-joint skeleton are unchanged.
- Woven normals use the existing traced CC0 MedievalKit/ambientCG Fabric045 input; source/member hashes and attribution are retained in `Viewer/Art/MedievalKit/CREDITS.md` and the input manifest. Existing coverage material inputs retain their prior provenance in `docs/HUMAN_COVERAGE_SOURCES.md`.
- Long/ponytail coif derivatives retain the accepted CC0 hair's UV/alpha and bindings. Only posterior tail clearance below ear level changes, by at most 22 mm. Separate cloak derivatives preserve the prior cape fitting. Source hashes, recipe hashes and exported hashes are recorded locally in each expansion provenance file.
- The book and lantern bind rigidly to their actual holding hands. A bounded arm reach adjustment preserves the source walking swing and closed fingers while clearing the hip. Riding retains the available rein hand and existing saddle/stirrup fitting. Native dye shaders preserve the lantern's emission rather than extinguishing it when tinted.

All generated GLBs, private source inputs, renders and evidence stay in ignored `Viewer/local-art/`, `work/` and `outputs/`. The source generator, manifests, routing, tests and documentation are versioned. No new downloads or upstream changes were needed.

## Evidence

- **16 accessory exports and eight coif hair derivatives:** source/output hashes, normalized finite geometry, compatible named joints and provenance validated.
- **995 runtime/GPU checks, 448 views, zero failures:** seven families × two bodies × walking/running × on foot/riding × two phases × four angles. Includes actual closed-finger measurements, saddle/stirrup contact, independent native hair/hues, and five lantern identities with default/full/partial hues. The flipped coif retains its head layer.
- **256 hair views, zero failures:** long hair and ponytail, both bodies, all seven additions plus coif/cape layering, walking/running and actual seated poses. At least 98% of reference tail pixels retained, with the complete body in both renders. Low drapes and the posterior ponytail shaft are classified in the fixed bind; scalp wisps belong beneath headwear.
- **32 actual posed geometry checks, zero failures:** every book/lantern vertex, triangle centroid and edge midpoint tested against posed shirts/trousers in both bodies' walking/running/riding samples. No triangle-interior penetration beyond 5 mm. Open cuff boundaries and intentionally grasping hands are excluded. Sleeve occlusion in a rear/edge-on image is legitimate and is not treated as a collision.
- **32 actual engine review frames**, including front/rear views and lit/unlit lanterns; two sheets and a local gallery in `outputs/human-tailoring/`. Captures await a completed render frame.
- Catalogue regeneration keeps the denominator at 1,126, with 39,410 item/action rows and 332 installed UOP mode/action metadata rows. Category mapping is distinct from exact original ornament, full action variation fidelity and owner art approval.

Final full verification and login results are recorded in the latest `PROGRESS.md` entry. These are finite art/pose checks. This batch does not claim new live server world-entry or multiplayer evidence; the existing native appearance integration is reused.

## Reproduce

From the repository root, with the already installed pinned foundation:

```powershell
./scripts/prepare-human-tailoring.ps1 -Gpu -Review
./scripts/build-human-catalogue.ps1 -NoOpen
./scripts/verify.ps1
./scripts/test-login.ps1
```

`-VerifyOnly -Gpu -Review` reuses prepared meshes. The wrapper verifies pins, builds both sexes and coif hair, imports, validates the exports, runs real GPU/hair tests, checks the captured final modifier poses in Blender, and renders the review. Assemble sheets with a Pillow-enabled Python and `scripts/review-human-tailoring.py`. The established full `prepare-human-coverage.ps1` also builds these categories and coif hair derivatives.

Local evidence: `asset-validation.json`, `gpu-validation.json`, `hair-validation.json`, `prop-poses.json`, `prop-geometry.json` and `index.html` under `outputs/human-tailoring/`. Logs are `work/tailoring-*.log`. These paths contain original/free-art evidence and stay ignored.

## Remaining gaps

Full/half apron and body sash prototypes failed seated garment occlusion and visual review. They are **not mapped, shipped as supported equipment or counted**. Their local rejected renders and pose-fitting log are retained for diagnosis. Nearest-surface weight transfer and large bind-space pushes produced clipped or creased waist/lap fabric; repeating that approach does not establish a finished garment. Revisit matched undergarment topology/weights, a stable waist seam and separately authored lap panels before mapping these identities. Never hide additional body triangles to pass this check.

The next clothing batch still needs aprons, sash, surcoat and dresses, followed by missing armour and weapon families. The book is a closed carried model; school-specific covers, opening/page/casting interaction and specialised grips remain art work. The lantern has no glass simulation or swinging handle physics. These are tested category replacements awaiting owner visual review, not final per-item fidelity or universal cloth/prop collision coverage.
