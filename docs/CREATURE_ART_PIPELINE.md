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
