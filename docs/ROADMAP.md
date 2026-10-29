# Live developer editing checkpoint — 28 October 2026

Done and tested (DEV_EDIT.md): a server-authoritative shared edit session for statics and terrain in live Britain, with an in-game panel (F9), two-client sync, conflicts/undo rules, reconnect, restart persistence, edit sets and the `scripts/dev-edit.ps1` Claude Code bridge. Visual overlay only.
Done 29 October: conversational layer with Claude Code bridge, rule scopes/multi-select, Commit into converter overrides with live reload, persistent data rules. Next, in order: (1) native speech input inside the client (now Windows voice typing) and a long-running Claude watcher that implements behaviour rules end to end; (2) owner decision on publishing committed overrides (coordinates) to Git, then PR-based review of commits; (3) inspect-only architecture: partial district rebake that keeps joined topology; (4) authoritative terrain/statics via a separate development copy of the map files for ModernUO plus a restart. This is the real blocker; do not bypass server authority. Both graphics-mode caches now carry source maps; Launch.cmd rebakes automatically whenever bake code changes.

# Civilian wardrobe and long-hair checkpoint — 28 October 2026

Both humans now have 20 equipment categories (86/1,126 indexed graphics): new doublet, cloak, low leather shoes and ankle sandals, with separate native dyes. Long hair/ponytails stay visible over clothes and headwear, including cloak-specific moving-surface bindings. Sources and CC BY sandal attribution are recorded; original body/bind and 45 clips per sex are unchanged. Full shared-project verification and the isolated committed-world-plus-character check pass, alongside 134 exports, 768 new and 816 prior cloth poses, 46 new runtime checks, 168 GPU hair-visibility cases (over 99.5% retained) and actual Forward+ renders. Concurrent world work is preserved. Live smoke is currently blocked before login by aborted local connections, despite the listener; eight native login tests pass. See HUMAN_CIVILIAN_BATCH.md.

Next: restore/confirm the local live connection path and repeat re-entry, equipment and observer checks; owner review of the new silhouettes/hair; improve hair-card edges/volume and shoulder/waist layering; then shields, armour pieces, ranged/two-handed holds and remaining human action families. The catalogue now names each current replacement mesh in item and item/action rows. Category coverage remains separate from exact item fidelity; monsters remain outside the current batch.

# Human wardrobe catalogue checkpoint — 28 October 2026

Human players/NPCs remain the current clothing/action scope; no monster/animal expansion in this batch. Skirts/kilts are 23–37% narrower in the matched Idle thigh measurement with full legs retained; shared garment controls pass 816 modern poses. Three new civilian clothing/headwear categories bring the wardrobe to 16; two fidgets bring prepared motion to 45 clips per body and classic category playback to 23/35. Native hair/beard/item colours remain independent. Full project, asset, dedicated native/live appearance/action and login/relay checks pass; evidence and limits are in HUMAN_WEARABLE_CATALOGUE.md.

Review-Human-Catalogue.cmd is the repeatable worklist for 1,126 indexed wearable graphics (84 category-mapped), 35 classic groups, installed human/equipment sequence metadata and the per-item/action matrix. Next: improve source folds/layered waist fit and exact designs; proper doublet/vest, cloak, shoes/sandals, leather layers, shields and ranged gear. Add the matching two-handed/ranged/turn/salute actions, then review each item/action combination and server race restrictions. Mounted riders remain catalogued/deferred; monster/animal families remain outside this human workstream. Track native identity, mesh fidelity, action mapping and visual QA independently.

# Modern interface checkpoint — 28 October 2026

Owner-approved direction: dark glass and brass windows, a customizable quickbar with Shift/Ctrl/Alt sets, every classic macro action, purpose-built windows for skills, spellbook, backpack and common server gumps, all wired to the real server protocol (ClassicUO as reference). Built: quickbar, slot editor, classic action catalogue, packets and runner (docs/MODERN_UI.md; QuickbarTests 37/0). Live check passes (scripts/test-quickbar.ps1). HUD built: vitals, target frame, journal, window menu, notices, skills, spellbook and backpack windows. Owner requirement: per-kind action timers on slots, refusing repeats until they expire, with durations from server feedback. Next: the skills window, spellbook and backpack from the canvas with drag-to-slot; modern rendering of server gumps and the crafting/vendor/runebook windows; settings page (scale, rows, sets, auto-switching bar sets); client-side actions still reported as unavailable.

