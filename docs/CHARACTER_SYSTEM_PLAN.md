# Character foundation and creation plan

Motion checkpoint, 28 October 2026: HUMAN_MOTION_PASS.md records prepared free
CC0 locomotion, guard/attack/cast/hit/death motion, garment-safe variants and
native human action playback. Both sexes retain the original body/bindings.
The rejected baseline remains for comparison/fallback; owner quality review
and complete mobile/action coverage are still open.

Full-port requirement, 28 October 2026: target every native mobile, wearable
and animation family, with the same server-driven appearance contract for
players and NPCs. Hair/beard IDs and independent hues, body/skin, references
and received statistics must remain authoritative. See CHARACTER_PORT_PLAN.md
for acceptance/coverage rules and CHARACTER_EQUIPMENT_EXPANSION.md for the
second batch and native creation/update/persistence work.

## Animation requirement — 27 October 2026

The owner reports that the present movement looks like a mannequin. Smooth,
natural movement is a required follow-up, not an accepted finished result.
Check the bundled CC0 Quaternius animation library on both fitted human rigs;
evaluate arm swing, torso/hip counter-rotation, stride cadence, foot sliding,
idle/walk/run transitions and robe motion together. Prefer authored motion over
procedurally smoothing stiff source clips. Keep the server-controlled root,
ground contacts and equipment skeleton intact. The three original MakeHuman
clips are a functional baseline, not the animation quality target.

Owner-approved direction, 27 October 2026. The free human/wardrobe experiment is the foundation. The first male/female batch is now integrated into the live avatar and portrait; see HUMAN_BATCH_INTEGRATION.md. ModernUO remains authoritative. Preserve existing login storage, saves and converter/IR. The original stage ordering below is retained as the design record.

## 1. Correct robe movement (implementation authorized)

Retain continuous legs where the hem can expose them. Replace the lower robe's excessive pelvis anchoring with bounded, continuous stride deformation. Preserve the waist and sleeves, provide space around the moving legs, and avoid floor penetration. Review complete Idle/Walk/Run cycles from front, side and rear, including robe alone and robe/hood. Structural/bounds checks alone do not establish visual correctness.

## 2. Finish one natural male appearance (implementation authorized)

Research reusable natural skin textures and practical Godot skin shading. Record exact source/licence and input hashes. Address blotchy albedo and dark eye area; balance normal detail, roughness, specular response, restrained subsurface scattering, eyes, brows and hair. Compare before/after under identical neutral and side lighting. Preserve body geometry and native animation. Start from one fixed male shape; broad shape sliders require further garment work.

## 3. Shared character and equipment presentation (first batch implemented)

Use the same body/material/equipment renderer in preview, creator and live world. Swap pieces independently with explicit layer and body-coverage rules. Map authoritative server equipment to licensed replacement art. Start with five tested pieces/two outfits; full wardrobe coverage remains unproven.

## 4. Graphical creation screen (planned)

Login → character selection → appearance → profession/start choices → confirmation → Britain. Centre: rotatable 3D preview, face zoom and outfit preview. Left: name, skin, hair and tested face presets. Right: server-valid profession/attributes/skills and summary. Start with the tested male human; offer female humans only after equivalent fitting/animation checks. Existing native creation uses fixed defaults and must be extended, not replaced with an offline simulation.

## 5. Persistence and complete journey (planned)

Use native server appearance fields where supported. Additional 3D cosmetics require a persistent profile keyed to server character identity, available to other clients. Do not overwrite existing appearances. Verify two distinct characters, live creation/entry, equipment changes, movement, another-client appearance and reconnect persistence. Run scripts/verify.ps1 and scripts/test-login.ps1 for live login changes.

## Current scope

Stages 1–2 and the first batch of stage 3 are implemented. Native male/female selection and reconnect persistence are tested, while the full stage 4 creator and extended cosmetics remain planned. The owner has explicitly requested substantial animation improvement; the current motion is a baseline awaiting that work. No purchases, publication, proprietary art commits or changes to the original prototype/UO installation.

Implementation records: CHARACTER_FOUNDATION_POLISH.md covers the initial robe/appearance pass; HUMAN_BATCH_INTEGRATION.md covers female fitting and live integration. The full graphical creator remains a separate milestone.
