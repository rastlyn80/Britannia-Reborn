# Exact variant reuse and source-control terrain - 3 November 2026

Two compatible source variants can reuse existing prepared rigs/actions/support while retaining their own maps. scripts/source-variant-inputs.json pins the original target/donor meshes, maps, tables/cabinets and prepared donors. prepare-source-variants.py refuses mismatched normalized geometry/weights/UV/rest hierarchy, table scales/action profiles or original animation-body links. BakeSourceVariants.gd bundles six independent scenes without transient import-cache dependencies. An inactive donor scene label is retained explicitly. The actual saved-scene witness compares all uploaded arrays, inverse binds, rest/node transforms, complete serialized animation channels and original target RGBA, then checks native0x2006static corpses. This is compiled deformation equivalence, not a new claim of raw GRN affine fidelity or native gameplay.

Reproduce with pinned local inputs: python -B scripts/prepare-source-variants.py; Godot --headless --path Viewer --script res://Presentation/BakeSourceVariants.gd; python -B scripts/prepare-source-variants.py --check-prepared; Godot --headless --path Viewer --script res://Presentation/SourceVariantSkinTests.gd. Use the pinned console executable under .tools/godot and the established .godot-user environment. No game executable is run.

SourcePreservingCreatureVisual uses a hidden unchanged original control surface for the existing strict four-slot foot solver, while the visible conditional-bind subdivision keeps every eight-slot influence. Hidden controls never render or enter static corpses. SourceVariantPoseEntry records the most recently drawn placement separately from last submitted local bone poses, so a held source skin still has a valid visible death origin. It adds explicit80ms source-pose entry without changing native roots, original source timings after that prefix, or donor classes.

Run the shared actual-avatar gate with Godot --path Viewer --script res://Presentation/CandidatePresentationBatchTests.gd -- --preparation=source_variants/preparation.json,source_preserving/preparation.json --output=res://../work/creatures/source-variants/final-current. Omit --preparation to recheck Mummy/Solen/Ice. Review via scripts/review-creature-batch.ps1 -Preparation source_variants/preparation.json,source_preserving/preparation.json -Output work/creatures/source-variants/final-appearance. One broad root verification plus focused repeats after new fixes avoids repeating unrelated completed suites. Current evidence and scope are in PROGRESS.md; no automatic acceptance or proprietary-art publication occurs.

# Source-preserving batch preparation - 3 November 2026

An opt-in shared importer now prepares original Gaman248 (ML table Wild_Guar) and RatmanMage143 without dropping skin weights. Their ordinary Loop refinement overflow is retained as failed evidence; the existing SourcePoseSubdivision helper instead subdivides each posed source triangle using conditional inverse binds. Geometry is baked once into reusable private scenes, preserving the26/45-joint source rigs. Two levels give6560/6944triangles with a bounded1.5mm rest-normal offset. This adds editable resolution, not a claim of final silhouette/anatomy improvement.

The dense candidates have5473/7138conditional skin-bind aliases. Crowd/LOD performance remains unproved; baking once removes repeated subdivision, not per-frame skin-palette work.

These two exported bases use the existing declared affine-to-rigid approximation before subdivision. Preservation is measured against those normalized bases, not against raw GRN affine deformation.

Exact inputs, mirror URLs, container hashes, logical member names and table pins are in scripts/source-preserving-inputs.json. prepare-source-preserving.py checks them before converting. No input is downloaded or executed by this preparer; all inputs and generated art remain private. Gaman's supplied1024RGB atlas uses the existing UV layout; its original256atlas is fully opaque. Ratman's original128atlas has real cutout texels, retained separately. Auxiliary BMP/_m maps remain uninterpreted and unused. Installer authenticity/redistribution and an actual game build version are not asserted.

Reproduce from the repository root, with the pinned local inputs present:

1. python -B scripts/prepare-source-preserving.py
2. Run Godot --headless --path Viewer --script res://Presentation/BakeSourcePreserving.gd, then Godot --headless --path Viewer --editor --import (the pinned console executable is under .tools/godot).
3. python -B scripts/prepare-source-preserving.py --check-prepared; then Godot --headless --path Viewer --script res://Presentation/SourcePreservingSkinTests.gd.
4. Run scripts/review-creature-batch.ps1 -Preparation source_preserving/preparation.json -Output work/creatures/source-preserving/review-current; run scripts/verify.ps1 at the completed owned integration boundary.

