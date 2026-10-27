# Male/female first wardrobe batch integrated — 27 October 2026

Both fitted CC0 humans now render in the live world and character-sheet portrait. Native creation offers male/female; server body/skin/equipment drives one shared skeleton with five independently fitted pieces and 32 coverage masks per sex. Full project checks, native login, actual asset/48-pose robe validation, all combinations, dedicated character creation/reconnect and a second client's robe updates pass. Corrected the female cuff/skirt weighting overlap. Category substitutes remain explicit, including trousers for native starter skirts/kilts; universal wardrobe and full graphical creation remain open. Owner rejects mannequin-like movement: animation quality is a priority requirement, not completed/accepted. Bundled UAL walk/jog/sprint retargeting was probed on both rigs; gait/foot-contact tuning and robe rebaking are next. See HUMAN_BATCH_INTEGRATION.md and CHARACTER_SYSTEM_PLAN.md. Art and test accounts remain local/ignored.

# Character plan, robe continuity and natural appearance — 27 October 2026

Saved CHARACTER_SYSTEM_PLAN.md. Implemented its first two stages in the private free-equipment review: retain all 6,386 lower-body triangles, eight garment-only controls following native leg motion, graduated hem lift around raised heels, cleaner pinned CC0 system skin, restrained detail/roughness/Forward+ SSS, eye/brow/hair treatment, three skin presets and short/bald choices. Original 53 bones/tracks remain numerically unchanged; 61 total bones include skirt controls. Actual GLB checks, 48-pose animated-opening/floor checks, both-renderer sampled motion and GPU material response checks pass; scripts/verify.ps1 passes (exit 0). Source and evidence: CHARACTER_FOUNDATION_POLISH.md and outputs/third-dawn/natural-human-review-evidence.json. Creator/live avatar/server integration remains planned, not implemented here. Additional hair candidates failed visual fitting review and stay off the UI. Skirt motion is fitted deformation, not cloth simulation; other poses and body shapes need review. All art/captures remain local and ignored.

# Five free wearable substitutes + human PBR pass — 27 October 2026

Fitted the CC0 MakeHuman Viking mail tunic, trousers and boots (RehmanPolanski), plus monk robe/hood (Donitz), independently of UO geometry. Individual pieces and two layered outfits use the fixed 53-bone free body. Added matching Aksel diffuse/normal/specular maps (Mindfront, CC0), skin roughness/normal/Forward+ SSS, eye/hair adjustments and matched AgX studio views. Body geometry is unchanged within 5.96e-7 m round-trip error. Four new parser tests + ten prior tests, actual GLB skin/rig/animation checks, both-renderer 108 actor/120 worn-piece samples and GPU material probes pass. Full scripts/verify.ps1 passes (exit 0); log: outputs/third-dawn/free-equipment-full-verify.log. A local inventory finds 143 normalized human-prefixed names in 370 original Others GRNs; this is not all modern item IDs. Exact specialty armour and universal combinations remain gaps. No default live Avatar/server/login changes. All art/captures stay local/ignored. See FREE_EQUIPMENT_TRIAL.md and Review-Free-Equipment.cmd.

# Britain defect sweep: shops, windows, arches, doors, rugs — 27 October 2026

