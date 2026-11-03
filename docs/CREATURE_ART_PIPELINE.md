# Original Ridgebacks, human riders and Grizzle - 3 November 2026

The exact-input source-preserving manifest now contains nine forms. Original Ridgebacks keep30joints/226triangles/eight source clips and their original referenced atlases (including rid_savage.tga); two conditional-bind levels bake3616triangles per form without averaging away source influences. Ordinary187 uses native item0x3EBA; Savage188 uses0x3EB8. EtherealRidgeback's native item constructor uses statuette0x2615/ridden0x3E9A: source-table193 is its presentation key, not a witnessed native loose body. Default hue0x4001 skips accidental palette1 while retaining authored spectral shading; other full/partial hue parameters are preserved. Source table839 is retained in provenance but filtered out of routed mobile bodies. Grizzle259/compatibility272 retains its39joint/594triangle mesh, original atlas and thirteen motions including explicitly named takedamage/idle2/misc; one conditional level gives2376triangles. Run is a disclosed Walk alias. The normalized affine-to-rigid import and30Hz scene sampling remain explicit approximations.

SourceRigMountVisual now owns shared final-skin control, original-bone socket anchoring, reins and fitting interface. Swamp constants are unchanged in its thin subclass. Ridgeback proportions(.70,.85,.85), saddle(0,1.72,-.25), mouth(0,1.60,1.42) and stirrup(.36,-.58,.12) are authored modern fittings in the imported bind geometry, not recovered GRN sockets. Original SCNs remain unmodified for comparison. Source profile185/186 uses the existing licensed modern human bodies, authored Savage paint and wardrobe, with exact native gender/hair/beard/item/hue/statistics retention. Native TribalSpear0xF62/hue837, BoneArms0x144E and BoneLegs0x1452 source hashes join the existing profile manifest. Bare painted torso with bone arms is now supported without changing ordinary armour/robe backing. Bone geometry/material detail remains an acknowledged replacement approximation.

Mounted death initially failed32checks in sixteen Savage Rider cases: restored CPU bones did not match the submitted riding skin and the final visual remained above the corpse ground. HorseRider now records its final modifier pose plus last-draw global/model placement, using the existing SourceVariantPoseEntry held-pose proxy; SourceRenderedPose and its old freshness guard remain byte-identical. HumanNPCDeathVisual prefixes the existing clip with the displayed pose and settles its world anchor to the native actor's visual ground by.45s. Unmounted entry behaviour remains unchanged. Final gate includes ordinary400/401 horse riders as well as185/186 on original Ridgebacks, raw default/partial hues, Walk/Run and layer25 removal immediately before/after decoded0xAF. Time0 complete body skin is bounded by1mm, final ground anchor by1mm, sampled flat-plane skin by4mm; final skeleton matches the existing static corpse. Temporary test corpse nodes use deferred freeing after render callbacks. No native packet-order, ragdoll or continuous collision certificate is claimed.

A warm source preparation now validates original file/container/model-table pins, converter chain, exact per-model recipe and all staged geometry/atlas hashes before reusing an atomic candidate-cache.json. Changed sources/recipes/code/staging reject reuse; invalid partial JSON is rebuilt. A nine-form warm run measured1.5286seconds on this host. `--refresh-presentation` permits only runtime/fitting/material pin updates after all original input, converter, recipe, baker and actual saved-scene/atlas hashes still pass. It does not revalidate runtime behaviour or enable an accepted route. Real CLI rejection of a tampered baker receipt leaves it untouched; changed shaping inputs cannot reuse the cache. Original receipt restoration is byte-exact. Evidence: work/creatures/ridgebacks/cache-guards.json and prepare-warm.log.