# TODO (owner requirement): complete every item at final quality — 28 October 2026

Must finish: every placed graphic in every facet at final art quality, rare ones included, not just Britain. Status after Britain push 6 (8aaf22a): Britain 100.0% of 2,993 placed graphics; world 92.1% of 10,762 placed graphics, 849 still open (outputs/item-catalog/open-work.json lists them by family, most placed first; mostly Malas, Ilshenar, Tokuno and Ter Mur). Work order: (1) the 849 open world graphics, via deeper multi-query sourcing (scan first), crafted recipes in photoscanned materials only where no honest scan exists, every look checked beside its original in compare sheets; (2) replace the weaker crafted stand-ins with scans when found (gorgets, bone armour pieces, pampas grass, century plant); (3) graphics never placed on the maps but used by the server or players (wearables/equipment overlap with the character pipeline: coordinate, do not duplicate). Not done until open-work.json is empty.

# World art coverage and graphics memory checkpoint — 28 October 2026

Goal set by the owner: every placed graphic in every facet at final art quality (photoscan/PBR, photoscanned construction or owner packs), not just Britain, and graphics memory that does not grow with the size of the world. Tracking now covers the whole world: the item catalogue reports final-quality coverage by placements for Britain, the world and each facet, by distinct placed graphics, and writes open-work.json (open families, most placed first). Current: Britain 90.3% of placements, world 93.2% of placements but 51.1% of 10,762 placed graphics (5,264 open in 1,679 families). Work tracks: bulk prop sourcing (scripts/source-candidates.py: CC0/CC-BY candidates from Sketchfab via the Objaverse mirror, thumbnail review sheets, then add-objaverse.py), Poly Haven CC0 nature sets split into single variants (reduce-polyhaven.py --split), photoscanned builders for construction families (FenceBuilder.gd first), guess review sheets (only matching looks approved), and identifying the ~500 unnamed records. Memory: GPU texture compression cut the Britain stress route from 3.72 GB to 1.26 GB of GPU memory (textures 3.25 to 0.84 GB); the phased plan for whole facets (facet parameter, shared assets out of district files, out-of-core incremental bake, towns baked and wilderness generated, LOD) is in WORLD_SCALE_MEMORY_PLAN.md.

# Holding-hand and slow-walk checkpoint — 28 October 2026

Owner accepts the relaxed arms. Both slow and normal-speed walking retain that motion; current male/female clips and holding-hand close-ups are available through the motion review. Corrected the grip reference's static open fingers with fitted right finger curls/thumb opposition, leaving the wrist/free hand animated and releasing on unequip. All 60 motion checks and full project verification pass, including actual post-modifier closure on both bodies and avatar playback at 0.98/2.44 m/s. See HUMAN_ARM_MOTION.md. Exact per-prop handle contact, left/two-handed holds, starts/stops/turns and robe drape remain separate work.

# Walking-arm feedback checkpoint — 28 October 2026

The owner still found arms stiff in the prepared gait. Armed/unarmed-guard walks now retain independent shoulder/elbow motion, a free swinging arm and the carrying-hand grip; the slow walk and intermediate jog also retain more authored arm follow-through. Both bodies rebuilt without body/bind/server changes. All 52 motion checks, 86 exported clips, 816 garment poses and full project verification pass. Actual before/after compares the previous prepared pass with this revision; see HUMAN_ARM_MOTION.md. Owner artistic acceptance remains open. Next motion work includes starts/stops/turns, better robe drape (enclosure is verified, appearance still inflates in some poses), exact hammer/sceptre and two-handed grips, and moving combat.

# Human motion checkpoint — 28 October 2026

The first prepared motion pass is integrated on both fixed human bodies: 43 clips each, armed/unarmed guards and gait, separate attacks/recoveries, native human action subset, sender timing/reverse/repeats, garment-safe footwork and server-confirmed ready/relaxed poses. See HUMAN_MOTION_PASS.md for sources and limits, and Review-Human-Motion.cmd for animated old/new comparison. Body/bindings and authoritative server state remain unchanged; sampled garment and native/live checks pass. Source preparation is automated and hash-pinned. This does not establish owner artistic acceptance or a complete mobile/action port.

