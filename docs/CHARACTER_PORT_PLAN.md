# Character/mobile port contract — 28 October 2026

The owner's target is a complete modern 3D presentation of Ultima Online's
mobiles, wearables and animations. A small collection of attractive stand-ins
is an intermediate milestone. ModernUO remains authoritative for identities,
appearance, statistics, equipment, movement and actions.

## One character description for players and NPCs

Use native mobile serial and body ID as the reference, never a guessed NPC
class inferred from appearance. Preserve skin hue, flags, notoriety, name,
coordinates/direction/facet and all received native mobile fields. Hair and
facial hair each have their own item ID, serial, layer and hue. Equipment
keeps its original graphic, layer, hue, serial and container reference even
when the replacement art is approximate or missing.

MobileAppearance.profile is the common description. GameSession.appearance_for
assembles it from the same server state for a player or any nearby NPC. The
world and character-sheet portrait consume the same description and renderer.
Statistics received for NPCs are preserved; unreceived strength, intelligence,
skills or other private statistics remain unknown. Do not manufacture values
to fill the presentation schema. Player skills/status remain in the existing
authoritative session model.

Native hair/beard fields now flow through character creation, server entry,
remote updates, item removal, reconnect and the shared renderer. Additional
3D-only cosmetics, if introduced later, need an explicit interoperable server
extension or persistent profile; do not silently replace native fields.

## Separate three coverage dimensions

1. **Mobile/body art:** each native body ID has a body family, licensed mesh,
   scale, rig, materials, sockets and validation status. Cover human sexes and
   ghosts, elves/gargoyles, animals, monsters, summons, mounts, polymorphs and
   corpses explicitly. Current accepted integration covers only bodies 400/401.
   Other body IDs remain exact in state and are tagged as missing native body
   art; the legacy visual is a placeholder, not a faithful conversion.
2. **Wearable art:** each native graphic/layer has a replacement recipe,
   supported body families/sexes, coverage rules, hue behaviour, source/licence
   and validation status. Related IDs may share a modern category mesh, but
   that is not exact per-item fidelity. Hair/beard IDs require the same audit.
   Preserve missing IDs so gaps can be measured and filled.
3. **Animation/action:** retain the native protocol, body at the time of the
   request, action, frame count, repeat/reverse flags and delay. Resolve actions
   through the correct body family; the same classic action number must not
   be assumed to mean the same motion for a human, animal and monster. Define
   compatible clips, grip/handedness, attachments, transitions and garment
   deformation for every supported action/body combination.

CharacterCoverage.gd audits the locally indexed client wearable graphics and
records mapped/missing IDs and source animation references. This is not a full
server-item census and does not establish mesh fidelity or collision-free
animation. Keep the raw indexed denominator, source version and unresolved
entries instead of calling an approximate category "fully ported".

## Implementation order

1. Establish shared descriptions and measurable coverage (implemented for the
   first human batches). Add civilian clothing and armour families without
   making body-mask combinations grow exponentially. Keep actual legs under
   skirts/robes and use independent coverage regions for gloves/headgear.
2. **Animation quality is the immediate quality priority.** The owner rejects
   the mannequin-like gait. Compare authored candidates, match cadence to
   measured motion, improve hip/torso/arm movement, turning and stopping,
   contact/foot sliding, and rebake garment controls for the selected motion.
   The current MakeHuman Idle/Walk/Run is still a baseline, not final quality.
3. Implement human action families: armed/unarmed stances, attacks, parries,
   casting, hit reactions, death, emotes, interaction, work/crafting and sitting.
   Connect received 0x6e/0xe2 requests to verified clips. Test one-/two-handed
   equipment, grips, hiding/layer rules and body coverage throughout actions.
   Capturing native requests is implemented; general server-action playback
   is not yet implemented.
4. Build non-human body families with body-specific rigs and action mappings.
   Reuse motion only after measured retargeting and visual review. Add mounted
   rider/mount combinations, death/corpse transitions and polymorph handling.
5. Expand exact equipment designs, hair and facial-hair silhouettes, racial
   restrictions, all native hues and exceptional layers. Finish the graphical
   creation preview using the same renderer. Add LODs, caching and performance
   budgets only after representative crowded scenes are measured.

## Acceptance for a ported family

Require traceable free artwork, exact native identities/references, deterministic
layering, tested native fields and reconnect/other-client agreement. Validate
actual exported rigs, UVs, weights, material/hue response and animation paths.
Inspect complete representative animations from multiple angles, including
equipment changes mid-motion and real terrain/stairs. Include NPC examples,
missing-art fallbacks and unknown fields. Never equate finite bone matrices or
an attractive idle screenshot with complete animation/wardrobe coverage.

Save evidence separately for protocol correctness, art fidelity, animation
quality, geometric coverage and performance. Only claim each dimension after
its own checks pass. Keep original client data, local saves and generated
source-derived outputs excluded from commits.
