# All-creature modernisation programme

Owner direction, 30 October 2026: apply the approved desert-ostard treatment to **all creature families, equines first**. Preserve recognisable UO identities; reuse suitable accepted modern assets for generic species. Keep native server appearance, stats, actions and permissions authoritative. This is an ongoing programme, not a completed creature port.

## Current batch: the complete preserved ostard family

Desert was approved by the owner. Forest, frenzied and ethereal now have their own high-detail atlas and original/refined/material comparison. All four retain 24 bones and seven imported desert-source clips, with independent deformation tests on each body. Each refined mesh has 1,490 geometric vertices and 2,960 triangles. Three new textures are 1,254-square, edited with built-in imagegen from their own original atlases; UV registration still requires visual review.

The ethereal variant uses a separate translucent/emissive shader. Other skins remain opaque. Raw hue bits are retained; ethereal 0x4001 is excluded from palette dyes. These are local previews, not new server body/mount routes.

Evidence: **27,741 checks / 1,008 sampled skinned poses** across four forms, including the added spectral-marker checks. Each of the three new forms passes actual Forward+ and Compatibility normal, roughness, light and dye image-response tests. Each has 31 stills and 96 sequence frames (93 stills / 288 frames added); walk/run GIFs preserve source clip timing. All captures are actual Godot output. Existing flat-floor/root-motion limitations in OSTARD_TRIAL.md still apply.

The full `scripts/verify.ps1` completed with exit 0. The existing unrelated bridge missing-id, malformed-Unicode and teardown diagnostics remain. The final extra spectral-marker assertions were also rerun directly on all four forms. This is not a diagnostic-free whole-project run.

Review `outputs/ostard-trial/family.html`, or use Review-Forest-Ostard.cmd, Review-Frenzied-Ostard.cmd and Review-Ethereal-Ostard.cmd. All generated textures, exact final prompts and per-form input/output/recipe hashes are saved under `Viewer/local-art/ostards/<kind>-modern-albedo-v1.png`, `<kind>-modern-albedo-v1.prompt.txt` and `<kind>-provenance.json`. These and all captures remain ignored/local. Source and recipe changes alone go to Git.

## Whole-source queue and limitations

Reproduce the new forms with the saved local atlases and pinned archive:

```powershell
foreach ($kind in @('forest','frenzied','ethereal')) {
  python -B scripts/prepare-third-dawn-ostard.py --kind $kind
  ./scripts/review-ostard.ps1 -Kind $kind -Validate -Capture
  ./scripts/review-ostard.ps1 -Kind $kind -Sequence
  ./scripts/review-ostard.ps1 -Kind $kind -MaterialTest
  ./scripts/review-ostard.ps1 -Kind $kind -MaterialTest -Compatibility
}
# Python with Pillow, as supplied by the bundled workspace runtime:
python -B scripts/build-ostard-gallery.py --kind all
python -B scripts/audit-creature-sources.py
```

`scripts/audit-creature-sources.py` audits every Animals/Monsters LOD2 mesh in the pinned Alpha Build 35 ZIP. Local exact-member/hash/texture/clip-candidate evidence: `outputs/creature-sources/inventory.json`. **147 meshes / 51 filename-based source groups**, including variants; **eight still fail diagnostic parsing**, and **six parsed candidates reference absent textures**. This is not the full modern UO mobile/body-ID catalogue or an implementation percentage. Later additions and bodies missing from this early archive need other sources. Same-family clip filenames are candidate leads, not proven rig/deformation compatibility.

Ki-rin diagnosis: 137 vertices, 30 bones, 272 original triangles. All six invalid normal vectors belong to two repeated-vertex triangles or unused entries. The opt-in diagnostic copy removes those two zero-area triangles (which cannot acquire area under skinning) and makes unused normals finite: 270 usable triangles. All positions, UV coordinates, bone data and weights remain unchanged; the strict shared importer is not weakened. However, its referenced `kirin.tga` does not exist in this archive. No textured ki-rin export or live implementation is claimed. Acquire a matching later source texture or author/review a replacement atlas before fitting riders. The normal-repair findings are not a finished creature.