Next: owner motion review; dedicated starts/stops/turns, stride/contact tuning on real terrain and moving attack blending; exact two-handed grips, shields and ranged actions; verify jump/death/work transitions with every garment. Expand remaining human action families and exact designs, then non-human body-specific rigs/actions, mounts/riders, ghosts/polymorphs/corpses and crowded-scene budgets. Keep unsupported native requests explicit. The old mannequin-like gait remains a fallback/comparison, not the current prepared human default.

# Expanded wardrobe/full mobile-port checkpoint — 28 October 2026

The full target is every native mobile, wearable and animation family, using one server-driven appearance description for players and NPCs. CHARACTER_PORT_PLAN.md defines coverage and acceptance separately for body art, equipment fidelity and action playback. Current integration covers bodies 400/401, 13 equipment category meshes, five hair families and all seven beard identifiers; independent native types/colours, references and received statistics survive updates/reconnect. Local audit: 80 of 1,126 wearable-flag graphics mapped, not all exact designs or server classes. Verified asset/192-pose/native/live checks and isolated committed-world integration are recorded in CHARACTER_EQUIPMENT_EXPANSION.md.

Next: prioritize natural gait/turning/stopping/contacts and garment rebaking, then real armed/unarmed stances and native combat/casting/death/emote/work actions. Received animation packets are retained but not generally played. Expand exact clothing/armour/headgear/hair art and remaining layers; build non-human body/action families, ghosts, mounts/riders, polymorph/corpse transitions; complete graphical creation with the same renderer and measure crowded-scene LOD/performance. Current hair edges, simple weapons, category silhouettes, three skin presets and basic grips remain quality/fidelity gaps. Preserve the server's original values even when art is missing; do not invent NPC statistics or mark a finite-rig test as artistic approval.

# Live male/female batch checkpoint — 27 October 2026

Stage 3 shared appearance/equipment rendering is integrated into the world and portrait, with native male/female creation and first-batch item mapping. Dedicated live creation, equipment changes, second-client replication and reconnect checks pass. See HUMAN_BATCH_INTEGRATION.md. Animation is the immediate quality priority: the owner rejects the stiff baseline. Compare the bundled UAL candidate clips, tune motion/cadence/transitions/contacts and rebake robe deformation before claiming natural movement. Full creator UI, native hair variety, broader skin/customisation, exact skirts/armour/weapons, arbitrary shapes and LOD/performance remain open.

# Character foundation checkpoint — 27 October 2026

Stages 1–2 of CHARACTER_SYSTEM_PLAN.md are implemented in the private review: continuous legs, stride/raised-heel skirt deformation, clean natural skin and eye/hair treatment. See CHARACTER_FOUNDATION_POLISH.md for source pins and measured checks. Next: owner artistic review, then a shared live/creator equipment renderer, server-valid creation controls and persistent cosmetic profiles (stages 3–5). Do not expose unverified body sliders or assume the creator/live avatar already uses these assets. Combat/sitting/other shapes, broader wardrobe matching and performance/LOD remain open.

# Free wardrobe trial checkpoint — 27 October 2026

Five CC0 wearable pieces and two combinations are fitted and sampled; the same-body skin/material comparison and actual GPU probes pass in Forward+ and Compatibility. See FREE_EQUIPMENT_TRIAL.md. Next: owner artistic review; exact armour/helm/weapon matching; more extreme poses and layered clipping checks; shared-rig runtime equipment swapping; then native item mapping and LOD/performance work. Do not call the full wardrobe solved: rare original designs, other body shapes/races and every server equipment combination have not been matched. Skirt motion is fitted skinning, not cloth physics.

# Free human foundation checkpoint — 27 October 2026

Owner now prefers a separate free human foundation instead of further repairing the UO body. A pinned CC0 MakeHuman-derived candidate and real chain-shirt/robe adaptation are implemented and sampled in both renderers, with independent rig/weights/animation checks. See FREE_HUMAN_WARDROBE.md. Next: owner approval of the candidate appearance, clothing-specific polish/extreme poses and additional garment types, then shared-rig equipment swapping/live mapping. Two fitted garments on one fixed shape do not establish arbitrary wardrobe or body-slider support; UO clothing redistribution remains unresolved.

