# Human locomotion and native action pass — 28 October 2026

Prepared free animation now replaces the rejected baseline on both fixed human
bodies when local motion assets are available. The original body, skin, UVs,
61-joint bind pose and all existing equipment bindings remain unchanged. The
old clips remain the fallback and are available in the animated comparison.
Artistic approval is still the owner's decision; this is an improvement pass,
not a claim that all native mobiles/actions or animation quality are finished.

## Source and reproducibility

Selected Quaternius Universal Animation Library 1 (already bundled) and the
current freely downloadable Standard edition of Universal Animation Library 2.
The publisher identifies the libraries as CC0, including commercial use:

- https://quaternius.com/packs/universalanimationlibrary.html
- https://quaternius.com/packs/universalanimationlibrary2.html
- https://quaternius.itch.io/universal-animation-library-2

The second publisher page currently lists v2.2, dated 28 September 2026. The
downloaded Standard archive is identified by its actual SHA-256 rather than
assuming every free clip changed in that release:
`4008ea208a604773a2b2177d965f0f5d3195498b5bf838c3f5785d68e95f2a68`.
Official free upload ID: 17958478. The GLB digest is
`8cee20ab1bc55130092447e810e26df22dd2803eccc54f52137a7d54d7ab88a8`.
Archive licence: CC0 1.0 Universal. Exact source, licence, root-motion reference
and existing library hashes are pinned in scripts/human-motion-inputs.json.

Adobe's official Mixamo FAQ also confirms free access with an Adobe ID and
royalty-free game use (https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html).
This pass uses the directly downloadable CC0 libraries and requires no account,
purchase, subscription or upload of our character. Only static GLB data is
imported. Downloaded Blender files/scripts are never executed.

After preparing the first human/equipment batches, run:

```powershell
./scripts/prepare-human-motion.ps1
./scripts/prepare-human-motion.ps1 -VerifyOnly
./scripts/test-human-batch.ps1 -Live -Visual -Cosmetics -Motion
./scripts/verify.ps1
./scripts/test-login.ps1
```

Preparation invokes the installed Blender with `--python-exit-code 1` and our
own scripts. Generated libraries, reports and captures stay in ignored
Viewer/local-art, work/human-motion and outputs/third-dawn. Original client
installations, owner characters, saved login and upstream server core are
untouched. Native live checks use the existing dedicated test accounts.

## Motion and garment fitting

Each body receives 43 prepared clips: 24 selected authored motions, a shorter
stride jog, a courtesy bow derived from the neutral stance, nine armed/unarmed
guard/locomotion composites and eight garment-safe action variants. Examples
include idle, walk/jog/run/sprint, sword ready and separate strikes, block,
punches, casting, hit, death, jump, interaction, harvesting and chopping. Work
clips are prepared candidates; this does not establish crafting integration.
One native heavy attack maps to one strike, not an entire multi-hit combo.
The first two sword strikes include their publisher-authored recovery segments
so they return to guard instead of stopping at the swing endpoint.

Retargeting calibrates corresponding neutral standing poses in world space
and aligns limb bend axes separately. Direct local copying between the source
T bind and our bent A bind produced head/finger errors, crossed ankles and
excessive knee lift. The final pass preserves the target's neutral anatomy,
corrects the limb alignment and grounds the presentation pelvis. It leaves
the network-controlled mobile root stationary.

The publisher's root-motion references cover 1.3 m in 40 frames for walking,
5 m in 28 frames for jogging and 5.5 m in 20 frames for sprinting (30 fps).
The fast source jog therefore covers about 5.36 m/s. A shortened-stride
derivative fills native walking speed near 2.44 m/s; the full run handles
native running near 4.88 m/s. Runtime cadence uses the pinned reference pace,
body scale and derivative stride estimate, with gait hysteresis and preserved
cycle phase. This is not a measured guarantee of zero foot slip. The existing
ground/stair contact solver still runs after animation.

Robes, skirts and kilts retain all underlying leg geometry. Their eight shared
controls are rebaked against all three cross sections in pelvis space, so
turning and wide stances do not assume a forward-facing pelvis. Initial full
lunges/high-knee runs failed the garment tests. The runtime therefore uses
shorter, quicker strides and stable lower-body guard variants under these
garments while keeping authored upper-body strikes. Trousers can use the
wider motion. Putting on a robe mid-attack switches footwork without resetting
its timing; ordinary equipment changes retain the same animation player.