## Sequence and completion criteria

1. Finish distinctive equines: source/author the ki-rin atlas, verify its seven clips, inspect a distinct skeletal-mount candidate, then finish other historical identity gaps. Accepted horses remain in place. Fit both human riders, outfits and transitions before adding ostard/ki-rin live mount routes.
2. Animals, starting with other rideable forms (llamas), then bovines, bears, canines, deer, felines and smaller animals. Reuse good free modern assets where appropriate and keep exact source/licence pins.
3. Distinctive monsters by family: arthropods/reptiles, dragons, humanoids, undead, magical beings and elementals. Use the original source first for UO-specific anatomy; repair bounded format issues separately. Review source/upgraded motion and art before accepting each family.
4. For each family: verify identities against pinned ModernUO; acquire and trace mesh/rig/maps/clips; improve useful geometry/materials; test real animated skin vertices, native hue semantics and actual GPU output; check action/corpse variants; then integrate real server routing and test live behaviour. Maintain separate source-ready, art-review, animation-tested, rider-tested and live-integrated status. Never count a parsed file or recolour as a finished creature/action replacement.

No human/horse replacement, wearable count, remembered-login location, server rule or save changes are part of this batch. Concurrent UI/item/terrain work is excluded from its commit.

## Source family queue

| Source group | Mesh variants | Upgrade status |
|---|---:|---|
| arachnids | 4 | Queued; source preflight only |
| bovines | 4 | Queued; source preflight only |
| bruins | 4 | Queued; source preflight only |
| canines | 8 | Queued; source preflight only |
| centaurs | 1 | Queued; source preflight only |
| cyclops | 1 | Queued; source preflight only |
| daemons | 5 | Queued; source preflight only |
| deer | 2 | Queued; source preflight only |
| dragons | 7 | Queued; source preflight only |
| elementals | 9 | Queued; source preflight only |
| equines | 14 | Accepted modern horse replacements retained |
| ethereal | 1 | Queued; source preflight only |
| ettins | 1 | Queued; source preflight only |
| felines | 4 | Queued; source preflight only |
| fey | 1 | Queued; source preflight only |
| flails | 3 | Queued; source preflight only |
| frogs | 1 | Queued; source preflight only |
| gargoyles | 3 | Queued; source preflight only |
| gazers | 2 | Queued; source preflight only |
| genies | 1 | Queued; source preflight only |
| gorillas | 1 | Queued; source preflight only |
| harpies | 2 | Queued; source preflight only |
| headless | 1 | Queued; source preflight only |
| imps | 2 | Queued; source preflight only |
| kirin | 1 | Diagnostic topology repair; referenced texture missing |
| lizard | 1 | Queued; source preflight only |
| lizards | 4 | Queued; source preflight only |
| llamas | 3 | Queued; source preflight only |
| mages | 2 | Queued; source preflight only |
| mongbats | 1 | Queued; source preflight only |
| ogres | 3 | Queued; source preflight only |
| ophidians | 5 | Queued; source preflight only |
| orcs | 4 | Queued; source preflight only |
| ostards | 4 | Four local upgraded comparisons; no rider/live route |
| paladins | 1 | Queued; source preflight only |
| porcines | 2 | Queued; source preflight only |
| rat | 2 | Queued; source preflight only |
| rodents | 1 | Queued; source preflight only |
| ruminants | 4 | Queued; source preflight only |
| scorpions | 1 | Queued; source preflight only |
| serpents | 4 | Queued; source preflight only |
| shadowlords | 1 | Queued; source preflight only |
| skeletons | 3 | Queued; source preflight only |
| slimes | 2 | Queued; source preflight only |
| spirits | 3 | Queued; source preflight only |
| succubi | 1 | Queued; source preflight only |
| terathan | 4 | Queued; source preflight only |
| titans | 1 | Queued; source preflight only |
| trolls | 2 | Queued; source preflight only |
| walking | 4 | Queued; source preflight only |
| walrus | 1 | Queued; source preflight only |