# Male anatomy checkpoint — 27 October 2026

Chest and facial transitions now have a bounded local shape refinement beyond the approved head/joint pass, with the prior rounded version preserved for matched-angle review. Ten synthetic tests and both-renderer sampled animation/garment checks pass; 34 bones, inverse binds and 186 original animation channels are unchanged. See THIRD_DAWN_ANATOMY.md. Next: owner artistic review, eye/lip/ear detail, extreme-pose garment clipping, and more wardrobe layers. Current art remains a private source-derived experiment; no facial-expression rig or universal clothing compatibility is claimed.

# Focused male silhouette checkpoint — 27 October 2026

Owner now requests targeted geometry changes for the pointed head and angular joints, while retaining the material work and acceptable body. Local masked rounding and bounded weight smoothing are implemented; same-material before/after review and Head close-up are available. Nine synthetic tests and both-renderer animation/garment samples pass; see THIRD_DAWN_ROUNDING.md. Next: owner artistic review, profile/rear and extreme-pose/clipping inspection, then face/eye/hair and additional garment layers. Old rig corrective deformation and distribution rights remain unresolved. The earlier broad subdivision rejection below is historical; current scope is local silhouette repair.

# Male skin/material checkpoint — 27 October 2026

Owner rejected further subdivision as low visual value. Prioritize the original male mesh with material/texture improvements. PBR v2 normal atlas, approximate de-lighting, skin roughness/specular regions, mipmaps and matched old/new review are implemented; actual GPU responses, animation and full verification pass. See THIRD_DAWN_SKIN.md. Next artistic gates: cleaner unlit albedo, face/eye/hair treatment, atlas seam review and more clothing masks/layers. Synthesized normal relief and material regions are approximate; old silhouette/anatomy and distribution rights remain unresolved.

# Male body/wardrobe refresh checkpoint — 27 October 2026

Private male-body comparison includes original, AI-textured, conservatively subdivided, chain-shirt and robe variants. Original skeleton/animations are retained; two garments share one rig and use prototype body-hiding masks. Eight synthetic tests, sampled deformation/ground checks and full verify pass; see THIRD_DAWN_HUMAN.md. Next: review face/hands and atlas seams, reduce painted lighting, extend explicit clothing hide rules and test attacks/deaths. Arbitrary equipment combinations, hues/hair/weapons, live native equipment mapping and distribution rights remain open. Two tested garments do not establish universal wardrobe compatibility.

# Sign texture checkpoint — 27 October 2026

All 54 requested sign-face reinterpretations are generated and locally reviewed in `outputs/item-catalog/signs/modern` (same filenames; 1254×1254 PNGs; source hashes and prompts recorded; ignored/local only). Next for integration: assign sign-face materials, fit UVs to each modeled board and inspect in-world at distance. Texture generation does not resolve the queued road-sign board geometry or permanent street-name display below.

# Owner-reported Britain defects (queued after the catalogue matching) — 27 October 2026

From the owner's in-game screenshots; fix with shared rules, then verify in captures:
1. Wall caps 102/108 (stone wall pieces whose later tiledata names are "ornate elven bookshelf"/"ethereal voyage scroll") render as a bookcase/book on wall corners (14 + 2 in Britain). Wall-flagged graphics must stay masonry.
2. Castle entrance just after the wooden drawbridge: the main gateway (between two arched side doors) is walkable in the source/server but is drawn as a solid wall; it must be rendered as an open passage. Find the passable gate cells under the wall run and open them. Compare rendered walls/collision with passable source arch cells (208/209/111/113/320 are passable, 206/207 piers impassable).
3. Stone arches (206-227, 110-113, 317/320) use the Quaternius wooden Wall_Arch frame; build them in masonry of the wall family.
4. Gatehouse: stacked "stone post" 204 render as thin detached poles above the roof, mixed wood/stone. Render posts as square masonry piers matching the walls, and check what the top-level pieces really are.
5. Floating pieces on towers above crenellations; gaps between walls and roofs; an unexplained opening in a building.
6. Clunky "York" houses: over-dense studs; dark plank houses with white plaster bands around windows.
7. Road signs: two boards on one post have broken geometry; street names must be shown on the boards permanently, not only on click.
8. White plaster panels over doorways and openings in brick (and other masonry) walls; lintel/infill pieces must take the wall's own family.
9. Britain castle: roof fragments out of place on towers and wall tops (timber roof slabs hanging off battlements, white dashed lines along wall faces).