The right-hand grip is taken from the prepared target sword stance, including
finger rotations, and remains closed around a held prop during casting and
other clips. Exact two-handed grips, shields, weapon-specific reach and moving
attack blending remain unfinished. Motion resources are shared per body rig;
each player/NPC retains its own playback clock and appearance materials.
Native starter katanas (0x13ff/0x13fe, checked against ModernUO Katana.cs) now
use the existing sword category, so live starter equipment also selects the
armed stance. The exact katana graphic is retained; its model is a category
substitute. World and character-sheet portraits receive the same ready pose.

## Native action integration

World.gd routes received native actions to the matching avatar. HumanActions.gd
maps a documented subset only for bodies 400/401. Supported classic groups
include locomotion/ready, one-/two-handed attack category substitutes, punches,
casting, hit reactions, death and a bow. Unsupported ranged, mounted and
non-human actions are retained in state/diagnostics rather than turned into a
guessed human melee animation. Different native designs can share a clip;
this is category playback, not exact original per-action fidelity.

The 0xe2 fields require particular care: ClassicUO's receiving implementation
interprets them as **type, subaction and variation**. The pinned ModernUO
sender uses historical action/frameCount/delay parameter names. New canonical
fields now preserve the receiving semantics; old raw aliases remain for
compatibility. They are not treated as classic frame timing. Supported new
human families are selected type-0 attack subactions and types 3/4/11
(death/hit/casting); other requests remain explicit gaps.

Classic frame count and delay set presentation duration (80 ms base plus
80 ms × (delay + 1), per the reference client); reverse and finite repeat
counts are supported. Zero repeat count/repeat mode loops until replaced or
movement resumes. Modern clips resample this duration, so sprite-frame parity
is not claimed. Death holds its final pose until a new action/body change.
The client does not calculate damage, change skills/statistics, move the
authoritative root or invent a successful attack.

Native group/packet facts were checked against the pinned local ModernUO
OutgoingMobilePackets.cs/Mobiles/Mobile.cs and ClassicUO
AnimationsLoader.PeopleAnimationGroup, MobileAnimation.GetObjectNewAnimation,
Mobile.SetAnimation and packet handlers. No upstream core changes were made.
The simple login/world panel now offers a server-confirmed war/peace toggle
and a native bow request; these do not grant privileges or bypass game rules.

## Evidence and remaining limits

- Independent exported GLB inspection covers 86 clips across both bodies:
  unchanged 61-joint rest layout, body position error below 0.000001 m,
  normalized finite rotations, stationary root and eight garment tracks.
- HumanMotionTests covers all 43 clips per body, resolved paths, finite poses,
  actual root bones, loop endpoints, native timing/reverse/repeats/death,
  garment changes mid-action and shared resources with independent NPC clocks.
  Final result: 48 checks pass; authored recovery joins differ by at most
  0.0858 radians per frame across native joints in the measured boundary step.
- Garment enclosure/floor sampling covers **816 poses**: both bodies, robe,
  skirt and kilt, 17 runtime-selected locomotion/guard/attack/cast/hit/bow
  variants, eight phases each. It does not certify every transition, jump,
  death, work clip, body shape or arbitrary future action. There is no cloth
  simulation. Raw wide-lunge clips are unsuitable under these garments; the
  renderer selects the fitted alternatives.
- Animated before/after captures use the same bodies/materials, actual old/new
  cadence and both sexes. Forward+ and Compatibility views are reviewed.
  Before/after: Review-Human-Motion.cmd. Native single-body wardrobe preview:
  Review-Human-Batch.cmd. Captures/reports are local, not committed.
- Live tests request war/peace and bow through the real protocol, check native
  confirmation, both human bodies, the actual world avatar, reconnect and a
  second client's received action. These do not certify real combat balance,
  every spell, two-handed contact or all native action families.

Final project verification and native login/relay pass. Logs:
work/human-motion/verify-accepted.log, live-accepted.log and login-final.log.
The complete preparation script also passed end to end (preparation-release.log).
The live check exposed orphaned owner-library lamp models when a scanned
replacement took precedence. A bounded parentless-model cleanup fixes that
leak without changing placement/art choices; unrelated concurrent world edits
are left separate.

Non-human rigs, mounts/riders, complete combat/action coverage, exact paired
weapon grips, facial expression, motion diversity, full start/stop/turn clips,
LOD and crowded-scene performance remain open. Owner review of the motion is
still required before calling the animation quality accepted.