- Counters follow their real footprint cell by cell (an L counter had become one bounding-box table) with a panelled photoscanned-oak carcass; the stand-in Quaternius cabinet is gone. Display-case blocks are one glazed cabinet per cell (timber carcass, felt bed, rim, thin non-depth-writing glass) instead of one case stretched over 5x3 m; the flicker came from that stretched depth-pre-pass glass.
- Server decoration (potted plants, goods) rests on the presented surface by a downward ray; reviewed floor/surface items get the same final correction. Potted plants/trees are pinned CC0 Poly Haven scans (potted_plant_02/04); chests and metal boxes are iron-bound photoscanned chests.
- Generic "window"/"archway" graphics take the family of the wall run they sit in (log/plank houses lost their white plaster window panels; the Wayfarer's Inn gallery is a timber-framed opening, castle gates stay stone). Brick "arched" windows are glazed leaded casements under a brick segmental arch. Wall-top "stone pillar" sprites are slim pinnacles (Chamber of Virtue), not 4 m piers. Signpost stubs are no longer drawn (the server sign builds its bracket).
- Doors have jambs and a lintel; over-door infill continues posts and bressumer in timber walls. Plaster albedo lowered (no clipping to flat white in sun). Terrain may meet a wall 0.6 m above its base, so streets no longer form trenches along facades.
- Rugs: woven damask field (floral_jacquard), pile and relief from dirty_carpet, guard stripes and border on each rug's true outer edges (CC0 Poly Haven, pinned).
- Replacement pipeline started: PropReplacements.gd + prop-replacements.json map UO item names to pinned CC0 Poly Haven scans at real heights (statics and server items); wave 1 covers barrels, plates, bowls, buckets, baskets, apples, pots, stools, thrones, grandfather clocks; chests of drawers use GothicCommode_01. Rejected after side-by-side review: bare pale bookshelf, human statue for UO "statue" (eagle and others), spinning wheel (rendered empty). Chairs, bookcases and garbage (the largest groups) still need suitable sources.
- Walls standing a few Z above their plinth, floor or ground get a stone foundation course down to it (the daylight slot under raised houses such as 1491,1601-1625). Beds use the carved Poly Haven GothicBed_01 instead of the pink Quaternius/Kenney beds; server chests of drawers use GothicCommode_01; in modern mode candelabra and candles use the owner packs. Rug pattern contrast reduced.
- Museum/Sketchfab scans via the public Objaverse mirror: scripts/add-objaverse.py checks each licence on the Sketchfab API (CC0 or CC-BY 4.0 only), pins source and output SHA-256, reduces in Blender (scripts/blender-objaverse-reduce.py) and writes Viewer/Art/Objaverse/NOTICE.md attribution. Wave 2: chairs (carved folk chair, rush-seat chair; facings measured from geometry), book-filled bookcases, carved wardrobe, brass candelabra, Mary Rose tankard, chalice, anvil, iron chandelier, Galway fireplace (last two pinned, not yet placed). Reviewed scans outrank owner-pack stand-ins in modern mode. Rugs on several storeys of the same cell keep one border. Rejected after preview: park bench, tree-slice table, food-laden table scene, untextured stoneware jug, ore sack, plain candle holder.
- Owner report round: open armoires (ModernUO swaps 0xA4D/A4F/A51/A53 to their open graphics) keep their model instead of vanishing (regression check added); every free-standing server item rests its lowest mesh point on the surface below (pack candelabra sank), bake-time settling also raises sunken objects; rocks/logs no longer sway; arcades draw slim columns with arches springing between them, and arch openings span empty cells up to their pier (main gate, Chamber of Virtue, Sorcerer's Delight); bridge parapet runs share one deck-side offset; trunkless tree crowns become realistic trees of their species; the status panel shows the player tile.
- Training dummies (Medieval Combat Dummy, CC-BY) and hay (photoscanned hay pile, CC-BY) replace invisible stand-ins; scan replacements outrank pack slots. Upper floors get a timber balustrade on edges that drop into a stairwell (not where stairs arrive). Distance: depth fog 70-700 m with aerial perspective plus a gentle far depth-of-field blur. Shop signs can mount on arcade columns and piers.
- Door facings derived from door sets when exported facings are out of range (bank double doors, inner doors); on-screen tile readout. Topmost walls, posts and pillars rise up to 16 Z to meet a roof eave above them (Britain Public Library hall at 1440-1471,1694-1720 no longer shows sky under its roof); stacked columns are not pinnacles (portico banners hang on full columns); stairwell rails ignore platforms that reach the floor level (bridge-flagged landings at half height); stray roof tiles are dropped only when isolated from every other roof tile (an earlier stricter rule opened holes at ridges). Docks aerial capture not re-checked (capture timed out under memory pressure).
- Wave 3 (Sketchfab via Objaverse, CC-BY, attributed): cutlery/knife/fork/silverware, spoon, tray, bread, kettle, fruit basket, bellows, tubs, iron ore, cauldron, lute, drum, books, spellbook, firewood/logs; wooden table runs use a trestle table repeated along the run (stone/marble tables unchanged). Flat goods scale by length. Rejected after preview: cartoon ham/cheese/fish bucket, textureless banner/rope/chained book, mushrooms on a ground slab, hurdy-gurdy (no UO item). Pinned for the next wave (not yet placed): worn banner, wall torch, iron chandelier, Galway fireplace - they need wall-facing placement.
- Evidence: classic cache rebaked; captures outputs/art-review/defects-a..c; scripts/verify.ps1 passes (0 errors).
- Gaps: inventory finds 1,951 Britain graphics (about 38,000 placements) still on code-built or stylised-kit stand-ins; a curated replacement pass (Poly Haven CC0 / owner packs) has started. Door opening direction report, a raised staircase on a brick house and the chimney screenshot are still to locate.

# Free human base + UO3D wardrobe fit — 27 October 2026

Owner rejected further old-body anatomy work and requested a free human base with real wearable adaptation. Downloaded/pinned CC0 MakeHuman/MPFB-derived CharacterCreator exports plus official male skin; no downloaded code executed. New review compares old body, free 53-bone human and refitted original UO chain shirt/robe on target Idle/Walk/Run. Full source skeleton endpoints fix omitted garment-child bones; pose/segment fitting, surface correction, body masks and skirt hem reweighting replace direct bone-name attachment. Independent exported GLB rig/weights/animation checks, source input hashes, ten source-free tests and sampled checks in both renderers pass. Full scripts/verify.ps1 passes (exit 0); input hashes and actual GLB checks also pass. Art quality, cuffs/collars/skirt dynamics and universal wearable coverage remain open. Default Avatar/server/login unchanged; all combined art remains ignored/local. See FREE_HUMAN_WARDROBE.md for sources, licences, reproduction, evidence and limits.

# Scene audit, classic/modern Britain, gables, plaster — 27 October 2026

- SceneAudit.gd audits the built 3D city (not source records) per district: eave roof gaps, roof components touching no wall, floating loose objects, walls buried by terrain, overlapping props. After fixes: 33 eave gaps (one brick hall whose source roof starts 0.6 m above its parapet), 3 isolated roof tiles, remaining "floating" are mostly wall-hung decor and source-height props.
- ContactSettle.gd rests loose objects on the presented surface under them in every district build; terrain is capped at wall bases (no buried houses); stacked duplicate props draw once; display-case glass uses a depth pre-pass (no flicker).
- Classic/modern Britain: a "Britain: classic/modern" button (user://graphics.cfg) selects between two prepared caches (prepared/, prepared-modern/); prepare-streaming.ps1 follows the setting or -Classic/-Modern. Modern swaps loose props, server decoration, table/bench runs (library pieces along the run, warm oak tone) and shelves for owner-pack/CC0 library models; two unsuitable variants rejected.
- Gables of timber houses continue the framing (post per one-metre bay, tie beam); a roof's gable material comes from the storey directly under it (no stone gables over timber houses).
- Plaster: photoscanned Poly Haven white_rough_plaster (limewash) and clay_plaster, softened; lighter haze; ground textures sampled with anti-tiling offsets.

Next (owner order): multi-variant surfaces (5–6 photoscans per repeated surface, never the same variant adjacent, blended).

# Male chest/face refinement — 27 October 2026

Owner requested softer chest/face angles after approving local rounding. Added the optional --anatomy recipe and retained previous rounded assets for comparison. Reduced/raised the low chest wedge, broadened chest rounding and softened cheek/jaw/chin transitions without increasing the existing 5,792 triangles. Orthographic head/bust comparisons and Front/Three-quarter/Profile controls show identical materials at matched angles. Ten synthetic tests, byte-level rig/animation preservation checks (34 bones / 186 channels), and sampled animation/garment checks in both renderers pass. Profile and three-quarter captures were inspected. Full project verification passes (exit 0); log: outputs/third-dawn/anatomy-full-verify.log; its first attempt found a separate one-line roof negative-shift parser error, corrected with parentheses. Proprietary derivatives remain ignored/local. See THIRD_DAWN_ANATOMY.md for exact bounds and remaining facial/garment limits.

# Focused male head/joint rounding — 27 October 2026

Owner requested local silhouette improvements after the material pass. Added a masked rounding recipe for the head, elbows, knees, shoulders and ankles, with the same PBR v2 material on both comparison bodies. 93 unselected source vertices remain exactly fixed in the rest cage; selected geometry moves at most 32.585 mm in source coordinates. A bounded skin-weight pass softens joint transitions. Native rig/animations and original garment bindings remain in use. Head close-up visibly removes the pointed crown. Nine source-free tests and both-renderer sampled body/garment animation validation pass; final full verification log is outputs/third-dawn/rounded-full-verify.log. Generated assets/provenance/captures remain ignored/local. No live Avatar/server/login changes. See THIRD_DAWN_ROUNDING.md for reproduction and remaining limits.

# Male material pass v2 — 27 October 2026

Owner prefers shaders/textures over subdivision. Human review now compares the prior material and PBR v2 on the original 362-triangle body; shirt/robe also use original coarse configurations. Added a generated normal atlas, approximate shader de-lighting/neutral skin colour, differentiated face/palm/skin/linen roughness, derivative tangent reconstruction and mipmaps/filtering. Previous shader remains separately available. Skin detail/sheen sliders and a close material view support review. A new colour-atlas generation was blocked by the image tool; the existing atlas remains in use.

Actual GPU normal, roughness and light-response tests pass in Forward+ and Compatibility, with stationary actor roots. Eight source-free tests, both-renderer sampled animation/garment checks and full verify pass. Fresh matching-camera and side-light captures were inspected. No live login/server/default Avatar changes. Source-derived maps and provenance remain local/ignored. These are approximate materials on coarse geometry, not scanned skin or final modern anatomy. See THIRD_DAWN_SKIN.md.

# Male Third Dawn refresh, subdivision and first wardrobe — 27 October 2026

`Review-Third-Dawn-Human.cmd` compares original, AI-textured, subdivided, chain-shirt and robe variants in the existing Viewer. The warm-skin atlas follows the original UV layout as a prompt constraint (front/rear visually inspected), with a shared skin shader and retained briefs. Bounded Loop subdivision softens the cage without replacing its skeleton: body 362→5,792 triangles (≤18 mm source movement), shirt 106→424 and robe 210→840 (≤9 mm). UV seams and normalized skin weights are preserved; no new anatomy is reconstructed.

Garments use named Skin bindings on the same human skeleton/animator. Prototype coverage masks retain head/open collars/hands/feet and hide covered body regions. Eight synthetic tests and engine validation pass (60 body poses + 24 garment poses across Idle/Walk/Run, stationary roots, grounding and bounded deformation) in Forward+ and Compatibility. Reviewed front/rear/locomotion captures; full verify passes including the actual-crop smoke load. No live login/server/default Avatar changes. All source-derived art, prompts, provenance and captures remain ignored/local. Details and limits: THIRD_DAWN_HUMAN.md.

# Britain defect pass 1, doors/windows, cannons and sign art — 27 October 2026

Owner-reported defects fixed with shared rules (each checked in offline captures):
- Walkable wall pieces (gateways, arch openings; tiledata Wall without Impassable) join along their axis into masonry archways with real openings (collision follows the mesh); solid arch pieces are masonry piers. The Britain castle gateway after the drawbridge is open; no more Quaternius wooden arch frames.
- Wall-flagged stone posts/pillars render as square masonry piers in the wall's material, not thin round poles.
- Door infill takes the surrounding wall's family and rises to any battlement on the neighbouring wall. Doors and signs that arrive before their streamed district are rebuilt when it loads (they previously measured an empty world: white plaster bands over doors, signs parallel to walls).
- Facade shader discards only upward caps (overhang undersides showed the sky as white dashed lines along castle walls). No shutters or flower boxes on fortified walls.
- Timber framing: one oak post per one-metre bay (the half-metre close studding read as heavy stripes).
- Doors: DoorLeaf.gd builds plank, strong/metal, barred and gate leaves at the doorway's size from photoscanned CC0 Poly Haven surfaces (rough_pine_door, medieval_wood, rusty_metal_02) with Z-braces, strap hinges and ring pulls. Windows: every glazed window is an oak leaded casement (stone sill in masonry); shutters are wood_shutter board pairs with iron straps.
- Cannons use the pinned CC0 Poly Haven cannon_01 at real proportions. scripts/add-polyhaven.py pins models and surface textures with hashes.
- Street signs: arrow boards leave the post in their pointing direction; a post section always reaches every board; sign text is requested quietly from the server and painted on boards without clicking.
- Owner sign art: scripts/install-sign-art.py installs the owner's 54 painted shop/guild sign faces into ignored Viewer/local-art/signs; LocalSignArt.gd hangs square framed boards from the forged bracket with the face on both sides. Generated from proprietary references, so local only.
- Tools: AreaInspect.gd (source pieces in a rectangle) and ArchitectureAudit.gd (whole-map floating-architecture audit; the source data has only 13 floating pieces, so remaining "flying" defects come from presentation).

Still open (owner screenshots): roofs standing off brick walls, floating interior windows/plants/boxes, mixed materials around a shop passage roof, flickering display cases, low-poly procedural props inside buildings, plaster material quality, terrain tiling. Next: an audit over the built 3D scene (not the source) for floating/misaligned visuals and coplanar surfaces. Tests: full verify passes.

# Modern sign-face textures — 27 October 2026

Generated all 54 local sign references as separate modern painted fantasy sign-face PNGs in ignored `outputs/item-catalog/signs/modern`, preserving each `*_flat.png` filename. Every output decodes at 1254×1254; source/output filename parity is 54/54. Inspected the completed `review.png` contact sheet. `provenance.json` records exact source/output SHA-256 hashes and dimensions; `prompts.json` records all 54 built-in image-generation prompts. Originals remain unchanged. These reference-inspired outputs stay local and are not asserted to have a redistribution licence.

The artwork omits posts and frames and can supply sign albedo; Godot material assignment, UV fitting to individual sign meshes and in-world visual validation remain undone. No gameplay/server changes. `scripts/verify.ps1` completed successfully.

# Catalogue matching: owner packs, free kits and rules — 27 October 2026

Goal: give as many original graphics as possible a modern look from the owner's purchased packs, the CC0 kits and procedural rules, reviewed side by side.
- Regional rules (graphics outside the reviewed Britain set; Britain rule outputs diffed and unchanged except the intended wall-cap fix) cover named floors, walls, roofs, lava/acid, waterfalls, reeds, ferns, cacti, crystals, stalagmites, palisades, lily pads, leaf litter, snow and mats. New facade families (sandstone, marble, dungeon, cave, basalt, log, clay, cloth, hide); optional local original-colour tints (`item-colors.local.json`, never committed, Britain excluded).
- `scripts/import-owner-library.py` + `scripts/blender-library-convert.py` convert 180 models in 55 slots from 17 owner Dexsoft/Arteria3d packs (extracted locally with 7-Zip) into ignored `Viewer/local-art/library` (GLB, repaired textures, triangle budgets). `LocalLibrary.gd` fits a stable variant per cell (piles scatter copies); `library-review.json` records 9 rejected variants. `RegionalRules.SLOTS` maps names to slots with exact patterns; slots apply only to graphics outside Britain.
- Tropical Nature Pack plants converted with the existing nature importer and mapped (blade, snake, fan, elephant-ear, ponytail and water plants).
- Review loop: `ItemCompare.gd`/`scripts/compare-items.py` render sheets (original art next to this client's render from the classic viewpoint); `scripts/approve-families.py` records approved graphic IDs in `reviewed-families.json` (2,829 graphics); `ArtProvenance.gd` reports approved graphics by real status.
- Coverage by world placements: built in code 56.8%, owner packs 22.7%, CC0 kits 13.7%, not drawn 1.5% (94.6% done); untested guesses 4.2%, original only 1.2%. By family: 579 of 2,506 placed families fully done; the remainder is a long tail of rarely placed graphics.
- Fix: wall-flagged graphics renamed in later tiledata (102 "ornate elven bookshelf", 108) render as stone wall caps, not a bookcase/book on wall corners.

Remaining: bone piles, blood/web decals, sarcophagi, graves, banners, braziers, hedges, yucca/century plants and the long tail; owner-reported Britain defects are queued in ROADMAP.md. Tests: art fidelity 87 checks, full verify passes.

# Original item catalogue — 27 October 2026

`scripts/build-item-catalog.ps1` (new converter command `item-catalog`) builds a local art-direction catalogue in ignored `outputs/item-catalog`, in about 30 seconds:
- every original item graphic with art (36,527 PNGs, 141 MB) plus its tiledata name, flags, height, weight and worn layer;
- placement counts across all six facets, with local diff blocks applied: Trammel 2,948,639, Felucca 2,901,057, Ilshenar 370,530, Malas 331,605, Tokuno 170,579 and Ter Mur 493,161 statics, plus 40,279 server decoration items from ModernUO's Decoration lists;
- "placed in the world" counts every facet except Felucca, which mirrors Trammel and is reported separately; Britain counts use the native Britain region;
- a reviewed-model marker from `reviewed-catalog.json`.

10,697 graphics are placed somewhere. Families group graphics with the same name and category within 8 IDs of each other: 7,453 families, 2,506 of them placed. `index.html` ranks families (or single items) by world placements, with search by name/number, category and Britain filters, a detail panel per family (every member with counts per facet, an example location, flags and model status), `#family_key` links and CSV export.

**Current look labels.** `Viewer/Presentation/ArtProvenance.gd` (run by the build script) mirrors Reconstruction/WorldItems dispatch and labels each graphic: kit model (CC0 Quaternius, Kenney, Medieval kit, Poly Haven), your packs (local Dexsoft/Unity conversions), built in code, not drawn, untested guess (a name rule matches but the graphic was never placed in Britain or reviewed), or original only. The page defaults to "Needs a model" and dims finished cards. By placements: built in code 40.8% (water alone is about a fifth), your packs 16.9%, kit 9.1%, not drawn 1.0%, untested guess 21.3%, original only 10.9%. Of placed graphics: 1,223 built, 210 kit, 55 your packs, 4,978 guesses, 4,221 original only. Worn items are all "original only" because the avatar's outfit is fixed.

Limits: categories are name/flag heuristics (about 2,100 families remain "other"). Family grouping uses names and nearby IDs only, not picture similarity or mirrored pairs. Vendor stock, loot and multi (house/boat) components are not counted, so wearables and weapons rank near the bottom. The catalogue is proprietary-derived reference material; only the extractor and the viewer page are committed. Converter self-tests gained a PNG CRC check; scripts/verify.ps1 passes.

# Window shutters, Dexsoft props, character sheet and skills — 27 October 2026

**Shutters and flower boxes.** UO walls carry no inside/outside information. WindowDressing.gd reads the outdoor side from the source: indoor cells have a roof, upper floor or landing overhead within three cells. Outdoor cells are open to the sky two cells out, with at most a roof eave directly beside the wall. Windows covered on both sides, open on both sides, or facing another wall stay undressed. Of 1,042 Britain windows, 1,012 got an outdoor side and 30 stayed undressed. 946 got MedievalKit (CC0) open shutter pairs, because both neighbouring cells along the wall are solid wall; about half of those also got a flower box. Bridges and masonry slits/arches are never dressed. Dressing is excluded from collision and distant massing. Interior captures (tavern, two-storey house) show none indoors.

**Dexsoft props (owner-licensed, local only).** scripts/import-dexsoft-props.py converts five small Dexsoft Medieval Village props into ignored Viewer/local-art/props: two barrels, a crate, a tub and a haystack (220–784 triangles each, with albedo and normal textures). They replace the procedural barrel/keg (44 statics), crate (13), water tub (3) and hay (13) models, and server barrels/crates. Each cell picks a stable variant. Without the local conversion the procedural/CC0 models remain. Log piles (6) now use the MedievalKit woodpile. The Dexsoft houses and the 12 m wood shed are not used: they cannot fit UO footprints.

**Character sheet (C) and skills (K).** CharacterProtocol.gd handles:
- the full 0x11 status: attributes, vitals, gold, weight/max, stat cap, followers, AOS resistances, luck, damage and tithing;
- 0xA1–0xA3 vitals;
- 0x3A skill lists and single updates, including caps and locks;
- 0xBF/0x19 stat locks;
- the outgoing status/skills query, skill use (0x12/0x24), skill lock (0x3A) and stat lock (0xBF/0x1A).

Field layouts follow ModernUO's packet writers. The sheet shows:
- a live 3D portrait;
- attributes with stat-lock toggles;
- hits/stamina/mana and weight bars;
- the five resistances and the belongings figures.

The skills page groups all 58 skills as the classic client does. It has a search box, value/base/cap tooltips, raise/lower/lock toggles, Use buttons for the 23 skills ModernUO registers a use handler for, and a skill total. A vitals HUD (top left) is always shown in game. Window art comes from the owner's Necromancer GUI pack (scripts/import-unity-gui.py → ignored Viewer/local-art/gui: parchment window, buttons, seal, Kingthings fonts); without it a drawn parchment style is used.

**Verification:**
- Offline:
  - 27 new character checks: packet layouts, session merge, sheet/HUD values, filter and toggles.
  - Art fidelity 75 checks: woodpile, prop mapping, dressing side/undecided.
  - Full scripts/verify.ps1 passes.
- Live (scripts/test-character.ps1, headless and -Visual):
  - native v6 status for the development character (str 40, hits 70/70, weight 77/240, cap 225);
  - 58 skills;
  - Magery lock change confirmed by re-query, then restored;
  - Anatomy opened the server target cursor, then cancelled.
- Live world-item, city and login tests pass.
- Same-route streaming profile p95 18.8–18.9 ms, p99 20.3–20.5 ms (was 18.5/19.8); startup 4.8 s (was 2.8 s).

**Remaining gaps:**
- The portrait is the generic avatar, not equipment-accurate.
- No paperdoll equipment slots in the sheet; Equipment remains the separate list.
- No title/karma/fame or skill-gain notifications.
- Combat, spells and skill training loops are untested.
- Kegs share the barrel model.

# MedievalKit modules and surfaces (step 3) — 27 October 2026

The owner-supplied MedievalKit 5.1.1 (CC0) was exported with Blender 5.2.1 (portable, ignored in .tools; scripts/export-medievalkit.py) into Viewer/Art/MedievalKit. That is 20 lightweight modules (doors, shutters, lantern post, chimney, fence, sacks, woodpile, well, handcart, flower box, pots, plaque, basket, rope, crate, barrel, fountain statue) with a manifest of source hash, triangle counts and file SHA-256s. In use:
- the square-headed plank door for all 377 server door leaves;
- the lantern post for server lamp posts and the 8 lamp/lantern post statics;
- the picket fence for the 364 wooden-fence statics;
- the sack for flour sacks;
- the kit chimney, with clay pots, as the crown of every grouped chimney stack.

The kit's limewash and dark-oak PBR sets (with ambientCG Plaster002/Wood062 normals) replace the plaster and timber-frame surfaces of every facade. Whole-building kit modules are not tiled: a 2 m roof or stone-wall module is 24k–38k triangles, and UO buildings must keep their source footprints. Dexsoft Medieval Village 1–3 and Old Village were extracted locally (owner-licensed, ignored) but not used yet. They are mostly complete prefab houses with baked lighting; their props remain candidates.

Verification: art fidelity 71 checks and all Godot suites pass; the live city, commerce and login tests pass. The live world-item test passed on rerun; its first run hit a transient single-door close timing failure.

# Depth-aware water — 27 October 2026

Water.gdshader reads the depth buffer and screen. Beds, piers and banks refract through the shallows and are absorbed with depth (red first). Contact foam forms wherever the surface meets anything, including piers, hulls and banks. Seabeds now shelve away from the shore (1.5 m plus 0.45 m per tile, up to 6 m), so open sea reads deep blue and the coast reads teal. When converted locally (scripts/import-unity-water.py), the owner's Tasharen Water normal map (RGB) and foam mask (alpha) replace the analytic ripples and noise foam; the public build keeps the analytic version. Verified in Forward+ and Compatibility. Same-route profile: p95 18.5 ms, p99 19.8 ms (was 18.4/20.3). All Godot suites pass.

# City defect pass: chimneys, signs, bridges, roofs, walls — 27 October 2026

Fixes from owner screenshots, each traced to a source cause and covered by checks (art fidelity 61→69):
- **Chimneys:** UO builds a chimney from stacked/adjacent sprite tiles; each was drawn as a full 3.2 m model at its own Z (floating clusters). Connected chimney tiles now form one capped stone stack over the group footprint, rooted at the roof/wall record beneath.
- **Signs:** street signs (0x1297–0x129E) now sit on their post top, and plank plaques (0x1F28/0x1F29) lie flat against their wall or stand on two posts. Neither hangs from a shop bracket any more. On click, the server-confirmed text is engraved on both board faces ("the Great Northern Road", "the Northern Bridge").
- **Bridges:** BridgePlan records the deck side of edge parapets, which now sit flush on the deck edge instead of mid-tile over the water. This is a presentation offset; source XYZ is unchanged.
- **Roofs:**
  - "wooden shingles" hip/corner pieces were mapped to slate, which made blue zigzags and broke joins.
  - Gable infill was drawn on hip, valley and storey-step edges. It is now limited to edges open to air; stepped hips close in roof material.
  - Timber/brick gable wedges (24, 25, 193, 194, 85, 86; stacked in >90% of Britain placements) assemble like the plaster ones instead of poking through rakes as teeth.
  - Roofs with no walls beneath default to timber ends.
- **White bands and blocks:** the interior shell's wall caps (wall top up to ceiling) and the masonry over arches were hard-coded to plaster. They now take the wall's or arch's own family.
- **Furniture through walls:** bookcases 2713/2714/2716, chests 3648/3650, drawer 2616 and wardrobe 2641 occur only in north–south runs in upstream placements (e.g. 53/63/51 neighbour pairs along y). They now face east instead of standing sideways through walls.

All Godot suites and the live world-item, city, commerce and login tests pass.

# Server objects across the whole city — 27 October 2026

ModernUO had populated doors, signs and decoration only for the first 64x64 crop. The bounded population tool now accepts the streamed city region, and it ran once against the real server: +3,935 decorations, +249 doors, +116 signs, existing items preserved, repeat run created zero, persisted across a restart. Doors and furniture render live in distant districts. Also fixed: build-preview-tools.ps1 nested assemblies.json on rerun, which stopped the server from starting. Details in WORLD_OBJECTS.md.

# Realistic plants and cheaper trees (local only) — 27 October 2026

`scripts/import-unity-nature.py` (renamed from import-unity-trees.py) now also converts 40 Tree Creator bushes and 51 mesh plants (ferns, tall grass, wildflower groups, lavender, ground cover) from the owner's Unity packs; `LocalPlants.gd` uses them for UO grass, fern, flower and bush records, falling back to the CC0 library. Fixes found while integrating: the BIG Environment Pack meshes are authored Z-up and are now stood upright; plants are emitted as plain mesh nodes because material overrides inside instanced FBX scenes were lost when districts were packed (they rendered as white cards); every converted foliage texture is now mipmapped and VRAM-compressed (all 159 were imported without mipmaps). Tree cost: instanced vegetation is batched per 16 m cell so mesh LOD applies per cell, and `mesh_lod/lod_change/threshold_pixels=2.0`. Same Forward+ route versus the first local-tree profile: p95 25.4→18.4 ms, p99 →20.3 ms, startup 2.8 s. Open: one 147 ms frame with no streaming phase (likely a first-use foliage pipeline compile) and the existing ~70 ms near-district instantiate stalls. Godot suites (graphics 19/19, art fidelity 61, prepared 16, contact 55, street 43 and the rest) pass.

# Realistic trees from owner-licensed packs (local only) — 26 October 2026

46 Tree Creator trees from the owner's Unity Asset Store packs are converted locally (UnityPy-based `scripts/import-unity-trees.py`) with generated detail levels; Britain's 10,448 trees map by UO name to suitable species (cedar, willow, oak, birch saplings, elm/maple/beech, dead trees) and the distant layer uses the coarsest level of the same variants. Without the local packs the CC0 trees remain. Same-route Forward+ profile: p50 16.8→17.3 ms, p95 21.0→25.4 ms, GPU p99 21.6→26.7 ms, worst 91→80 ms; tree LOD/shadow cost reduction is still open. Grass tufts and bushes are still the stylized library. 442 Godot checks, parity, GPU and native city checks pass.

# Poly Haven props — 26 October 2026

Stylized props are being replaced with realistic CC0 Poly Haven photoscans (ten models, 53 pinned files). Barrels, crates, stools and tables are reviewed in tavern, castle and barrel-stack captures; lantern, candlestick, bucket, bowl and plate entries are provisional. Chairs, benches, bookcases, beds, bags and chests keep the previous library models where Poly Haven has no period match. Armour names ("platemail", "plate helm") no longer match the dish rule. 442 Godot checks, parity, GPU, native city and object checks pass.

# Rooted vegetation and flower-bed planters — 26 October 2026

Owner-reported flying trees and flowers. 90 "FlowerBed" pieces were classified as flowers (name match), so the 1 m raised beds were missing and the flowers/trees planted on them floated; they are now stone-curbed planters with soil at source height. UO stores one height per tile while the presented terrain interpolates between tiles, so vegetation at raw tile height floated or sank on slopes; trees, flowers, grass, bushes, mushrooms, rocks and logs now root on the higher of the rendered terrain at the tile centre and any planter/floor top beneath them, as a presentation offset (source XYZ unchanged; cases more than 2.5 m away keep their source height). 442 Godot checks (+5), parity, GPU and native city checks pass.

# Roof ends follow their walls — 26 October 2026

Owner-reported white blocks and "sails" over brick and timber buildings: every roof end (and source gable piece) was drawn in plaster regardless of the building, which became glaring once plaster was brightened. Each roof now takes the dominant family of the walls beneath it within three cells (brick, stone, timber or plaster), and source gables use their own family. 437 Godot checks (+1), parity, GPU and native city checks pass. Still open from the same screenshots: crude placeholder statues and an unidentified white board-on-posts prop near Britain's west bank.

# Stair facing from tiledata — 26 October 2026

Owner-reported crossing staircases: stair direction was inferred only from a same-graphic neighbour one step higher and otherwise defaulted to "rises north", so 316 of 926 Britain stair tiles (flight ends, landings, wide stairs, daises) faced the wrong way and intersected their flights. UO stair graphics carry their facing in tiledata (StairBack = east, StairRight = west, both = south, neither = north), which agreed with every unambiguous neighbour inference; it is now authoritative for "stairs" graphics, while low "step" pieces keep inference. 434 Godot checks (new four-direction test), parity, GPU and native city checks pass.

# Sea, Tudor plaster, stone merlons and water — 26 October 2026

Owner-reported defects fixed through shared rules. (1) 95,546 open-sea land tiles (map.mul "water", ~18% of the city dataset) had no water presentation and rendered as grass; terrain now presents them as a 1.5 m bed under a merged sea surface, the shoreline field includes them, and the ground shader treats them as silt. (2) Flicker: 935 river cells had a water plane exactly at terrain height, and plank/dock decks sat coplanar with the ground; sea quads skip cells that already have water objects and terrain under ground-level floors drops 6 cm (presentation only; movement uses source data). (3) Plaster houses follow owner-supplied York references: close-studded near-black oak (studs every 0.5 m, sill rail, heavy bressumer, run-end posts, braces) proud of bright white rough-cast using the photoscanned plaster relief, and leaded diamond-pane windows; studs never cross source openings. (4) Stone/brick wall tops (castle and tower merlons, parapets) were the village plaster/timber kit wall; they are now solid masonry with a coping. (5) Water shading is a continuous world-space normal (directional swells plus smooth analytic ripples, distance-faded), deep/shallow colour from shoreline depth and shore foam; the old tangent-space normal made each tile visibly different.

The stream bake now fails (no stamps, no index) when any prepared resource cannot be written — a running client keeps its districts open and previously caused stale districts to be stamped current. Evidence: 428 Godot checks (+5 new), prepared parity, GPU checks in both renderers, native city traversal and world-object checks pass; owner captures inspected locally. Remaining: trees (stylized library), stairs with crossing flights, roof/gable shapes and the converter test block.

# Free visual upgrade (step 2) — 26 October 2026

Turf now uses two pinned Poly Haven CC0 photoscans (`leafy_grass` close detail, `aerial_grass_rock` 15 m colour field) instead of a procedural green ramp. Lighting uses the AgX tonemapper, a light contrast/saturation grade and SSAO that also affects lit areas. Facade plaster takes tonal variation from its photoscan, varies between cream/ochre/grey lime washes by neighbourhood, and gains base damp, staining and streaks recovered from each piece's base/height (also under MultiMesh instancing); timber is darker, deeper-grained and its framing now projects from the infill. The bake now refuses to run when a pinned surface is not imported (a previous bake had silently stamped blank materials as current).

Tried and rejected: SDFGI bounce light plus volumetric haze made the streamed city GPU-bound (median ~30 ms, GPU p99 49 ms on the profile route); lower-cost SDFGI settings were still unstable while moving, so both are disabled. Measured back to back on the same route: GPU p99 20.6 → 21.6 ms, frame p99 22.5 → 22.5 ms.

Honest status: ground and timber read clearly better; plaster walls still look smooth at street distance, and trees/props/building geometry remain the stylized low-poly library and simple box construction. Those are the dominant remaining "toy" cues and need better models (owner-approved art kit decision), not shader work.

# Streaming stalls reduced — 26 October 2026

District loading no longer produces 100 ms+ frames on the profiled walking route: worst frame 326 → 40 ms (OpenGL) and 306 → 80 ms (Forward+), frames over 100 ms 22/24 → 0, p99 32.1 → 18.7 ms / 29.3 → 21.3 ms, startup ~1 s faster. Cause and fix: collision shapes are now baked as bounded triangle slices built within the frame budget, and source-window/support indexing is incremental. Retained memory +~40 MiB; a few 60–80 ms Forward+ frames remain. See STREAMING_AND_MINIMAP.md.

# Bridges, wall attachments and contact corrections — 26 October 2026

Shared `BridgePlan.gd` recognizes plank decks over water/riverbed, bridge-flagged stone piers and parapets from source relationships. Window art standing on bridge piers (graphic 94, 12 placements) now renders as dressed-stone towers with the source's barred slit instead of plaster walls with timber casements; low stone walls along decks render as stone parapets with a coping. Explicitly plaster/wooden construction beside a bridge is untouched, and the same graphic away from bridges is not reinterpreted. Fourteen window/battlement graphics whose tiledata names are generic ("window", "arrow loop", "battlement") now carry inspected art facts (stone/brick family, slit/arched opening) in `reviewed-catalog.json`; the castle curtain walls lost their plaster window slabs.

"Wall torch", "wall sconce" and "wall map" names were classified as walls (152 placements rendered as plaster panels). They are now wall-hung props: each is hung on the face of the adjacent west/north source wall as a recorded presentation offset; source XYZ is unchanged and unsupported cases stay put. Contact now recognizes exact/surface-flag supports, procedural table/counter tops (0.82/1.0 m rather than native 1.2 m), legacy rugs and same-graphic barrel stacks; duplicate beds stacked above identical beds are context-suppressed like benches/tables. The bridge/bank audit no longer reports water statics over riverbed as bank gaps — all 301 earlier candidates were that case.

Follow-up: legacy "bar" art (39 placements, panelled serving counters) rendered as garden fences; it now uses the shared counter construction and counter contact height. The refreshed context-aware audit inspects 1,409 reviewed placements: 1,286 supported, 103 presentation contact adjustments, 13 context-suppressed duplicates and **7 unsupported candidates** (was 53): two wine bottles above bar tops (gaps 3/5), a bottle on cards on a table, an elevated table and cards over a rug, one bed and one bench with no source support. Bridge/bank candidates fell from 301 to 1. Native headless city traversal (62 accepted steps, reconciliation, minimap, F6) and native world-object checks pass after the change.

Evidence: 447 offline checks pass (27 new); prepared parity passes for all 360,448 terrain / 136,662 statics; GPU matrix/ownership checks pass in Forward+ and OpenGL. Before/after local captures of the bridges, castle walls, dining hall, barracks, barrels and torches were inspected. Not yet re-measured: the refreshed full-city contact audit (the run was stopped by low system memory), native object/city traversal tests, and streaming-hitch profiling. Remaining visible contact gaps: items on bar/shelf pieces whose stand-in models are too short (e.g. castle dining hall), isolated beds/benches without source support.

# Reviewed art catalogue checkpoint — 26 October 2026

Implemented the first art-led reference-block pass: 108 per-ID choices (88 reviewed, 20 provisional), 35 curated CC0 Fantasy Props library models, detailed village doors/windows and six new stone/brick PBR maps. Imported and procedural rendering are explicitly distinguished. Shared source-backed contact rules align tabletop objects and stacked furniture without changing native XYZ; unsupported cases stay unresolved. Original code-generated wardrobes, canopy details and type-specific mugs remain where suitable imported replacements were unavailable. See ART_CATALOGUE_PASS.md.

A double-click Review-Art.cmd builds the local source/model gallery, per-ID inventory and automatic block/river/bridge inspection captures. All proprietary references remain local. Full offline verification passes 420 checks; prepared source parity and GPU ownership/matrices pass in both renderers. Native object actions pass headless and with actual mouse input under OpenGL; both renderers pass native 62-step city traversal, minimap and recovery. Repeated streaming stays bounded at roughly 317 MiB OpenGL / 435 MiB Forward+, with loading hitches still visible. This is a substantive first art pass, not completed visual approval across Britain. Bridge/roof silhouettes, rare IDs, material refinement and broader attachment/intersection checks remain. No region expansion or server-code edits in this pass.

# Prepared streaming and original radar checkpoint — 26 October 2026

Live Britain now loads prebuilt compact geometry/collision, decodes source only for nine active districts, streams bounded far/coarse scenery, and incrementally activates/retires scene parts. OpenGL prepared startup 3.591 s versus 41.864 s; retained engine allocations about 311 MB versus 1,491 MB; nodes 2,916 versus 83,705. Fourteen-destination reload tests plateau in both renderers. Loading hitches remain (worst rapid-move frames 1.27–2.05 s); full-facet offline topology is not bounded and is guarded at 128 chunks. See STREAMING_AND_MINIMAP.md.

A north-up, zoomable original-colour minimap follows native character position/facing. Six local radar tiles cover Britain; zoom wheel/+/- does not zoom the camera, and the texture window is bounded. All 397 offline checks pass without warnings/errors. Native 62-step route, door, reconciliation and recovery, actual mouse-wheel map zoom, all-record prepared parity, incremental scene equivalence, GPU transforms and near/far ownership pass in both renderers. No server code/gameplay edits or new art imports; user's saved login is unchanged.

Owner's visual feedback now governs the next milestone: improve exteriors AND interiors before artistic expansion. Existing mappings often remain crude semantic substitutes. Plan reviewed per-graphic models/assemblies with scale/pivot/support/material policies, exact licences and side-by-side source review. Directional signs with attractive destination text on their surfaces are recorded as an idea, not implemented. See ART_FIDELITY.md and CLASSICUOMOSHU_REVIEW.md.

Live Britain checkpoint (2026-10-26): Launch.cmd now connects native gameplay to the converted 704×512 city, with nine physical districts, shared source-relative coordinates, full-city movement prediction, native movement packets and far scenery. A graphical development-account test completed 62 server-accepted run steps across x=1600 and beyond the former y=1568 boundary, reconciled exact XYZ (1599,1567,20), then returned home through the native recovery command. District retention/eviction and physical terrain checks are automated. Population/commerce remains concentrated in the original patch; combat, skills and city-wide native population are not claimed. See LIVE_BRITAIN.md.

Current mapping/seam checkpoint (2026-10-26): all 1,597 Britain IDs / 136,662 static records have explicit shared rendering coverage, with honest semantic-substitute confidence. Joined full-region plans feed both a city architecture bake and nine nearby draw chunks. Shared terrain/roof normals, floors, ceilings, UV phase, stable grouped ownership and source-based overhang switching address district seams. New props and stone/thatched/flat-roof families replace missing markers. Source/context parity, 357 offline checks and graphical boundary/reload checks pass. Live gameplay/population is still the original patch. See BRITAIN_MAPPING_AND_SEAMS.md for evidence, first-plan timing and remaining art/production limits.

Latest scope clarification: the requested expansion is the whole **city of Britain**. Explore-Britain.cmd (and the retained Explore-Britannia.cmd alias) now opens the native city bounds including castle/western outskirts, rounded to 704×512 / 88 chunks. All 360,448 terrain and 136,662 static records pass independent source parity. The city overview renders 42,382 simplified architectural/tree features; close-detail art and chunk seams remain unfinished. Live gameplay/population stays in the proven patch. See BRITANNIA_EXPLORER.md.

# Current checkpoint — interaction, recovery and Britannia explorer (2026-10-26)

The user-approved forced restart recovered the saved world; native autosaving resumed. Commerce passes headless and in Forward+: correct native gold debits, tavern/inn stock, owned backpack purchase, public ownership rejection, ground/container transfers and equipment. The separate ClassicUO development character entered the matching street and its sign returned The Wayfarer’s Inn. Gump frame bounds, draggable windows, icons/hues and item actions have regression coverage. See COMMERCE_PASS.md for exact limits.

Building signs now project perpendicular to source facades on brackets, including their click targets. A separate whole-Britannia explorer converts Trammel X=0–5119/Y=0–4095 into 5,120 chunks. Every one of 20,971,520 terrain samples and 2,376,103 statics independently matches the owned inputs. The overview renders in Forward+, and a new district loads through shared terrain/reconstruction rules. Full-world art, chunk architecture ownership and gameplay streaming remain incomplete: new IDs appear as gold markers, not silently invented finished buildings. Live population/gameplay still uses the original validated crop. See BRITANNIA_EXPLORER.md.

# Current checkpoint — native world objects, artwork and gumps (2026-10-25)

The 64x64 Britain crop has 148 native root placements (131 decorations, 12 door leaves, 5 signs). Doors preserve eight singles and two linked double pairs; human-height leaves, shared lintels and PBR timber replace the earlier oversized door presentation. Native sign replies display actual building names. Graphic/type mappings distinguish small objects and furniture; local classic sign art is applied to 3D faces without publishing it.

Native containers and contained items are clickable; read-only books, dice-script replies, bulletin-board opening/reading and target-cursor responses are connected. A generic legacy/compressed gump renderer uses native pages/control IDs, local classic frames/buttons and real server replies. The Help option opened the server's description form and Cancel invoked its script, including actual mouse input under OpenGL. Full gump parity, item transfer and board-game manipulation remain incomplete; see docs/WORLD_OBJECTS.md for exact boundaries.

Saved graceful restart loaded 297 items and 3 mobiles. Population remains idempotent and current interactions work after reload. Live development-character movement now tests against a native closed door, replacing the obsolete route assumption. Latest full offline verification and renderer checks are recorded in docs/TESTING.md. No source client data, derived local art, credentials or saves are included in Git.

# Progress — 25 October 2026

## Current checkpoint: native world objects and usable signs

The current Trammel crop is populated with 131 upstream decorations, 12 native door leaves (8 singles plus 2 linked double pairs) and 5 native signs: 148 root world placements, including 65 native containers. Population is bounded to the prepared crop. Repeat population creates zero items, preserves serials and leaves open doors open. Native item types own contents, locks, permissions and saves; no synthetic loot or global spawn/decorate commands were used.

The 3D client now tracks authoritative world items separately from avatars. Actual mouse clicks open/close single and linked doors, show real container contents (including empty containers), and resolve the clicked sign's actual building name. The Salty Dog sign returned its native name and displays it above the plaque and in the interface. Doors keep the original single/double layout, with character-scaled timber leaves, iron hardware, lower lintels and infill to the original wall envelope. Shared DoorwayPlan rules cover translated/rotated fixtures; these are runtime server-object rules, not house-specific edits to baked geometry.

Validation: 248 offline checks (30 new world-item/doorway/sign checks), actual development-character entry and native item use, open-door population idempotency, and real mouse interactions/captures in Forward+ and OpenGL. The development character returns home after testing; the user's ClassicUO character/account is not moved. A save/config backup was made before population, and the resulting world was saved normally. Post-population restart/reload and systematic native/3D placement comparison remain unverified. No map expansion, NPC/vendor spawning, item transfer, equipment interface or board-game interaction is claimed. See WORLD_OBJECTS.md for setup, implementation boundaries and local evidence.


## Current checkpoint: material, shoreline and lighting refinement

Forward+ is the desktop default, with Launch-Compatibility.cmd available. Added 21 pinned CC0 PBR maps across seven surface sets, all verified and metre-scaled. Terrain retains original grid/elevation anchors and gentle-diagonal support while adaptively smoothing steep cells; rock/soil/vegetation, wet edges and shallow water blend from source masks and a signed shore field. Window glass/sills, roof-following rafters, warm client-only interior fixtures, contact shadows, indirect light and subtle haze improve the reference district. Tree/grass sway and water ripples pass both controlled-time and running-clock rendered tests. Source data and server gameplay were not modified.

150 offline checks, 21 texture checksums, six GPU animation checks and real development-character entry pass. All 2,689 source placements remain accounted for. Fixed-camera screenshots and forest/water GIFs are local in outputs/validation. See VISUAL_PASS_03.md for precise scope, reproduction, renderer fallback, source/collision guarantees and remaining larger-map/streaming/art limits. Restart Launch.cmd to load the pass.

## Current checkpoint: shared wall repairs and living environment

Supersedes the gable relocation described below: unsupported gable wedges are now suppressed, while exterior closures belong to the joined roof envelope. Explicit corners join neighboring wall planes; implicit perpendicular joins, one-Z storey seams, closed-door jambs and wide arch assembly address the other identified holes. The current audit records 14 corners / 34 branches, 20 implicit joins and 33 storey seams with no isolated corners. Furniture bevels/materials, finer paving/roof patterns, timber ceiling and lighting balance form the next visual pass. Trees, grass/small plants and water now animate using bounded shared shaders. This remains unfinished art, particularly terrain banks and complex roof intersections.

135 offline checks and three real GPU animation checks pass. Full source accounting remains 2,689 / zero unmapped. Independent translated/rotated fixtures verify that the join rules apply beyond Britain. Loading larger regions reruns the rules; additional source IDs and streamed chunk halos remain explicit validation work. See VISUAL_PASS_02.md for scope, audit counts, evidence and reproduction. Restart the viewer to load changes; no server restart or account changes are required.

## Contextual interior repairs

The previous capture still had two obvious artifacts. Read-only inspection of the original static block confirmed an elevated bench at (1621,1586,20), duplicating the bench at Z=0 with no supporting floor. Perspective rendering now suppresses only unsupported elevated duplicates; supported upper-storey furniture is retained. Source gable 330 at Y=1587 had no wall under it. Its assembly now attaches to the nearest sufficiently complete parallel wall with the same top elevation, Y=1591 (+4 visual tiles). Supported gables retain their original plane. Both adjustments are reported with reasons and offsets; source XYZ is unchanged. Map/debug rendering retains source placement.

The roof underside now uses timber lining rather than exterior slate. Bench orientation follows the assembled footprint rather than the first component ID. Fresh interior capture shows no flying bench or central hanging gable. This is a correctness fix, not the intended final visual quality: furniture remains simple, roof intersections and other building shapes still need dedicated art refinement. `scripts/verify.ps1` passes 127 offline checks (43 street/presentation checks), and the actual crop still accounts for all 2,689 records. Perspective collision: 72,296 triangles; 184 grouped contributors, 35 boundary fragments and one unsupported duplicate suppressed. Source files and server state are unchanged.


## Interior and classic-client follow-up

Source gable IDs 330/331 are now assembled from stacked wedges into continuous plaster infill, and adjoining furniture records become single brown wooden benches/tables/counters with spaced supports. This removes the staircase bands and overlapping pale full-model replacements shown in the user screenshot. Source positions are preserved. An elevated bench record at (1621,1586,20) remains visible above its ground-level duplicate; it is present in the source crop and requires support/data investigation. Roof junction silhouettes still need refinement. The interior capture is local evidence, not a finished-art claim.

Added double-click ClassicUO primary/observer launchers for the existing ModernUO server; see CLASSIC_COMPARISON.md. The native observer and Godot primary both entered the server. Pinned portable binaries and local profiles are ignored, BSD license included.

## Current checkpoint: retargeted movement, roof alignment and recovery

Implemented continuous visible facing, correct source-to-equipped rest-pose animation retargeting, native stride pacing, and bounded source-backed prediction. The pinned server has zero-cost turns; the previous full walking delay on turns and per-step resync caused avoidable pauses. Flat/gentle steps now start immediately; server ACK/rejection and idle/12-step reconciliation remain authoritative. Live production-scene walk/run matched exact server XYZ, a second client observed the movement, and first visible motion measured 16-17 ms locally. Arbitrary-angle authoritative physics and latency/stress tests remain out of scope.

Façade runs now share metre-authored structure/openings and kit surface materials. Connected roofs share mesh samples and have gable/ridge/fascia treatment. Both full building footprints showed the same one-coordinate east/south roof-art anchor bias; persistent [-1,-1] visual offsets correct it without changing source XYZ. Roof normals, ground materials/diagonal triangulation, lighting, hooded appearance and the HUD were improved. 2,689 records remain accounted for: 2,470 visible owners, 184 grouped components and 35 retained boundary roof fragments suppressed in perspective.

Added F6/Return to Britain, a native text command panel, crop-edge guard and isolated loopback-only PreviewTools server extension. The latest saved account character was returned to Trammel (1602,1591,20), confirmed by a server position reply. No privilege promotion. The world was explicitly saved, gracefully stopped, backed up under ignored work/server-backups, then successfully reloaded with the extension; upstream source remains unchanged. The server is running.

Current verification: 120 offline checks, converter/extension builds and real crop load pass; live login, recovery, six-step prediction/exact reconciliation and two-client observation pass. Updated screenshots, gait contact sheet and original-palette map comparison are local in outputs/validation. See STREET_MOVEMENT_PASS.md for reproduction, provenance and remaining fidelity/IK/physical-jump limits. Earlier checkpoints below are historical.


## Login memory and mouse camera correction

Camera look now starts only with an unhandled right-button press, captures the pointer, consumes relative motion, and releases before GUI routing on mouse-up, Escape or window focus loss. Controllers are off until explicitly enabled; their stick deadzone is 0.35. No idle camera recentering is introduced. Login fields retain the latest submitted account/password, seeded from the existing local development account when no saved login exists. Windows CurrentUser DPAPI encrypts the local vault through anonymous pipes; passwords are never passed as process arguments. Remember is enabled initially, with explicit forget/opt-out controls. Non-Windows secure persistence is not implemented and reports failure.

Visual pass: closer default camera, warmer light, softer ground/roof patterns with distance-aware filtering, 4x MSAA, coordinated low-contrast architectural materials using unchanged publisher texture files, smaller in-world instructions and hidden controller settings after entry. This does not resolve remaining architectural proportions, missing gable/hip reconstruction or crop boundaries. Original sources and server remain untouched.

Validation: all 84 offline checks pass, including 11 new encrypted-vault and mouse lifecycle checks. Live login/relay and server run/camera-wall/jump tests pass. New screenshot: outputs/validation/updated-street.png. Final screenshot was captured with scripts/test-graphics.ps1 -PreviewOnly without moving the character. A later full traversal rerun timed out, and its retry found the player at x=1604 rather than the fixture corridor x=1600; the harness now rejects that precondition explicitly instead of asserting a corridor wall at arbitrary positions. Earlier live run/camera/jump passes were at x=1600. Windows vault tests use disposable fixture credentials and remove their vault; no real login secrets are emitted. Re-run scripts/verify.ps1, scripts/test-login.ps1 and scripts/test-graphics.ps1.

## Latest checkpoint: complete crop catalogue, solid camera and run/jump presentation

All 187 used static IDs now have explicit persistent rules. All 2,689 source records retain ordinal/ID/XYZ and are accounted for: 2,645 visual owners and 44 grouped components. No unmapped crop IDs remain. Expanded Quaternius modules/nature plus audited CC0 Kenney furniture cover gaps; procedures supply continuous family-specific roofs, stairs, carpets and small props. Coverage is not exact original-art fidelity; confidence/substitutions are reported, including a post silhouette needing further review. Source artwork references are local-only, never game assets. Added chunked presentation collision (91,416 triangles), spherical camera sweep/recovery/near-body hiding and broad orbit/zoom.

Real Shift run packets and per-segment walk/run timing are implemented, with speed-scaled animation and consistent tile-centre presentation. Space produces a ceiling-aware animated local hop, tested through apex and landing; it does not alter server Z or replicate physical jumping. Server remains unchanged and authoritative. All 73 offline checks pass. Live wall rejection/recovery/backpack and actual run/camera/jump pass; real corridor camera retracts to ~0.697 units, jump peaks ~0.95. Existing server remains running. See GRAPHICS_PASS.md for reproduction, source/asset provenance, screenshots and limitations. Earlier 54-check / 556-unmapped notes below are historical.

Added reproducible original-colour radar comparison: scripts/capture-radar.ps1 renders terrain-only, static-overlay radar and an aligned north-up orthographic 3D view for the exact play crop. Local radarcol.mul/hues.mul supply original colours; highest drawable static base Z selects the overlay. Inspected outputs/validation/britain-map-comparison.png and separate 64×64/enlarged radar PNGs. This is a reconstruction of the static radar data, not an original-client UI screenshot; live mobiles and multis are excluded. Images remain ignored/local.

## Latest checkpoint: Quaternius art and smooth confirmed movement

Imported five free CC0 Quaternius Standard packs with bundled licenses, pinned archive hashes and selected-file manifest. C# tiledata metadata supports 32/64-bit flags and static heights. Current crop replaces 2,133/2,689 static placements; 556 unresolved pieces remain gold markers. Provisional connectivity/slope rules need architectural review; slate uses tinted round-tile geometry over a continuous roof bed. Nature, classified procedural ground and shadows are integrated. Real humanoids wear fixed peasant outfits and animate idle/walk/jog; equipment appearance is not implemented.

Confirmed server endpoints now drive continuous timed XYZ segments with preserved corners, rejection reset and bounded teleport/catch-up behavior; facing blends and camera follows after interpolation. Request cadence is 410 ms versus upstream's default 400 ms foot walk. Server collision and per-step resync remain authoritative; no prediction/continuous-physics claim. Full 54-check verification passes without warnings/errors. Live wall rejection/recovery/backpack and two-character visual keyboard test pass. Inspected playable.png and character-preview.png in ignored outputs/validation. Existing server left running; duplicate launch guard refused a second instance. Details and reproduction: ART_AND_MOVEMENT.md.

Next: validate roof/wall orientation and pivots against source landmarks, implement explicit corner/door rules and confidence overrides, improve camera obstruction/foot placement, then replace per-step resync with a tested elevation strategy. Earlier notes below are historical and superseded where they describe art as unimported or motion pacing as 450 ms.

User confirmed art sources: Medieval Village MegaKit for architectural statics and Stylized Nature MegaKit for nature, with Kenney only as a gap-filling fallback. Recorded in DECISIONS.md and ASSET_SHORTLIST.md. Import and archive-level license/provenance verification remain pending.

Asset survey: inspected current Britain crop and local tiledata read-only; saved ignored local inventory. Verified publisher CC0 declarations for Quaternius Medieval Village/Stylized Nature MegaKits and Kenney Fantasy Town Kit. ASSET_SHORTLIST.md records edition restrictions and first reconstruction target. No third-party art downloaded/imported or purchased; visual placeholders remain.

## Current checkpoint: playable local proof of concept

Added streaming Huffman and modern packet framing; creation/selection/spawn; server ACK/rejection and exact XYZ resynchronisation; nearby mobile replication; backpack open/content parsing; a character UI, interpolated capsule avatars and third-person WASD controller. Actual ModernUO created two distinct characters in Britain. Live tests verified wall rejection/recovery and a second client observing movement. The real viewer passed injected keyboard movement and captured outputs/validation/playable.png. Offline suite now has 39 checks. Server source remains unchanged; ClassicUO wire tables are adapted under BSD-2-Clause with retained notice.

Launch.cmd opens the primary account; Launch-Second-Client.cmd offers the second account. The 64×64 play-world crop covers Britain starting coordinates (1602,1591,20); the original region remains separate. scripts/prepare-play-world.ps1 regenerates it read-only. The pre-existing server was left running. Do not start another instance on the same runtime; the launcher now probes TCP and holds an exclusive lock.

Read PLAYABLE_POC.md for evidence, temporary resync overhead, fixed creation preset, reconnect caveat and the duplicate-server/save-collision observation. Next: improve session efficiency/reliability, character/geometry presentation and item pickup/drop. The older notes below record the imported baseline and have been superseded where they describe character entry as unimplemented.

Final validation: 39 offline checks pass; real wall rejection/recovery, two-client observation and actual keyboard-driven rendering pass. Game seed/login now batches into one write (TCP still permits fragmentation); a further multiplayer + visual run passed afterward. Existing server save files show continuing autosaves. No other server instance was left running by these tests. Character selection uses the server's existing characters; creation was exercised on empty local test accounts.

Imported the working prototype into UltimaClone, preserving the original; corrected build/launch/setup/capture tool paths. Rebuilt converter: zero warnings/errors, all 15 checks pass. Godot loads the real Britain IR (2,304 samples, 1,616 statics).

Audited/pinned ModernUO ab59efea86fd9e399d261bed9d188ab4d95ad4c2 and ClassicUO ee79d7ebc1cc0e53ff84fe6cae17d389e2737f93. Server code unchanged; ClassicUO reference-only. Installed local SDK 10.0.201; server build has zero warnings/errors. Added NuGet locks, setup/build/start/configure wrappers and separate local runtime.

Godot now has direct login transport and a local connection panel. Eight packet tests pass. Live Godot → ModernUO authenticated, received one-server list and game relay. Tests print no password/token. A normal Player account was created through ModernUO and persisted via the server save command.

Runtime binds TCP 127.0.0.1:2593 and UDP loopback ping 12000. Provisional profile: upstream default Endless Journey with Trammel selected; not a final era decision. No game-file edits, purchases or publication.

Resume: read MASTER_PLAN, ROADMAP, DECISIONS and MODERNUO_INTEGRATION. Run scripts/verify.ps1; Start-Server.cmd; scripts/test-login.ps1. Credentials remain in ignored Server/credentials.local.json. Next: compressed game session, character selection/spawn and server-authoritative movement. No playable multiplayer claim yet.

Known issue: pinned upstream shutdown threw when pingServer was disabled. No patch/report; development enables loopback ping. Empty-account first boot needs a console (answered n); current runtime has a saved account. Sandbox sockets required approved execution; do not misdiagnose those timeouts as protocol incompatibility. Full upstream suite and established-client verification pending. Evidence: outputs/validation.

End-of-session state: test server saved its account and shut down cleanly with ping enabled. Launch it using Start-Server.cmd before live tests. Original converter and local-world IR match the imported originals by SHA-256. The source repository excludes the separate runtime and proprietary data.

Interior/contact pass: closed source-height floor slabs and conservative void repairs; diagonal corner returns and wall-to-ceiling seams; roof/basement liners; corrected stair direction/bridge blocks and cardinal prediction; bounded post-animation feet, phase-preserving gait blends, camera trunks/recovery/leaf clearance; nearest-storey lamp cables and isolated natural peak filtering. 196 offline checks (final ceiling fixture separately after full run), six GPU animation checks, live development-account entry, both renderers and new captures. Shared rules carry forward for mapped families; native stair parity, larger-region coverage and full foot locking remain unverified. See INTERIOR_CONTACT_PASS.md.

Conversion pipeline and floor stability: end-to-end conversion now bakes the shared reconstruction rules and records rule/source hashes plus repair coverage. Stair supports/decks share the tread PBR material. Separated basement ceiling tops from ground floors and introduced single ownership for coincident terrain/static/duplicate floor surfaces. 201 offline checks and real conversion/bake/reload evidence; see CONVERSION_PIPELINE.md.

Reproduced doorway flicker with moving GPU captures: lower-storey wall caps intersected upper floors. Tall facade caps no longer render through floors; sills/gables retained. Constructed indoor land floors replace blended landscape floors, screen-space leakage disabled, and connected coastal spurs use a two-cell source halo. Visible crop unchanged. 205 offline + four GPU stability checks, full conversion/bake/reload and compatibility pass. See GLITCH_STABILITY_PASS.md.

## Britannia Reborn and server environment — 25 October 2026

The project is now Britannia Reborn, with canonical public repository https://github.com/rastlyn80/Britannia-Reborn. Original project code is GPL-3.0-or-later; NOTICE.md retains BSD/CC0 and separately fetched dependency distinctions. README and CONTRIBUTING describe the actual early scope, public setup and data exclusions. The full local history was checked for proprietary inputs, real converted worlds, credentials and saves before publication; none matched the restricted paths or secret-assignment checks. Largest history blob is approximately 14 MB of licensed CC0 art. This is a bounded scan, not a complete transitive dependency/legal audit.

Native global/personal light and weather packets now feed the improved sky, cloud cover, fog, sunlight and sheltered rain/snow presentation. A read-only loopback preview extension supplies the actual upstream regional clock and current weather snapshots every ten seconds. Server core, source maps, gameplay and world state were not edited. A saved graceful restart reloaded 3 mobiles/50 items; the development character then received real clock/light/clear-weather data. Rain and snow screenshots use controlled state fixtures. Details and limits: SERVER_ENVIRONMENT.md.

The Godot title/login panel show Britannia Reborn. Its custom user-directory setting intentionally retains the former UO World Studio vault path; the existing encrypted login remains available. Setup now accepts a custom UO installation path and reuses the configured data directory on subsequent server launches.

Server-owned doors/containers/signs and broader world population remain the next integration milestone. No population or map expansion is claimed by this environment change.

Validation at publication: scripts/verify.ps1 passes 218 offline checks and the actual-crop load; 13 environment checks are included. Live environment and login tests pass after the rename. Controlled day/night contrast, cloud motion and real ceiling shelter pass on both Forward+ and OpenGL (3 GPU checks each). Moving-camera floor/doorway stability adds four passing checks; return-view RGB differences remain below 0.0017. No proprietary capture is included in Git.