Owner requests queued next: (1) replace the plaster wall material (current lime render reads flat and fake) with a photoscanned rough-cast/limewash set and real wall relief; (2) break up visible tiling on large uniform terrain: per-region texture variation, stochastic/rotated sampling and macro colour noise so neighbouring tiles of the same land type blend without a repeating pattern.

Performance for richer models (after the defects): (a) automatic mesh LODs on import for owner/kit props and kit modules, plus MultiMesh batching of repeated props per district cell, so full-detail models are used near the camera; measure the streaming route before/after. (b) Where repeated shapes match (towers, gatehouses, long wall runs), substitute larger modules, and merge each building's pieces into single meshes.

Approach: every fix is a shared rule plus an automated whole-map audit (floating pieces with nothing beneath, roofs not resting on walls, wrong-family infill, rendered walls on passable cells and open cells on impassable ones), so the same defects are found and prevented automatically as the map expands, not fixed building by building.

# Next after the item catalogue — 27 October 2026

Use the catalogue ranking to choose replacement families. Next: model naming rule (`Art/Modern/<category>/<family>.glb`) with automatic registration, isometric silhouette fitting/flagging against the original art, picture-similarity and mirror grouping, and a family override file. Then equipment appearance on the shared Quaternius skeleton (skinned garments with body-region hiding and hue masks; socketed weapons and shields).

# Next after character sheet/skills — 27 October 2026

Character sheet, skills and vitals HUD are live on native packets. Next gameplay presentation: an equipment paperdoll in the sheet (worn layers, drag to equip), skill-gain/stat-gain notices, war mode and a combat target/health bar for the selected mobile, then spellbook/casting. Keep the starting-up cost and the ~135 ms first-frame stall in view.

# Next after the free visual upgrade — 26 October 2026

Free shader/lighting work has reached diminishing returns. Next: an art-kit comparison page (same Britain street, 2–3 candidate kits with exact prices/licences) for an owner decision, then building geometry depth (roof eaves thickness/overhang, recessed windows, door surrounds) through the shared facade/roof rules, and replacement trees with LODs. Keep paid assets out of the public repository.

# Next after bridge/contact checkpoint — 26 October 2026

Bridge parapets/piers, generic masonry window names and wall-hung attachments are fixed through shared rules (see PROGRESS.md). Next: re-run the context-aware contact audit and resolve bar/shelf support heights; profile and reduce district-loading stalls with same-route before/after measurements; then a lighting/material upgrade and an owner-approved art-kit comparison before broader artistic work.

# Art-first next gates — 26 October 2026

The first shared replacement pass is implemented and inspected; see ART_CATALOGUE_PASS.md. Next: (1) resolve rendered bridge approaches, hanging attachments, remaining unsupported candidates and simplified architecture/materials through targeted captures; (2) extend reviewed per-graphic choices across Britain, prioritizing frequently visible exterior/interior items; (3) reduce district loading/upload stalls before further expansion. Keep catalogue status honest: 108 explicit choices / 88 reviewed does not mean all 1,597 static IDs are artistically approved. Source-level warnings are inspection candidates, not automatic repairs.

Live Britain checkpoint (2026-10-26): Launch.cmd now connects native gameplay to the converted 704×512 city, with nine physical districts, shared source-relative coordinates, full-city movement prediction, native movement packets and far scenery. A graphical development-account test completed 62 server-accepted run steps across x=1600 and beyond the former y=1568 boundary, reconciled exact XYZ (1599,1567,20), then returned home through the native recovery command. District retention/eviction and physical terrain checks are automated. Population/commerce remains concentrated in the original patch; combat, skills and city-wide native population are not claimed. See LIVE_BRITAIN.md.

Current mapping/seam checkpoint (2026-10-26): all 1,597 Britain IDs / 136,662 static records have explicit shared rendering coverage, with honest semantic-substitute confidence. Joined full-region plans feed both a city architecture bake and nine nearby draw chunks. Shared terrain/roof normals, floors, ceilings, UV phase, stable grouped ownership and source-based overhang switching address district seams. New props and stone/thatched/flat-roof families replace missing markers. Source/context parity, 357 offline checks and graphical boundary/reload checks pass. Live gameplay/population is still the original patch. See BRITAIN_MAPPING_AND_SEAMS.md for evidence, first-plan timing and remaining art/production limits.