The skin witness checks each dense face corner against its corresponding original posed triangle, independently of the bind construction. Current evidence:94checks/60poses/six temporary candidate static-corpse cases, max distances1.530521/1.528739mm under2mm bounds. The shared actual GPU review passes27visibility/full-hue checks and produces20comparison frames. Appearance receipts now hash the registry-selected asset, including saved scenes. The initial erroneous Gaman-cutout declaration failed honestly and remains under review/; current corrected results are under review-current/. Neither runtime registry nor accepted index is changed. Original GRN interpolation/affine fidelity, terrain/contact, partial-hue pixel semantics, riding and native behaviours remain separate gates.

# Creature art source policy

Owner direction, 30 October 2026: for distinctive Ultima Online creatures such
as ostards, **try the original Third Dawn models and modernise them before
deciding whether to replace them**. Preserve their recognisable shape and
character. The owner will judge the result from an animated comparison.

The owner has approved the desert result and requested the same programme for
**all creature families, equines first**. The full source queue, current batch
and remaining work are tracked in [CREATURE_MODERNISATION.md](CREATURE_MODERNISATION.md).

## Source order

- Reuse suitable existing modern assets for ordinary animals and shared forms.
- For distinctive UO creatures, start with the preserved Third Dawn mesh,
  textures, skeleton and available animation clips. Investigate other original
  source variants when the first model has a technical problem.
- Use a close free alternative when the original is absent, cannot be repaired
  reasonably, or the upgraded comparison is rejected. Keep its exact source and
  licence. Meshy candidates remain available for comparison/fallback.
- Keep accepted human bodies and horse replacements in place while testing the
  source creatures separately. This policy does not discard previously accepted
  work or equate all creatures with a shared horse rig.

## Upgrade and review procedure

1. Inventory the source mesh, texture maps, bones and clips; check native body,
   mounted-item and variant identities independently against the pinned server.
2. Export an unchanged baseline using the existing bounded parser, retaining
   originals and recording hashes, coordinate transforms and scale.
3. Refine the visible silhouette, head/beak, joints and coarse bends. Use added
   topology where it supports those changes, retain UV seams and bone weights,
   and check deformation after each refinement. Subdivision supplies resolution;
   shape edits and surface detail provide the visible improvement.
4. Improve albedo, normal/detail maps, roughness and shaders while retaining the
   creature's characteristic markings and server-controlled colour channels.
   Adjust proportions where appropriate, as already authorised by the owner.
5. Compare original and upgraded versions with matching camera, lighting and
   motion. Test idle, walk, run, attacks/reactions/death where available, then
   rider fit and transitions for mountable creatures on both human bodies.
6. Record measured geometry/rig counts, sampled defects and remaining gaps.
   Present the animated result for the owner's keep/refine/replace decision.

All native stats, permissions, movement and mount state remain server-owned.
File availability or matching bone names do not count as a working replacement.
Source and derived game art stay in the existing ignored local directories;
source-code and recipe changes remain separate from art distribution.

## Read-only source audit

The existing preserved Alpha Build 35 archive was rechecked against the SHA-256
in [THIRD_DAWN_IMPORT.md](THIRD_DAWN_IMPORT.md), without executing its binaries.
Local evidence: `outputs/third-dawn/creature-source-audit.json`.

| Source candidate | Parsed source mesh | Animation evidence | Current status |
|---|---|---|---|
| Desert ostard | 98 vertices, 185 triangles, 24 bones | Seven clips; 23 named tracks per clip match the body | Local original/upgraded trial; owner review and rider/live integration pending |
| Forest, frenzied, ethereal ostards | Each 98 vertices, 185 triangles, 24 bones | Desert clips have named-track correspondence; reuse needs deformation testing | Candidate variants, not runtime coverage |
| Ki-rin | `Kirin_LOD2.grn` exists | Idle, walk, run, attack, hit, death and fidget files exist | Current parser rejects a non-finite numeric value; identify format/data cause before export |

The ostard clips are idle, walk, run, attack1, gethit, die1 and fidget. This audit
does not prove smooth motion, rider compatibility, complete native action
coverage or modernised artwork. No creature coverage percentages change here.
The [desert ostard trial](OSTARD_TRIAL.md) now provides the baseline, geometry-only
and upgraded-material comparison, with seven imported clips and sampled skinning
checks. It awaits owner art review and rider/live integration; the other ostard
forms and ki-rin parser investigation remain pending.
