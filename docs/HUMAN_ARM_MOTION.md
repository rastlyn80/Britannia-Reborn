# Walking arm refinement — 28 October 2026

The owner still found the prepared walk stiff, especially the arms. The armed
locomotion composites had replaced both arm chains with a sword idle pose;
the unarmed guard likewise held a punch-start pose. Moving legs and a twisting
torso could therefore conceal almost stationary shoulder/elbow joints.

The revised preparation retains authored opposing arm/leg timing. The slow
walk has slightly more shoulder follow-through and elbow variation around its
cycle mean. The intermediate jog retains more of the authored upper-body
motion while keeping its existing short stride. Armed locomotion lets the free
arm swing, relaxes its fingers, and blends the carrying shoulder/elbow with the
gait instead of replacing them. The right finger grip remains active. Unarmed
guard locomotion also retains stride-driven arm motion. Constant guard
references avoid wrapping a partial idle cycle at a stride boundary.

Both bodies still have 43 clips, the same 61-joint bind, body mesh, UVs, skin
weights and equipment attachments. Server movement, appearance and action
requests are unchanged. The existing garment-safe lower-body choices remain.
This is an animation refinement, not owner acceptance of final motion quality.

## Reproduce and inspect

Before rebuilding, optionally copy each body's `motion/human-motion.glb` and
`motion/motion.json` to a sibling `motion-before-arm` directory. The local
comparison captured here uses the preceding prepared pass from c1d1769, not
the older mannequin fallback. The generated files remain ignored.

```powershell
./scripts/prepare-human-motion.ps1
# Reimport local assets, then run all project checks:
./scripts/verify.ps1
./scripts/review-human-motion.ps1 -ComparePrepared -Clip Jog -Outfit carry -Sex male -Angle 35
./scripts/review-human-motion.ps1 -ComparePrepared -Clip Walk -Outfit carry -Sex female -Angle 55
./scripts/review-human-motion.ps1 -ComparePrepared -Clip Jog -Outfit viking -Sex male -Angle 65
```

Without `-ComparePrepared`, the review continues to compare the original
fallback with the current prepared clips. Missing snapshots are reported.
`-Compatibility` checks the alternate renderer. Restart an already running
client/review after regeneration so it loads the changed animation resources.
Sources and hashes remain those in human-motion-inputs.json; no new asset or
licence was introduced. HUMAN_MOTION_PASS.md records the base preparation.

## Evidence and limits

- Preparation and independent exported GLB checks pass for both bodies; all
  86 clips preserve the fixed body/rest rig and stationary authoritative root.
- The existing robe/skirt/kilt enclosure/floor sampling passes all 816 poses.
- HumanMotionTests now passes 52 checks. It tests independent shoulder and
  elbow rotation through armed, relaxed and unarmed-guard walks/jogs, checks
  all twelve locomotion loop endpoints, and advances the actual avatar
  controller with the native starter katana at 2.44 m/s. This specifically
  guards against a moving torso masking fixed arms or playback restarting
  every frame. These checks measure motion, not artistic naturalness.
- Actual rendered comparisons cover both bodies, slow and native-speed
  walking, equipped/free arms, a robe, and Forward+/Compatibility. Local
  evidence: work/human-arm-motion and the dated Documents/Codex delivery.
- An additional local triangle-overlap probe samples 24 phases of armed
  Walk/Jog on each sex. The sword has no body intersections beyond the grip
  exclusion in all 96 samples, before and after. The same probe flags existing
  male hammer/sceptre overlaps in both versions; those need a separate grip
  fitting pass. This does not certify every prop, sleeve or transition.
- The fitted robe can still look excessively inflated in some stride views;
  enclosure checks establish coverage, not cloth quality. Cloth simulation,
  full start/stop/turn motion, exact two-handed grips and moving combat remain
  open. No claim of a complete wearable/mobile animation port is made.

Full verification passes with no engine/script errors. Logs:
work/human-arm-motion/preparation-final.log, motion-final.log and verify.log.
Concurrent world/prop work is kept separate from this character change.

## Closed carrying hand and walking review follow-up

The owner approved the improved arm movement and asked to see it in the slow
walk, with the item-holding hand closed. A close-up exposed that the active
grip helper was copying static open fingers from the library's sword idle.
Its presence alone had not established an actual closed grip.

WeaponGrip now adds fitted local phalanx curls and thumb opposition to the
fixed target hand reference. It changes the fifteen right finger bones only;
the carrying wrist and free-hand animation retain the stride motion. Removing
the weapon releases the override. Sword, hammer and sceptre currently attach
to this right hand; exact handle contact and future left/two-handed equipment
still require their own fitting. No prepared mesh/animation rebuild is needed.

HumanMotionTests samples the skinning pose inside modification_processed,
not the restored animation pose after a frame. For both bodies it checks
folded finger-chain span through idle, slow walk, intermediate gait, run,
cast and sword attack with each of the three held categories; checks that
the wrist/free fingers are untouched; and verifies release of fingers/thumb
on unequip. Actual avatar-controller checks cover both 0.98 and 2.44 m/s.
Final result: 60 motion checks pass; full project verification passes without
engine/script errors. Rendered hand close-ups are checked in Forward+ and
Compatibility. Final evidence: work/human-grip/verify.log.

Current male/female motion and hand detail can be reviewed without a baseline:

```powershell
./scripts/review-human-motion.ps1 -CurrentOnly -Clip Walk -Outfit carry -Angle 35
./scripts/review-human-motion.ps1 -CurrentOnly -Clip Jog -Outfit carry -Angle 35
./scripts/review-human-motion.ps1 -CurrentOnly -Sex male -Clip Idle -Outfit carry -GripCloseup
```