Latest scope clarification: the requested expansion is the whole **city of Britain**. Explore-Britain.cmd (and the retained Explore-Britannia.cmd alias) now opens the native city bounds including castle/western outskirts, rounded to 704×512 / 88 chunks. All 360,448 terrain and 136,662 static records pass independent source parity. The city overview renders 42,382 simplified architectural/tree features; close-detail art and chunk seams remain unfinished. Live gameplay/population stays in the proven patch. See BRITANNIA_EXPLORER.md.

Latest: saved-world recovery and native commerce now pass headless and graphical checks. Full Britannia geographic conversion/overview is available via Explore-Britannia.cmd; all source records pass independent parity. Next gates: expand 3D mappings beyond the 187-ID reference catalogue, assemble architecture across chunk boundaries, then connect streamed gameplay/population. The full-world explorer is not full-world multiplayer.

Current priorities after the Britain mapping/seam pass:

1. Live city movement/collision is connected and a native boundary route passes. Extend traversal checks to castle, docks and varied elevations; reduce startup and district frame stalls.
2. Expand native doors, signs, containers and vendors in bounded, auditable city batches; retain the existing population limits until that work is explicitly implemented and validated.
3. Extend native gump/action coverage, selling and wardrobe presentation beyond the verified interaction loop.
4. Review rare prop/landmark art, first-detail planning time and neighborhood performance. Semantic mapping coverage is not exact bespoke artwork fidelity.

# Roadmap

Immediate priorities after the prepared streaming/minimap pass (26 October): (1) reviewed exterior AND interior fidelity for one representative Britain block, including floating/misrepresented objects and contextual materials; (2) further reduce measured loading/upload spikes and partition offline world topology; (3) then extend regions and native gameplay. Preserve the shared conversion rules. Directional sign text-on-surface idea is recorded in ART_FIDELITY.md. Source-ID coverage is not visual approval. See STREAMING_AND_MINIMAP.md and CLASSICUOMOSHU_REVIEW.md.

| Milestone | Status | Acceptance / remaining work |
|---|---|---|
| 0 Audit | Completed for imported code/dependency inventory | Baseline tests and architecture documented |
| 1 Authentic conversion | Implemented/tested for small Trammel base+diff crop | 15 parser checks and real viewer load pass; independent in-game comparison outstanding |
| 2 ModernUO integration | Godot and native ClassicUO entry verified locally | Compressed game login, character creation/selection and actual spawn pass; ClassicUO observer and Godot primary both entered the running server |
| 3 First playable multiplayer | Local proof of concept implemented and tested | Real character entry, ACK/wall rejection, two-client movement observation, backpack opening/contents and actual keyboard-driven scene pass |
| 4 Reconstruction | Britain city mapping and seam pass verified | 1,597 IDs / 136,662 records mapped; joined roofs/walls/floors/terrain, source-based ownership and nine detail chunks. Exact art matching and other-region coverage remain |
| 5 Gameplay presentation | Native objects, commerce and inventory verified in reference patch | Gumps, buying/payment, container/ground transfers and equipment pass. Selling, full wardrobe, skills/combat/spells and expanded city population remain |
| 6 Full facets | Britannia geography/overview implemented | Full main-landmass binary chunks and independent source parity pass; live streaming now covers Britain city. Other regions, population and traversal coverage remain |
| 7 Platforms | Planned | Desktop exports, Android controls/performance, then Apple signing/testing |
| 8 Polish | Graphics/traversal pass implemented/tested | CC0 environment/furniture, camera collision, real run, local ceiling-aware jump and animation; physical replicated jump, equipment and further polish remain |
| 9 Production | Planned | Security, load tests, backup/restore, updates and operations |

Current slice complete: bounded source-backed prediction, rest-pose retargeting/continuous facing, connected roof/facade construction with corrected roof anchors, source material polish and server recovery tools. Next: strengthen latency/reconnect behavior, add foot IK and equipment presentation, then an item pickup/drop path. Numeric facet/file profiles, input bounds/provenance, independent map comparison and ClassicUO coexistence remain explicit debt. See PLAYABLE_POC.md for exact scope.