Reproduce privately through prepare-source-preserving.py, BakeSourcePreserving.gd, --check-prepared and SourcePreservingSkinTests.gd; regenerate source-variant helper receipts with prepare-source-variants.py/BakeSourceVariants.gd. Prepare human profiles with prepare-savage-profiles.py, leaving foot profiles in preparation.json and riders in riders.json. Run actual-renderer CandidatePresentationBatchTests with --preparation=source_preserving/preparation.json and private --output; CreatureAppearanceTests with that preparation; RidgebackRidingTests, SwampDragonRidingTests, MountedHumanDeathTests and SavageHumanProfileTests. Root scripts/verify.ps1 adds optional headless rider/death gates when the private forms/profiles exist. The full root run completed with exit0, including450saved-skin checks,1037headless rider checks,2208mounted-death checks,71server-extension/84overlay checks and successful world startup; log work/creatures/ridgebacks/root-verify-final.log. Existing Unicode/material/cleanup diagnostics and two nullable warnings remain. Root first attempt stopped at an old dependency pin; the final rider uses the existing helper instead of altering/rebuilding the established source helper.

Current focused evidence under work/creatures/ridgebacks/: presentation-final/756checks166poses18entries; old-candidates-final/377checks80poses8entries; appearance-current/113checks54views; riding/1049checks336poses6human corpse cases; death/2208checks32cases; current Swamp riding254checks72poses; existing Savage foot537checks. source-preserving/skin-proof.json has450checks249poses30generic corpse cases. All focused gates and the required final root run pass. Nine current native source-file hashes also match cached metadata in native-source-audit.json; this is a separate source audit, not constructor execution or a geometry-cache native certificate. Exact paint normal/tangent array preservation passes on the real renderer. Headless cached normals differ by up to0.0001292 in the probe because vertex-region readback does not reproduce the same cached normal data there; the headless contact gate explicitly excludes those two exact channels, while the GPU gate retains the original exact-channel requirement. No production paint precision check or error guard is suppressed.

Source and native acceptance remain separate. Native bounded168/279(60.2%) stays unchanged; the wider all-creature isolated-server approval is still pending after automatic review treated the prior permission as equines-only. Three native-harness drafts remain local/unpublished. Before accepted-index changes, keep193item-only/272compatibility catalogue marking, native permission/AI/combat/source action witnesses, continuous terrain/cadence/ledge/spawn, partial-dye pixels, final shape/texture and crowd/LOD evidence explicit. Gazer/Bog/Ant/Changeling source exceptions remain isolated so regular family work continues. Proprietary inputs, derived scenes/textures/captures and binaries stay excluded; production, saves, remembered login and concurrent terrain/building/UI work remain untouched.

# Source-preserving Orc/Swamp integration - 3 November 2026

`scripts/source-preserving-inputs.json` now contains five exact source forms. Added OrcBomber182 keeps its own37joint/404triangle/two-influence source mesh,128RGBA atlas and six original motions (plus explicitly held compatibility Fidget); it is not an Orc geometry substitution. Two subdivision levels bake6464triangles/6060vertices/5445conditional binds once. SwampDragon794 and barded799 each retain61joints/1446triangles/256RGBA, nine original motions, one subdivision level (5784triangles/8676vertices;2488/2515conditional binds). Original scene deformation is the declared rigid approximation of affine source data with30Hz sampling; the saved-skin2mm proof is against corresponding posed imported triangles, not a raw GRN interpolation/fidelity certificate.

Both retained AOS/ML Swamp Idle files are byte-identical: SHA256 `7f5346a01b46960252edfd23d4566108de0204e1e93a861dcc45a57307f3b448`,93928bytes. One noncanonical chunk word at21696 is `0xCA5A0E03`; an exact-hash in-memory adapter changes it to `0xCA5E0E03`, changing only byte21698. Derived SHA256 is `478b3bbf9c6d815c7452e16d0f9bdad2f77ca2724fe5e9e328f888b209c713ab`. Strict parsing then recovers91tracks/bones, safely mapping59tracks to either61joint model; omitted source leaves are not required intermediaries. Payload/keyframe bytes and original files stay unchanged. This is an authored compatibility correction, not an assertion that an official repaired asset exists. Manifest records original and derived hashes separately. Static extraction/probe evidence is under work/creatures/swamp-dragons/; no installer/game executable was run.

