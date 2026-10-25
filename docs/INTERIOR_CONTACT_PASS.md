# Interior, stairs and character contact pass

Implemented 2026-10-25 in the shared Godot reconstruction/presentation layer. No coordinate-specific meshes or source-file edits. Restart Launch.cmd to load it; an already-open viewer retains the old scene.

## What changed

- Floors are closed 12 cm slabs with their top at the source elevation, continuous world-space timber texture, tiny shared-edge overlap, and half-cell extensions to adjacent wall bases. Conservative isolated single-cell void repair requires four supporting floor/wall neighbors; stairs, doors and lower-storey floors prevent repair. The crop receives three derived floor patches. All source placements remain represented.
- Stair directions are inferred from adjacent source elevations; fallback directions for 1827/1850/1852 were corrected. Bridge support blocks now use their effective half-height, so they no longer bury the small risers. Five fine risers fit a normal 1 m source stair module. Stone stairs use the stone surface.
- Perpendicular diagonal wall endpoints receive their missing half-cell returns unless an explicit wall/corner/door/arch occupies the junction. Four joins, tested in all orientations and translated layouts. Existing explicit corner and direct endpoint rules remain. One-Z wall/corner-to-floor ceiling seams close without moving their bottoms: 47 ceiling seams in this crop.
- Interior liners recognise both static floors and map.mul wooden land floors. Flat ceilings sit beneath connected roof eaves or beneath the terrain-encoded floor above a basement. Perimeter closures follow existing wall cells; short walls can extend to the supported ceiling. The crop has 757 derived liner panels; stairwells and lower-floor openings remain open.
- Lamp suspensions stop at the nearest source floor or generated ceiling. The basement fitting previously ran through the bedroom floor to the roof; its cable no longer does so.
- A post-animation SkeletonModifier3D applies bounded two-bone leg contact to actual physics support. Feet keep their animated swing, receive extra tread clearance, and tilt toward gentle support normals. Three support probes smooth torso height across risers. Jumping releases contact and teleports clear it. Character network roots are untouched.
- Walk/jog/sprint changes retain stride phase and use threshold hysteresis; starts, stops, turns and landing blend. Static cardinal stair prediction uses the pinned ModernUO bridge-height/step-reach rules, reducing per-step resynchronisation pauses. Walls, body clearance and diagonal uncertainty remain conservative; server rejection still wins.
- Camera sweeps always cover the full requested range, retract immediately and restore outward slowly. Trunks get a camera-only collision layer; nearby leaves dither out around the lens. Foliage does not obstruct jumping or character movement. Existing right-button mouse controls remain.
- Four isolated natural height outliers get a conservative visual cap (neighbor maximum + 1Z). Original map Z/navigation are retained. Buildings, paving, connected ridges, major peaks and incomplete crop boundaries are protected. The same displayed mesh supplies physics support; repairs are inspectable through TerrainSurface.peak_repairs.

## Verification and reproduction

- scripts/verify.ps1: converter 19, login 8, session 16, presentation 11, graphics 19, input/memory 11, street/movement 43, architecture/nature 8, surface 15, contact/interiors 46 = 196 checks. Converter/isolated server extension build; 21 pinned CC0 texture hashes verified. The final added ceiling fixture also passed separately after the complete 195-check run; no runtime changes followed that run.
- Six GPU tree/grass/water motion checks still pass, including freely running shader time.
- Live development-account world entry passed at Trammel 1602,1591,20 using scripts/test-graphics.ps1 -PreviewOnly; this does not claim a new native-client stair parity run. User login vault, user character and ClassicUO observer were untouched.
- Forward+ screenshots and OpenGL compatibility load/exit passed. 2,689 source records accounted, zero unmapped; 122,212 presentation collision triangles.
- scripts/capture-contacts.ps1 reproduces basement, stair, bedroom, upstairs-floor, ceiling, terrain and posed foot-contact captures in ignored outputs/validation. The posed stair character is an offline presentation capture, not a multiplayer traversal recording.
- Logs in ignored work/contact-release.log, contact-46.log, contact-animation-proof.log, contact-live-preview.log and contact-compatibility.log.

## Scope and remaining limits

These rules automatically run on subsequent conversions with the same source semantics and mapped tile families. They are not a guarantee that unseen IDs or architectural patterns will be reconstructed correctly. Larger-map/chunk-halo validation and independent native-client visual/height parity remain required. Isolated floor repair is deliberately conservative. Peak filtering cannot infer missing boundary neighbors and does not flatten genuine mountains. Foot contact is bounded presentation IK, not full foot locking/root-motion or replicated jumping. Dynamic server items and diagonal stairs may still require resynchronisation. No proprietary source data or derived screenshots are committed.

The modifier uses the engine's documented post-animation callback: https://docs.godotengine.org/en/stable/classes/class_skeletonmodifier3d.html . Movement rules were checked against pinned Server/ModernUO/Projects/UOContent/Engines/Pathing/Movement.cs; no server-core edits or linked server dependency were introduced.