Input/login correction: mouse capture/release and focus handling tested; controller input requires opt-in; last Windows login is encrypted and prefilled. Visual material/lighting pass improves readability; faithful architectural silhouettes, roof joins, terrain materials and character art remain explicit presentation work.

Latest evidence: 117 offline checks; live six-step walk/run with exact server reconciliation and a second client observer; saved-account recovery to the Britain start; roof/wall centre and shared-edge tests. See STREET_MOVEMENT_PASS.md.

Visual quality target: polish one complete Britain building plus its street as the reference scene before extending the art treatment. Priorities are joined architectural volumes and supported props; bevels/proportions and higher-quality furniture; coherent surface scale, roughness and material variation; interior/exterior lighting and shadows; natural ground/foliage transitions; then character animation/foot contact and camera polish. The source grid is geographic input, not a requirement for visibly blocky final geometry. Current captures are reconstruction evidence, not a finished-art target.

Shared visual pass implemented: topology-based explicit/implicit corners, narrow storey seams, complete wide arches, unsupported gable suppression, bevelled timber props and bounded wind/water shaders. See VISUAL_PASS_02.md. Larger-map ID coverage and chunk-halo ownership remain unverified; art quality is still in progress.

Material/terrain/lighting pass: Forward+ default plus compatibility launch; verified CC0 PBR surfaces, source-constrained adaptive banks and wet-edge blending, glass/rafters/interior lighting, and verified live-clock wind/water. Reference district improved; larger-region silhouettes, asset mappings and neighbor-halo streaming remain next validation work. See VISUAL_PASS_03.md.

Interior/contact pass: closed source-height floor slabs and conservative void repairs; diagonal corner returns and wall-to-ceiling seams; roof/basement liners; corrected stair direction/bridge blocks and cardinal prediction; bounded post-animation feet, phase-preserving gait blends, camera trunks/recovery/leaf clearance; nearest-storey lamp cables and isolated natural peak filtering. 196 offline checks (final ceiling fixture separately after full run), six GPU animation checks, live development-account entry, both renderers and new captures. Shared rules carry forward for mapped families; native stair parity, larger-region coverage and full foot locking remain unverified. See INTERIOR_CONTACT_PASS.md.

Conversion pipeline and floor stability: end-to-end conversion now bakes the shared reconstruction rules and records rule/source hashes plus repair coverage. Stair supports/decks share the tread PBR material. Separated basement ceiling tops from ground floors and introduced single ownership for coincident terrain/static/duplicate floor surfaces. 201 offline checks and real conversion/bake/reload evidence; see CONVERSION_PIPELINE.md.

Reproduced doorway flicker with moving GPU captures: lower-storey wall caps intersected upper floors. Tall facade caps no longer render through floors; sills/gables retained. Constructed indoor land floors replace blended landscape floors, screen-space leakage disabled, and connected coastal spurs use a two-cell source halo. Visible crop unchanged. 205 offline + four GPU stability checks, full conversion/bake/reload and compatibility pass. See GLITCH_STABILITY_PASS.md.

### Britannia Reborn public checkpoint

Canonical repository: https://github.com/rastlyn80/Britannia-Reborn. Original project code: GPL-3.0-or-later, with retained third-party licenses. Server-driven regional clock/light/weather, improved sky/clouds and sheltered precipitation are implemented; details in SERVER_ENVIRONMENT.md. Next: bounded upstream world population and server-owned item rendering/interactions, then expand and validate conversion seams. No full-world population, full facet conversion or production readiness is claimed.

### Native world-object checkpoint

Whole streamed city now populated (4,489 server root items incl. 377 door leaves and 121 signs; 27 Oct 2026). Original slice: 131 decorations + 12 door leaves + 5 signs; 8 single doors and 2 linked double pairs; 65 native containers. Repeat population preserves open doors and creates zero duplicates. Real mouse interactions and actual building names pass in both renderers; shared doorway proportions and item lifecycle have 30 regression checks. Next: systematic ClassicUO placement/behavior comparison, then a larger region and chunk seams. No map expansion or NPC spawning occurred. See WORLD_OBJECTS.md.