SourceSwampDragonVisual extends the shared coarse-control/dense-render class. It declares modern-only proportions(.45,.65,.65), retaining original SCN geometry/table size for comparison, and authored saddle/mouth offsets attached to the original spine1/head. Reins and stirrups use the existing human rider modifier; both forms use their own atlas and original cutouts. Neutral barding texels opt into metallic strength.75. MountVisual can resolve a prepared registry entry's explicit mount_item; tests inject entries in memory and leave accepted-index unchanged. HumanAvatar keeps an already seated rider seated when native barding swaps the mount visual.

Pinned native source revision remains Server/dependencies.json. SwampDragon.cs SHA256 `ae4368ae70257c9ee6ce27d1452d5ec9e27d73ad6d1d8bb47c30c57b66349fd9` declares body794/item0x3EBD/default hue0x851, versus barded799/item0x3EBE/resource hue. OrcBomber.cs SHA256 `aab01f8427ff624de7cdc0c56d2f63b67e7fe72730de085b35ed5239e8fd2e0e` uses body182 and bomb projectile0x1C19; ThrowBomb does not call Animate. These are read-only source contracts, not tested native mounting/combat/barding-damage claims or a completed projectile-driven throw cue. No native source was changed.

Reproduce privately: `python scripts/prepare-source-preserving.py --check-inputs`; `python scripts/prepare-source-preserving.py`; Godot with Viewer path and `--headless --script res://Presentation/BakeSourcePreserving.gd`; `python scripts/prepare-source-preserving.py --check-prepared`; headless SourcePreservingSkinTests.gd. Run CandidatePresentationBatchTests.gd on the actual renderer with `-- --preparation=source_preserving/preparation.json --output=res://../work/creatures/swamp-dragons/presentation-current`; run SwampDragonRidingTests.gd; run CreatureAppearanceTests.gd with preparation res://local-art/creatures/source_preserving/preparation.json, family source_preserving and a private --output. Source variants' helper receipt is regenerated through prepare-source-variants.py/BakeSourceVariants.gd. Finally run scripts/verify.ps1 once for the integration batch; it includes the optional Swamp contact/identity gate when both private forms exist. Headless contact results use riding-contact/, GPU results use riding/.

Current actual Forward+ evidence: presentation-current/validation.json412checks/90poses/ten fixture deaths; appearance-current/appearance.json65checks/30sampled views; riding/validation.json254checks/72poses. All pass; current post-proportion maximum first-skin difference is0.001996mm (1mm bound). Full scripts/verify.ps1 completed with exit0, including the241skin/corpse checks,254Swamp contact/identity checks,71server-extension/84overlay checks and successful world startup; log work/creatures/swamp-dragons/root-verify.log. Existing Unicode/material/cleanup diagnostics and two nullable warnings remain. The earlier raw-proportion captures in presentation/ predate the authored fit; do not substitute them. Source-preserving skin-proof.json241checks/135poses/15static corpse cases passes; all dense corners stay below2mm from their parent imported triangle, including1.5mm source normal shaping. Capture review is required in addition to fitting metrics: earlier contact-only success still hid lower legs inside the oversized source barrel, prompting the explicit modern proportions. Legitimate fin/robe occlusion and finite pose checks do not prove universal garment collision.

Accepted native168/279(60.2%) is unchanged. Native test scope remains pending after automatic review rejected the wider non-equine trial; three native-harness drafts stay unpublished. Keep source aliases, projectile choreography, continuous cadence/transitions/ledge/spawn, partial-dye pixels, native permissions/barding and crowd/LOD/final art as separate gates. Exact proprietary inputs, derived scenes/textures/captures and extraction binaries remain private/excluded. Continue regular families through the shared pipeline; isolate unusual source-format failures instead of blocking the batch.

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
