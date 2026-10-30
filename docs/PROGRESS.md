# Britain graphics complete — 30 October 2026

Owner request: finish Britain's graphics. **Britain is at 100.0% of 3,247 placed graphics (0 open).** The world is at 94.4% (625 → 603 open).

The last 16 Britain graphics:
- **New CC-BY Sketchfab scans:**
  - a bronze horse statue;
  - an abstract twisted sculpture, as white marble on a plinth (gargoyle sculpture);
  - leeks bundled as green onions;
  - plain-glazed donuts;
  - a stone wall fountain (Assisi scan) for the elven wash basin.
- **Scans already in the repo:**
  - the grandfather clock, for the clock frame;
  - folded cloth in blue, for unnamed 7185;
  - the grey rock in glossy black, for crystalline blackrock.
- **Crafted in `CraftedProps` from photoscanned materials:**
  - a sheaf of crossbow quarrels;
  - a cooper's inshave;
  - a pit-saw blade (floor saw);
  - spit roasts on forked uprights with the roast scan (rabbit and chicken);
  - a tied flax bundle;
  - a tall standing mirror for the gargoyle floor mirrors.

# Item catalogue waves 17–18 — 30 October 2026

**Bulk sourcing over the open backlog** with the Sketchfab API. About 120 candidate families were reviewed on sheets. Only honest matches were pinned; rejects were unpinned and their entries removed. 40 CC-BY/CC0 scans were added:
- **Furniture and fittings:** hammock, futon, bookstand, barrel lid, shackles, pulley, vise, tea set.
- **Structures and statues:** stepped stone pyramid (pylon), Haida totem pole (slimmed), stone gargoyle, scarecrow.
- **Plants and nature:** sea coral, brambles, morning glory, topiary, potted cacti, wall fern, corn stalk.
- **Food and small goods:** miso pot, wasabi, lettuce, lead weight, origami, feathers, hand fan, froe.

**Crops:** the CC-BY "Farm plants models" set is pinned once and split into single plants (`scripts/blender-split-variants.py`). The carrot, onion and potato patches and young shoots now draw carrots, onions, turnips and sprouts. A new model form, `Objaverse/<set>/split/plant_N`, serves split variants of a pinned scan set, with correct provenance in `ArtProvenance` (not labelled Poly Haven).

**Rejected after rendering:** scaffolding (fell apart), shell necklace, molehill (grass disc), skull totem, minotaur (carries a cube), windchime (broken bounds), ant nest (77k triangles after reduction), animated mandrake (Blender reduce failed).

**Counts:** world 93.4% → 94.2% (713 → 625 graphics open); Britain stays at 99.5% (16 open).

**Next:**
- Ter Mur architecture, which needs builders rather than models: floor tile 39807, angle walls, staitcube, canals, gargoyle spouts and windows.
- Exodus nexus pieces, horde statues and dragon heads.
- The remaining long tail of single-placement items.

# Item catalogue wave 16 — 30 October 2026

The owner provided a Sketchfab API token; it is stored only in the ignored `.tools/sketchfab-token.txt`. Sourcing and pinning now reach every downloadable CC0/CC-BY Sketchfab model, not only the Objaverse mirror. `source-candidates.py` lists such models as `sketchfab:UID`, and `add-objaverse.py` downloads them with the same licence checks and provenance records.

**New CC-BY scans:**
- **Harpsichords** (south and east sets): "Clavecin" by Favier, fitted to the 2×3 footprint with the keyboard toward the bench.
- **Harpsichord benches:** "Antique Bench" (red upholstery). Harpsichord benches are now one seat, not a bench run (`RegionalRules`).
- **Britain decorations:** pitcher, roast chicken, arrows (arrow fletching), dummy head on a stand (wig stand), corn cob, jester hat, porcelain milk jug and canned meat (spam). The pitcher and corn scans carried no usable texture, so they are recoloured.
- **Contribution statue:** uses the stone lantern scan already in the repo.

**Counts:** world 93.2% → 93.4% (733 → 713 graphics open); Britain 99.1% → 99.5% (30 → 16 open).

**Still open in Britain, because no honest free match was found yet:** crossbow bolts, donuts, green onions, rabbit on a spit, gargoyle mirrors and sculpture, floor saw, inshave, flax bundle, elven wash basin, clock frame, crystalline blackrock, horse statue.

# Item catalogue wave 15 — 30 October 2026

Owner request: search deeper for free models (elven chair, harpsichord) and use real textures for the tapestries.

**Tapestries:** all 31 tapestry graphics are now woven hangings textured with photographs of real public-domain tapestries from the Art Institute of Chicago (CC0).
- The photos are pinned by a new script, `scripts/add-artic-textures.py`, into `Art/Tapestries`, with a manifest (artwork page, IIIF source, crop, SHA-256) and a NOTICE.
- Eleven weavings were chosen to match the originals' colours: hunt and falconry scenes, Berain grotesques, leaf verdure, woodland, Phaeton, the Vatican pheasants, Diana's nymphs, the Emperor of China, Caesar and Cleopatra, and Apollo.
- The builder is `CraftedProps._tapestry`: gently folded cloth on a rod with finials, a free-standing post frame or a gilt frame.
- All tapestries now hang on the adjacent wall (`mount: wall`). Without a wall, or for server items, a tapestry hangs on the side its original art shows.
- The worn-banner stand-in for "tapestry" is retired.

**New scans:**
- **Big elven chair:** CC-BY Sketchfab "Elven Chair (Free)" by wolfgar74, red cushion, four facings.
- **Icicles:** CC-BY "Icicle 01 (baked)" by Elin, six graphics, facings from the art.
- **Large vases:** a CC-BY terracotta amphora and a CC0 glazed vase (Minneapolis Institute of Art).

**Other looks, from scans already in the repo:** muck (nettle, recoloured), wheat sheaves (wheat-stalk bundles), rocks, boulders and the unnamed standing stone (the grey rock scan the other rock graphics use).

**Harpsichord:** the CC-BY "Clavecin" by Favier on Sketchfab is a real harpsichord, but it is not in the Objaverse mirror. `add-objaverse.py` now accepts `NAME=sketchfab:UID`, which downloads through Sketchfab's API with the same licence checks. This needs a personal API token in `SKETCHFAB_TOKEN` or `.tools/sketchfab-token.txt` (ignored).

**Counts:** world 92.9% → 93.2% (761 → 733 graphics open); Britain 98.4% → 99.1% (51 → 30 open). Sheets are local only (`tap15`, `tap15b`, `chair15`, `ice15`, `misc15`, `misc15b`, `rocks15b`).

# Human body sash and native cloth cutouts — 30 October 2026

Added the previously missing body sash (0x1541/0x1542, native MiddleTorso 17) to male/female humans and NPCs, with civilian and rigid plate-fit meshes. Catalogue regenerated: **248/1,126 graphics (22.02%), 73 categories**, 39,410 item/action rows and 332 UOP mode/action rows. Existing 35 classic / 28 on-foot / seven ordinary-horse action groups are unchanged.

The accepted sash retains the fitted shirt/plate topology and weights, 61 named inverse binds, independent native hair/item dyes and existing body masks. Plate fit closes above articulated faulds. Full and partial native dyes now preserve non-cosmetic alpha-scissor outlines and thresholds; cosmetic cutout behaviour remains unchanged. Middle-layer tunic/doublet and outer-robe concealment follow the native layer, while separate shirt/armour and long hair remain supported.

Evidence: **304 runtime/GPU checks, 128 views, zero failures**; **64 long-hair/ponytail views, zero failures**, including cape layering; four export hashes / 32 actual final-modifier poses / 7,104 sampled visible triangles with exact source weights and bounded offsets; eight completed Godot review frames and two sheets. Complete body and legitimate far-side/sleeve occluders are retained in the GPU references. These are finite art/pose checks, not universal garment collision or exact original ornament approval. Source licences, reproduction and limits: [HUMAN_WORKWEAR_BATCH.md](HUMAN_WORKWEAR_BATCH.md). Local evidence is ignored under outputs/human-workwear and work/workwear-*.log.

Verification: coverage source validator **110 accepted exports**, runtime coverage **791/791**, horse regression **2,468/2,468 / 768 contact poses**. Full scripts/verify.ps1 recheck exited **0** and completed all its assertions. It still logged the two existing StreetTests fixture errors at TimberBridge.gd:41 (missing id), plus existing teardown/RID diagnostics; the suite is not diagnostic-clean. The first verification attempt stopped on invalid local gump-art request JSON; the unchanged parser's standalone **12,040-packet fuzz recheck** and complete suite rerun then passed. No parser or bridge changes were mixed into this character batch. No live login change was made and no new server world-entry/multiplayer claim is made.

Held back: full/half apron experiments still show waist/lap defects and failed stricter pose/plate review. They remain **unmapped and uncounted**; rejected code/poses/renders are preserved only in ignored work/output folders. Next: a clean apron seam, then surcoat/dresses and remaining armour/weapon families. The sash and other torso/outer-leg combinations still need owner/combination-specific art review. Shared terrain/item work is preserved.

# Item catalogue wave 14 — 30 October 2026

Owner request: carry on with the item catalogue, choosing free art without asking.

**Seasonal trees** (owner tree pack, local): bare, autumn and white trees all drew the same green tree. `LocalTrees.seasonal()` now picks by graphic or by the crowns over a trunk (`Reconstruction.tree_crowns`):
- bare oak, plum and willow → leafless species;
- maple → autumn tree with crimson-tinted leaves (`TINTS`, also used by the baked far trees);
- fruit trees with "fall leaves" crowns → autumn species;
- cherry and silver sapling → snow-white species.

**New CC0 Poly Haven models:**
- **Yucca:** quiver tree, slimmed, leaves recoloured green.
- **White poppies:** celandine, petals recoloured white.
- **Flax:** periwinkle (already pinned), petals recoloured blue.
- **Cotton:** heliophila.

**Code changes:**
- New `Recolor.gdshader` behind a `recolor` key in prop-replacements, which repaints one hue of an atlas texture.
- **Gravestones** are crafted per graphic (`CraftedProps._grave`, which now receives the graphic id) in tinted stone: obelisks, carved columns, rose spires, needles, round-top single and double tablets, blocks, posts and fallen stones (43 graphics).
- **Ter Mur stone benches** (15871/15872) are dark masonry instead of timber (`Reconstruction.furniture_name`).
- **Gargoyle furniture** now uses existing scans: beds (Gothic bed), couches and chairs (carved chairs, facings checked), chests, dressers and banners.
- **Other existing scans now in use:** boots, limes, squash (pumpkin recoloured), arcanist statue.

**Counts:** world 92.3% → 92.9% (832 → 761 graphics open); Britain 98.0% → 98.4% (65 → 51 open). Sheets are local only (`trees14b`, `plants14`, `plants14b`, `garg14c`, `garg14d`, `graves14`, `food14`).

**Next:**
- big elven chair, small elven tapestry and harpsichord (crafted);
- large vases, icicles, muck, wheat sheaves, rocks/boulders kit look;
- Ter Mur architecture (floor tile 39807, angle walls, staitcube, exodus nexus);
- donuts, cooked bird, onions crop, mandrake, grapevines.

The Britain bake rebuilds once on next launch (Reconstruction changed).

# Item catalogue wave 13 — 30 October 2026

Owner request: carry on with the item catalogue.

Comparison sheets showed most remaining "guess" looks were wrong:
- swamp cypresses drawn as Italian cypresses;
- banana trees as agaves;
- wheat as grass.

**New CC-BY Sketchfab scans, from the Objaverse mirror:**
- **Cypress:** two bald cypress scans for all four trunks; their crowns now count as drawn by the scanned tree.
- **Bananas:** a banana plant and a banana tree.
- **Wheat:** a wheat field, coloured golden through the material repaint.
- **Britain decorations:** skull with candle, metal hanging lantern, training-dummy frames (drawn once per footprint), bo staff, and a purple rose of Trinsic.

**Code changes:**
- `PropReplacements` gains a "palette" key, which colours a scan's surfaces by material name; the rose scan has no colours of its own.
- Oak crown 3295 is approved, consistent with the approved oak crowns.
- The cypress library slot is removed.

**Counts:** world 92.0% → 92.3% (862 → 832 graphics open); Britain 97.7% → 98.0% (75 → 65 open). Britain's counted area grew to 3,247 graphics since the last 100% count. Sheets are local only (`w13trees`, `w13after`, `w13wheat`, `w13brit`, `w13rose`).

**Next:** elven chairs, tapestries and harpsichord (crafted, since no free scans were found), gravestones, yucca, flax, cotton, white poppies, Ter Mur pieces.

# Voice chat by speech-to-text — 30 October 2026

Hold V (or the talk-line microphone) and speak. Local Whisper turns your speech into text, which is said in game as normal speech: it appears in the journal and over your head. Settings, per character: language, translate into English, review before sending, and microphone.

Live evidence: a spoken clip went through the chat recognizer and came back from the server as your speech in 1.45 s. PolishTests passes 24/0.

Gaps: no real voice relay, because ModernUO carries no audio. Translation is into English only, Whisper's built-in mode. See MODERN_UI.md.

# Gameplay polish: paperdoll, gains, combat target, casting — 29 October 2026

Owner request. Details are in [MODERN_UI.md](MODERN_UI.md) under "Gameplay polish".
- **Paperdoll:** drag to wear onto the model or any slot, with the target slot lit from local tiledata layers. Slots flash on equip, refusals give their reason, and four more slots were added.
- **Gain cards:** skill and stat gain cards with a bar toward the cap, merged per skill.
- **Combat target:** overhead health bars in fights, a ground ring on the target, and a target frame that puts the attack target first, flashes on hits and trails the bar.
- **Casting:** a cast bar with words of power, glow at the hands, a coloured target reticle, and fizzle and mana endings.

**Evidence:**
- `PolishTests.gd` passes 22/0.
- A live drag with real mouse input equipped a shirt, confirmed by the server.
- Live captures of every state.

**Gaps:**
- A real server cast is untested until the test kit's new `magic` option loads at the next server restart. The running server was started by another session and did not accept the console shutdown, so it was left running.
- Other casters get no glow.
- Overhead bars for party members are not separate from the party frames.

# Human accessories: seven catalogue gaps — 29 October 2026

Added bonnet, feathered hat, tricorne, jester hat, chain coif, spellbook and native lit/unlit lantern on both human bodies. Corrected flipped coif routing; native dyes/emission, closed holding fingers, arm clearance and coif/long-hair/cape layering are connected. Catalogue: **246/1,126 graphics (21.85%), 72 categories**, twelve newly covered graphics; action counts remain 35/35 classic and 28/28 on foot with seven supported horse rider groups. Rejected apron/sash experiments are not mapped or counted.

Evidence: 16 accessory + eight hair exports; 995 checks / 448 actual GPU views; 256 hair views; 32 direct posed prop-geometry checks; all passed. Reproduction, sources, finite-test limits and the next clothing gaps: [HUMAN_TAILORING_BATCH.md](HUMAN_TAILORING_BATCH.md). Full verify passes assertions/exit status but retains existing bridge fixture script errors and teardown diagnostics; that shared work is preserved. Login: eight unit checks and the existing server list/relay smoke passed; no new live world-entry claim. Original body/bind inputs, upstream source, saves and remembered login are unchanged.

# Trinsic bridges: timber footbridges and solid stone piers — 29 October 2026

Owner report: a Trinsic bridge "looks really bad", and asked to look for a free model. Captures showed two defects. Trinsic's six canal footbridges were flat boxes on stilts with loose rail pieces. The long sandstone east bridge (2067–2104, 2790–2800) had wooden balustrades on its pier tops and hollow, slotted piers.

**Model search.** Sketchfab and the Objaverse mirror were searched through the existing pinning pipeline (CC0 / CC-BY 4.0 only), with eight bridge queries and 33 licensed candidates; Poly Haven was also checked. None fits a UO bridge footprint. The candidates are single fixed-proportion spans (stylised, low-poly or multi-million-triangle scans), while UO bridges are tile-built at exact walking heights and every crossing has its own length, width and ramps. Poly Haven's CC0 `modular_wooden_pier` and `modular_fort_01` kits are the best free matches for later dock and tower work.

**Shared rules instead of a model:**
- `TimberBridge.gd` recognises a deck of boards over water with a ramp as one footbridge. Docks without ramps keep their pieces. The bridge is drawn once, by its first deck board, fitted to its own footprint:
  - weathered boards (pinned CC0 Poly Haven `rough_wood`) laid along the walking surface, ramps included and gently rounded;
  - stringers and side fascias;
  - trestle bents with cap beams and cross bracing, down to the bank or riverbed;
  - sills, and post-and-rail handrails on both sides.
  Its members are accounted as components, and source XYZ is unchanged.
- **Solid piers.** A closed 2×2 ring of masonry wall pieces under a paved top is drawn as solid blocks. This applies to bridge piers and to paved thick-wall walks.
- **Stairwell rails.** They no longer appear on a pier top, and a stone block paved on top counts as a foundation, not a stairwell step.
- **Stacked landings.** A stack of stone blocks draws one paved top.

**Evidence:**
- Before and after captures of every Trinsic footbridge, the east bridge, the docks, Britain castle and the Trinsic west wall. These are local captures from preview bakes, not committed.
- A whole-region comparison (britain-trinsic) against the previous code: stairwell rails go from 245 to 139. Every one removed is in Trinsic bridge, footbridge or pier footprints; none is in Britain. 662 pier blocks; 6 footbridges with 580 records.
- `BridgeTests.gd`: 15 checks, run in verify.

**Remaining:** Trinsic's sandstone still reads dark brown, because of the regional art tint on `medieval_blocks_03`. The east bridge stays a solid causeway, as the source stacks it. The docks keep their individual planks and posts.

# Horse colours and riding polish — 29 October 2026

Implemented four native base coats (matched against private original stand frames) and server-driven full/partial hues, stable coat/tack regions, cycle-preserving gait transitions, turn balance, real bounded hoof support, authored interruptible leg-over mount/dismount, fitted riding garments and continuous robe lining. Camera/nameplate/picking track the dismounted visual body. Added canter-derived fast gait and prototype hit/death poses; corpse art, eating/lying, distinct fidgets and other mount families remain gaps. No source textures, bind/UV inputs, authoritative coordinates or upstream source changed.

Evidence: 414 native server/observer/re-entry checks; 134 actual GPU appearance checks; expanded 512 clothing views; 267 runtime/transition/slope checks and the prior 2,468 saddle/runtime checks. Latest evidence and finite-test limits: [HORSE_POLISH.md](HORSE_POLISH.md); separate worklist: `Viewer/Presentation/horse-catalogue.json`. Human wearables remain 234/1,126 (20.78%). Shared verify passes assertions but reports an error in concurrent uncommitted bridge fixture handling; committed reconstruction passes the same street tests. That parallel work is preserved.

# Ordinary horses and seated human actions — 29 October 2026

Implemented the first horse batch in the shared client: real skinned horse art with idle/walk/canter/rear, male and female saddle/stirrup/rein fitting, native double-click mounting/dismounting, mounted speed/camera/picking and observer updates. The four ordinary UO horse identities currently share one dark-bay warhorse. Seven rider groups now connect live; other mount families, exact coats, climb-on motion and the full animal action library remain deferred. Riding robe/skirt/kilt variants keep covered legs opaque; final tailoring remains open.

Evidence: 2,468 contact/runtime checks including 768 poses; 384 actual GPU clothing views; 270 native checks on two characters/clients in an isolated pinned ModernUO world (loopback 2594), all passed. Production 2593, remembered login, upstream source and original UO data remain unchanged. Human catalogue: 35/35 classic categories connected for supported humans/horses, 28/28 on-foot, unchanged 234/1,126 wearable graphics (20.78%). These are category counts, not exact item or universal animation fidelity. Source/licence pins, reproduction, local visual review and remaining gaps: [HORSE_RIDING.md](HORSE_RIDING.md). Licensed raw art stays ignored; standalone redistribution is prohibited.

# Full protocol layer: every ModernUO packet parsed or built — 29 October 2026

The owner requires full interaction with the server: nothing it sends dropped, nothing it accepts unreachable. Following the second blueprint (PROTOCOL_BLUEPRINT.md), with ClassicUO and ModernUO's source as references:

- **Dispatch:** a router feeds 14 protocol modules (`Network/Packets/`).
- **Coverage:** all 99 server packet types and 16 extended subcommands ModernUO sends have handlers. Every packet it accepts has a builder, or is deliberately not sent with a stated reason.
- **Client version:** now matches the owner's install (7.0.102.3).
- **Evidence:**
  - ProtocolTests 42/0, in verify.
  - Live census: 35 packet types, 0 unhandled. Tooltips now arrive for every object (148, one query each).
  - Paperdoll, profile, name and spell requests were answered live.
  - Full verify and the login tests pass.
- **Presentation (owner rule: it must look good, with items as 3D models):**
  - Phases 1-3 are built: effects, audio, shops, action timers, containers, paperdoll, modern gumps and crafting.
  - Phase 4 is built: party frames, secure trade, books, bulletin boards, the quest arrow and journal tabs. Live with two local accounts: party invite through the server's cursor, accept, party chat, and a traded dice cup arriving in the other pack. A book was written and read back.
  - Phase 5 is built: houses and boats (tile-built houses, procedural ships, custom-house designs), placement previews, speech keywords (ModernUO's spoken commands now work), a movable helm, world and treasure maps, A* walking to a tile, and the house designer. Live: a house placed, a custom house built and committed, a boat sailed by speech and from the helm, a treasure map decoded and read.
  - Phase 6 is built: fuzzing of every packet type in verify (12,040 packets, no failures; a full-scene pass also clean), proper logout, Change character, Reconnect, character deletion, server popup reasons (the idle warning no longer disconnects), every facet's map with a notice away from Trammel, and the race-change card. Live long census: 42 packet types, 0 unhandled, logout acknowledged, reconnect into the same character.
  - Remaining: mounts and creature bodies (in progress elsewhere), full models for houses and ships (owner-approved sourcing), and 3D for the other facets (world pipeline). The board and quest arrow are shown with sample data only, and there is no chat-channel window.

# Front end without a district; the right-hand panel replaced — 29 October 2026

The play launchers now open on a front end with its own small moonlit stage, with nothing from the map loaded: sign in, choose a character (shown on a plinth with its remembered look), create one with live swatches, and a loading screen.

- **Loading at the character:** districts load only once the server sends the character's position, so a character in Trinsic loads Trinsic.
- **The old right-hand panel is gone:** a game menu (Esc or the gear) holds settings, keys and help, developer tools, Log out and Quit. Peace/War moved to the vitals card, targeting to a prompt with Self and Esc, server commands to a console on the ` key, and connection state to a chip above the minimap.
- **Evidence:** front-end tests pass 26/26 and are part of verify. In a live run against the local server, sign-in had 0 districts loaded; after choosing the character, 9/9 near districts were in about 14 s. The HUD showed without the panel; the game menu, settings and console worked, and logging out returned to sign-in. Tests and tools without `--front-end` are unchanged.
- **Remaining:** deleting characters; profession and skills at creation; a server probe before sign-in. See MODERN_UI.md.

# Human action, wearable coverage and armour correction - 29 October 2026

Reached the owner's category targets with unchanged denominators: 35/35 original action groups have prepared clips; 28/28 on-foot groups are connected; 234/1,126 indexed wearable graphics (20.78%) have category art on both bodies. Totals: 65 categories and 59 clips per body. Seven rider clips are opt-in previews; mounted live playback and mount gameplay remain deferred. Replaced rejected body-derived armour shells with continuous tailored trousers/undercoat and separate manufactured plates, matte leather and brushed steel. Backing retains its cloth colour under native metal dyes. Full body/UV/bind foundation, native identity and existing movement are preserved.

Evidence: 94 new exports, 118 clips, 761 focused runtime checks, 1,152 cloth poses, 2,400 armour rigidity/floor poses, 320 actual GPU armour coverage cases and 400 hair-depth cases. Full verification, native login and live human re-entry/equipment/action checks pass. Remaining: category prototype silhouettes and layer polish, exact designs/dye masks, two-handed/support-hand/string/reload detail, remaining wearables and protocol variations. Category coverage is separate from final per-item quality and owner approval. Monsters remain out of scope. Sources, reproduction and finite-test limits: HUMAN_COVERAGE_SESSION.md and HUMAN_COVERAGE_SOURCES.md.

# Commit, persistent rules and talking to the world — 29 October 2026

Roadmap items 1–3 done plus the owner's follow-up.

- **Talking to the world.** An Ask box (typed, or Windows voice typing) feeds an offline interpreter that maps requests to the shared command grammar and never guesses; everything else goes to Claude Code through a server-side ask/answer/propose queue and `scripts/dev-edit-bridge.ps1`. A real round trip answered a developer's request with a scoped proposal.
- **Group edits.** Bounded rule scopes and shift-click multi-select apply as atomic batches with one undo.
- **Commit.** Session statics, placements and terrain fold into local committed overrides that the converter applies on every bake. Collision is kept consistent with ModernUO; only touched districts rebake, and running clients reload them live: 75 s bake, 2 districts, worst frame 146 ms. Persistent "always/never" data rules are supported; behaviour rules such as roof/wall attachment are routed to Claude as code changes. Each Commit is now also published to Git as one change file on a `world-edits/<id>` branch with a pull request, built by plumbing (no checkout), and merged edits apply on collaborators' next launch. Server-only state stays on the server. Evidence: commit converter tests 20/20, including published merging, skipping a published local copy, restore-over-hide and terrain built on published edits. A dry-run publish produced exactly one added file on `origin/main` with the working tree untouched, and the GitHub API credential has push rights. A real push and pull request is not yet exercised: it will happen on the first in-game Commit.
- **Talk (local speech).** The F9 panel records the microphone in game and recognizes it with local Whisper (whisper.cpp, 99 languages, offline). It has a language picker, optional translation into English commands, and a microphone picker. An 8 s spoken command is recognized in about 1.6 s on the CPU. AI edits follow the manual flow: the assistant role can only propose, and plans are drawn as drafts before Accept (live 41/41). Unknown requests go to Claude automatically, and long answers arrive in parts. See DEV_EDIT.md.
- **Code fix previews.** A converter fix is judged in the world before it becomes code. `scripts/code-preview.ps1` copies `Viewer` (code copied, art hard-linked, in 30 s) and bakes only the affected districts into `outputs/<region>/previews/<id>/`. A `codepreview <id>` proposal opens a card in the F9 panel: those districts swap in place, Before/After compares, beacons mark examples, and Accept tells Claude to make it permanent. Live check 6/6: 7 districts swapped and back, worst frame 98 ms. The first case, walls poking through sloped roofs (owner report), affects 981 walls in 36 districts; it is baked as a preview awaiting the owner's decision.
- **Previews and revert.** Assets follow the cursor and replacements preview in place; `revert-commits.ps1` rolls back.

Tests: server 65, client 72 (headless and GPU), converter 15, live 40; verify.ps1 and test-login.ps1 pass. See DEV_EDIT.md.

# Live collaborative developer editing — 28 October 2026

Owner goal: build and fix the world from inside it, together, and eventually just by talking (Claude Code now, voice later). Delivered a working vertical slice in live Britain. F9 opens a developer panel that joins a server-authoritative edit session in the isolated ModernUO extension (`[DevEdit` over the native connection; explicit account allowlist plus loopback; separate journal, never world saves). Supported: select and inspect statics (identity, coordinates, prepared source record), place approved decorative assets, move/rotate/replace/hide existing decorative statics, and bounded terrain height/surface brushes. Drafts, shared previews and accepted edits are visually distinct; preview/accept/cancel, history-derived undo/redo, reservations, revision conflicts, reconnect/late-join snapshots and deterministic edit sets all work. The converted bake stays immutable. It now records per-static render ownership, so edits collapse or restore only that static's geometry, and terrain deforms only affected district meshes on a worker thread, crack-free across borders. `scripts/dev-edit.ps1` is a Claude Code bridge using the same command model.

Evidence: 49/49 server-logic, 43/43 client (headless and GPU byte-level), 31/31 live two-client checks; edit survived a server restart (4/4). Two graphical clients saw each other's edits in 134–256 ms; the cross-border brush rebuilt 2 of 9 districts; worst edit frame 72 ms against a 19–45 ms two-client baseline. verify.ps1 and test-login.ps1 pass. Everything is visual overlay: ModernUO movement, collision, line of sight and saves are unchanged and the UI labels gameplay-affecting edits as preview-only. Joined architecture is inspect-only. Details, launch steps and gaps: DEV_EDIT.md.

# Civilian equipment and long-hair layering — 28 October 2026

Added fitted leather doublet, authored cloak, low leather shoes and ankle sandals for both human bodies. The wardrobe now has 20 equipment categories and 86/1,126 indexed graphics category-mapped; exact item fidelity remains separate. Long hair/ponytails retain visible tails over clothing and headwear; cloak-specific bindings follow its moving panel. Native hair/beard/item dyes, identity, fixed body/61-joint rig and 45 clips per sex remain intact. Rejected the rough pointy-shoe candidate; accepted low shoes derive from the traced CC0 boots. Sandals are Elvaerwyn CC BY 4.0 with source/licence/modification notices and login-screen art credits.

Evidence: 22 pinned source assets; 134 exported parts/masks; 768 civilian poses (three near contacts, no deep/floor failures), 816 prior cloth poses, unchanged 90 clips/body error below 0.000001 m, 46 new civilian/hair checks, 168 GPU tail-visibility cases (all retain over 99.5% of reference pixels) and 37 Forward+ render jobs. Full verification passes on the current shared project with zero engine/script errors, and on an isolated committed-world-plus-character copy. Concurrent world edits remain intact and outside this character commit. Eight native login tests pass; live re-entry/observer/equipment/login smoke remains unverified this checkpoint because connections abort before login despite the local listener (Godot Login send failed; delayed socket probe Windows 10053). No server/account/config/save changes were made. See HUMAN_CIVILIAN_BATCH.md for sources, reproduction, logs and limits. Artwork/captures/accounts remain ignored. Owner artistic acceptance, hair-card volume/edges, more layer/action combinations, shields/ranged/two-handed equipment and broader skin hues remain open.

# Tighter skirts and the human port catalogue — 28 October 2026

Owner asks to narrow skirt-like garments, preserve native dyes and continue human player/NPC wearables/actions without monsters. Refit robe/skirt/kilt from anatomical pelvis/leg samples, excluding A-pose fingers; compress deep pleats and rebake the existing controls while retaining full legs, body/UV/bind and sleeves. Matched Idle thigh widths: skirts 28.3–35.8% narrower, kilts 23.4–36.9%; female robe 10.8% narrower, male robe within 0.4% of its prior width. Added CC0 civilian shirt, soft cap and cloth hat on both bodies (16 equipment categories); rejected the bodice/doublet candidate after layered review. Native hue/partial-hue updates preserve independent hair/beard colours and walk phase. Two fidgets bring each body to 45 clips and 23/35 classic groups connected.

Review-Human-Catalogue.cmd generates a searchable local worklist: 1,126 indexed wearable graphics (84 category-mapped), all 35 classic human groups, 17 selected human/equipment UOP sequence records with 39 body / 293 equipment mode-action rows and 39,410 item/action review rows. Raw MUL availability, category art, per-item fidelity and pending QA are separate. Non-human candidates are flagged; mounted human groups are deferred. Sources, archive/member hashes, reproduction, evidence and gaps: HUMAN_WEARABLE_CATALOGUE.md.

Validation: 102 exported models, 90 motion clips with body error below 0.000001 m, 816 modern cloth poses, 192 native skirt/kilt + 96 native robe poses; 8 parser, 20 new wardrobe/dye and 60 motion checks. Full project verification passes. Existing dedicated server characters pass re-entry, robe removal/re-equip (including the new female shirt/kilt), reconnect, observer appearance/action updates, war/peace/bow and native login/relay. Logs: work/human-wardrobe-batch/verify-accepted.log, live-accepted.log, final-motion7.log and asset-checks6.log. Artistic approval, exact item shapes, some layered waist overlap/deep pleats, two-handed/ranged/turn/salute, racial class audit and broader skin hue fidelity remain open. All artwork/captures/native data and test accounts stay ignored; concurrent world work is preserved.

# Closed holding hand and slow-walk review — 28 October 2026

Owner approves the relaxed arm pass and asks for it in walking, with the holding hand closed. Normal/slow walking use the prepared moving arms; new current-only previews show both bodies. A close-up exposed static open fingers in the sword-idle reference despite the active grip helper. WeaponGrip now fits finger curls/thumb opposition on the fifteen right finger bones; it leaves the wrist/free hand animated and releases on unequip. Both bodies pass rendered-modifier checks with sword/hammer/sceptre through idle, walk/jog/run, cast and attack, plus actual avatar-controller walking at 0.98 and 2.44 m/s: 60 motion checks. Full verification passes; Forward+/Compatibility hand views inspected. See HUMAN_ARM_MOTION.md and work/human-grip/verify.log. Exact per-handle contact, left/two-handed equipment and robe drape remain open. Concurrent world work stays separate.

# Walking arms refined after owner feedback — 28 October 2026

Replaced the idle-arm override in armed/unarmed-guard locomotion with stride-driven shoulder/elbow blends. The free hand relaxes; the carrying arm retains a bounded swing and native fitted finger grip. Slow-walk elbow variation and jog shoulder motion are stronger, preserving authored arm/leg opposition. Both bodies remain 43 clips on the same mesh/61-joint bind, with garment-safe footwork and authoritative server state unchanged. New review snapshots compare the immediately preceding prepared motion with this revision. Preparation/86-clip checks and 816 garment poses pass; 52 motion checks include independent arm joints, all locomotion loop seams and actual avatar-controller playback at 2.44 m/s. Full verification passes without engine/script errors. See HUMAN_ARM_MOTION.md and work/human-arm-motion/verify.log. Owner quality acceptance, inflated-looking robe poses and exact hammer/sceptre grip fitting remain open; concurrent world/prop edits are separate.

# Human locomotion, armed stances and native action playback — 28 October 2026

Prepared 43 CC0 motion clips per sex, with neutral-pose/limb-axis retargeting, grounded presentation pelvis, short-stride jog, armed/unarmed locomotion/guard, separate sword strikes with authored recoveries, punches, casting, hit/death and bow. Body/UV/weights/inverse binds and the 61-joint rest rig remain unchanged. Shared cached motion resources keep independent NPC clocks. Native classic and selected new-format human actions now reach the world avatar; 0xe2 preserves canonical type/subaction/variation alongside historical aliases. Native war/peace selects ready/relaxed poses; starter katana IDs retain their identity while using the fitted sword category. Coverage is now 82/1,126 indexed wearable graphics. Server references, hair/beard fields and received statistics remain authoritative.

Robes/skirts/kilts use rebaked pelvis-space controls and garment-safe footwork; full leg geometry remains. Evidence: 86 exported clips, body error below 0.000001 m, 816 garment poses, 48 motion tests plus the prior 19 human/39 expansion checks. Native dedicated-account war/peace, bow, actual world avatar, reconnect and second-client action playback pass. Full verification and native login/relay pass; final logs are work/human-motion/verify-accepted.log, live-accepted.log and login-final.log. A one-line unused lamp-model cleanup fixes a prop leak exposed during live teardown; concurrent world artwork is preserved. Animated before/after: Review-Human-Motion.cmd; sources, reproduction and limits: HUMAN_MOTION_PASS.md. Artistic approval, full turn/start/stop motion, exact two-handed/ranged/moving combat and non-human/mounted families remain open.

# Expanded human wardrobe and native appearance — 28 October 2026

Added eight equipment meshes per sex (skirt, kilt, gloves, two helmets, sword, hammer, sceptre/staff), bringing the fitted wardrobe to 13 category meshes. Added four fitted hair meshes beside short/bald and four beard components covering all seven native human beard IDs. Shared player/NPC profiles preserve server serial/body, raw equipment, independent hair/beard IDs/hues, flags/notoriety and received statistics; absent NPC stats stay unknown. Creation sends these native fields, with reconnect/other-client checks. Native 32-entry hue palettes drive per-instance materials; skin remains three approximate presets. Animation requests are retained with native values/body, but general action playback is unfinished. Coverage audit: 80/1,126 indexed wearable graphics, only bodies 400/401; this is category coverage, not a complete port. See CHARACTER_PORT_PLAN.md and CHARACTER_EQUIPMENT_EXPANSION.md.

Evidence: 96 exported models, 192 sampled skirt poses, five proxy parser tests, 19 baseline + 39 expansion checks, dedicated styled character creation/re-entry, reconnect/observer equipment and hair checks, and eight native login checks plus login/relay smoke pass. Full verification passes against isolated committed world 69fb534 plus the character overlay and bounded nil-colour guard, with prepared local dependencies (work/character-expansion/isolated-verify-prepared.log, exit 0, no engine/script errors). Shared-tree full checks encountered bottle-colour expectations in concurrent world/art work; those edits were preserved. Forward+/Compatibility captures reviewed. Gait/armed stances, exact item/head-style art, non-human mobiles and full action playback remain open. Assets/evidence/test accounts remain ignored and local.

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
- Wave 4 scans + performance (2026-10-28): 17 more CC0/CC-BY Objaverse models pinned (mossy log, rocks, books, bench, inkwell, chests, bottles/carafe, fish, flour sacks, bedroll, cards, rustic fireplace, angel statue, hay pile); heavy scans re-reduced and the heaviest Poly Haven props get decimated copies in Art/Reduced (scripts/reduce-polyhaven.py, source hashes in manifest). Depth-of-field removed (it caused the reported blur) and the frame cost of repeated props cut. Britain placement coverage 86.7% final-quality (scan 13.2%, crafted 59.2%, owner 14.3%); gaps: garbage, mushrooms, wooden/iron fences, lamp posts, banisters, stalagmites, unnamed 2795-2810 records. Evidence: both caches rebaked; scripts/verify.ps1 passes (ArtFidelity 90/0, world items 35/35).
- Wave 5 scans (2026-10-28): scanned fly agaric/amanita mushrooms (mushroom patches per tile), English street lamps and candelabra that keep their lights, an iron wall torch with flame, a worn banner hung flat on the adjacent wall (banners now use the wall-mount planner), a marble angel statue (multi-tile statue drawn once, column statues on a stone pedestal, bird/gargoyle statues excluded), scanned chairs for 2894-2901 with sprite-checked facings, and reviewed benches routed to the scanned bench run. Prop replacements gained per-graphic overrides, variants, clusters, wall anchoring and pedestals. 12 weak candidates rejected (fences, gate, eagles, lions, knight, manure, small lamp, war banner). Britain placement coverage 89.2% final quality (scan 15.7%, crafted 59.2%, owner 14.3%); whole world 90.9% of placements but only 50.3% of 10,709 placed graphics (5,301 open across 1,356 names). Evidence: both caches rebaked; captures outputs/art-review/wave5, wave5b; scripts/verify.ps1 passes (ArtFidelity 93/0, world items 35/35).
- World coverage + memory (2026-10-28): ArtProvenance reports final-quality coverage for Britain, the world, each facet and per placed graphic (Felucca-only graphics now count) and writes outputs/item-catalog/open-work.json; the catalogue page shows it. New tools: scripts/source-candidates.py (bulk CC0/CC-BY candidate search with thumbnail review sheets), reduce-polyhaven.py --split with scripts/blender-split-variants.py (one glTF per variant of a Poly Haven nature set, all variants sharing one texture folder). Wave 6: scanned stumps, stick debris, a pole brazier with fire, spine and pelvis bones (prop replacements gained pitch and sized flames), Poly Haven flower patches by blossom colour (empodium, ursinia, periwinkle, gazania; flowers, orfluer flowers, poppies, campion), FenceBuilder (split-rail wooden fences, wrought-iron railings, stone piers with rails) replacing kit fences, and 5 owner-pack guesses approved after review (most guesses on the sheet did not match and stay open). GPU texture compression for all 3D art (1,619 imports, and now the project import default; owner GUI images stay lossless): Britain stress route GPU memory 3.72 GB to 1.26 GB, textures 3.25 to 0.84 GB, p95 21 to 17.5 ms, startup 6.8 to 3.4 s; the stress test now records GPU memory. Plan for whole facets: docs/WORLD_SCALE_MEMORY_PLAN.md. Coverage: Britain 90.3% of placements, world 93.2% of placements, 51.1% of 10,762 placed graphics. Evidence: both caches rebaked; captures outputs/art-review/wave6, wave6b; scripts/test-streaming.ps1 pass; scripts/verify.ps1 passes (ArtFidelity 93/0, world items 35/35). Gaps: 5,264 open graphics (vines, crystals, stalagmites, hedges, cattails, lilypads, bones, sarcophagi, stone arches, unnamed records), facet-aware streaming and bake not started.
- Stacked fence posts (2026-10-28, owner report at the porch 1491,1622): UO stacks fence pieces (railing pieces at z18/z24, post-only pieces at z30/z36) into tall railings and porch posts. Each piece's post now spans the full source height and is capped only when no fence piece continues above (Reconstruction indexes fence cells), so the stack reads as one pole instead of segments with gaps and caps. Evidence: captures outputs/art-review/porch; ArtFidelity 94/0 (new stacked-post check); scripts/verify.ps1 passes.
- Fence junctions (2026-10-28): fence pieces know their neighbouring fence pieces (Reconstruction indexes fence ids per cell and Z, within 3 Z). Rails run from the tile centre toward each joined neighbour; a post stands at the centre where the art has one or where the run ends or turns, so corners, T-junctions and ends meet without overshooting rails. Iron railings meet at a newel, stone piers carry rails between them; isolated pieces keep the art layout. Remaining: where two meeting runs sit at different source heights (porch side run z18, front run z20), their rails meet with that offset. Evidence: captures outputs/art-review/junctions; ArtFidelity 95/0; scripts/verify.ps1 passes.
- Roof staircases, porch posts, hay on dividers (2026-10-28, owner reports): (1) the stepped dark "notches" across several roofs (slate hall 1449-1473/1702-1716, half-timbered slate house, thatch 1504-1516/1560-1576, shingles 1647-1664/1632-1657, thatch 1663-1680/1543-1552) were interior partition walls raised by the eave rule to each mid-slope roof tile, their timber caps poking through the slope. Walls are now raised only to a roof's eave course (its lowest tiles within 3 Z), so outer walls still meet raised eaves and partitions stay in the attic. (2) Fence posts always stand at the tile centre, so stacked post-only pieces line up with the railing posts below. (3) The top rail of a wooden fence reaches just under the piece height, so hay UO lays on a stall divider (z16 on a z10 h6 divider at 1306,1777 and 1306,1783) rests on a real rail. Evidence: a roof-height scan of Britain (neighbouring tiles off the 3-Z slope rhythm) located the roofs; captures outputs/art-review/roofs-hunt (before) and roofs-fix (after); scripts/verify.ps1 passes (ArtFidelity 95/0).
- Wave 7 scans (2026-10-28): curated search terms for generic UO names (scripts/sourcing-queries.json). New CC-BY scans mapped: green crystal clusters (crystal, tall crystal, broken crystals as small clusters), cave flowstone columns, a stalagmite spire group, cattails and bulrushes, lily pads with a flower (lilypad/lilly pad/water lilly families), a skeleton laid flat for bones/skeleton, a tibia for bone; sunken logs use the mossy log scan. Rejected after preview: a reed row, untextured wheat, a broken-texture sunken log, and two bald cypresses (UO trees are trunk+crown groups drawn whole by the owner tree packs, so a trunk replacement would not render). Coverage: Britain 90.8% of placements, world 95.0% of placements, 52.5% of 10,762 placed graphics (5,107 open). Evidence: preview renders, capture outputs/art-review/cypress; scripts/verify.ps1 passes (ArtFidelity 95/0).
- Wave 8, 65% of placed graphics (2026-10-28): worked by family and graphic count, so one mapping covers every facing, colour and tile of an object. Footprint assembly (Reconstruction._plan_footprints): neighbouring tiles of one multi-tile name form one object, drawn once by its lowest record, centred, scaled to the footprint and turned along its long side (sarcophagi, coffins/caskets, telescope, catapult, fountains, pillory, rope bridge, lighthouse, fireplaces, large gargoyle bed). New CC0/CC-BY scans: weapon rack (also sword displays), paper lantern, coin pile (treasure), ladder, round and heater wall shields, potion flasks, chest, deer trophy, vat, sarcophagus, coffin, telescope, catapult, pillory, fountain, rope bridge, lighthouse; Poly Haven picture frame (paintings), throw pillows, stone fire pit. Wall-hung shields, trophies, paintings and tapestries use the wall-mount planner. Rules: serpent mosaics as stone floors, marble/sandstone arch pieces and gargoyle bases as pillars in their stone, wall carvings as marble walls, ruined-wall rubble (wasteland, broken brick/stone/check) as scanned stone clusters, unnamed dark dungeon masonry (13833/13852/13882/13883), iron gates and wooden rails through the fence builder, wood stacks as firewood. Catalogue corrections: empty tiledata names resolve as the client sees them (rugs 2787-2810 were already drawn), and graphics with no or blank (<3 px) original art count as not drawn. 43 gravestone guesses approved after review; rejected a decimation-broken sarcophagus scan and an untextured spike trap. Coverage: 65.0% of 10,762 placed graphics (3,767 open), world 95.7% / Britain 91.7% of placements. Evidence: preview renders, captures outputs/art-review/wave8; ArtFidelity 96/0 (new footprint check); scripts/verify.ps1 passes. Gaps: one wall shield hangs slightly angled; vines, blood, ships/shipwrecks, teleporters, sinkholes, dirt decals, webs, bodies, banisters and the remaining unnamed records.
- Wave 9 toward 80% (2026-10-28): bulk review of the 96 largest guessed families found almost no matches (bare fruit trees drawn leafy, webs/runes as placeholder stars, pedestal tables with four legs), so none were approved. New: 28 realistic CC-BY weapons and shields from per-name searches (pickaxe, sledge, cleaver, knives, crossbows, swords, maces, axes, spears, pitchfork, kite/heater/buckler/round shields, war hammer, bardiche, halberd) laid flat on the ground by a new "lay" option; one gold-bar scan repainted as gold/silver/iron/copper ingots (PBR "material" override); diamond, cheese wedge, garlic, grapes; existing scans reused for fish, bowls, glass pitchers and the Poly Haven stone fire pit. GroundDecal.gd/.gdshader: photoscanned ground decals with irregular outlines (leaf litter, snow, raked sand, dirt, dirt patches, mud, blood pools, spilled flour, stains) using Poly Haven forest_leaves_02, snow_02, coast_sand_01 (pinned) and existing surface sets; snow and sand fill and join whole tiles. Coverage: 67.4% of 10,762 placed graphics (3,504 open), world 96.0% / Britain 92.6% of placements. Evidence: preview renders, captures outputs/art-review/wave9, wave9b; ArtFidelity 96/0; scripts/verify.ps1 passes. Gaps: hanging beef/sheep carcasses at the butcher (1450,1720) do not render; wall cracks and sinkholes need wall/terrain geometry.
- Wave 10 toward 80% (2026-10-28): armour on display (chainmail hauberk, steel breastplate and close helm, PBR steel repaint), shipwreck and rowboat footprints (wreck bow, mast and sail pieces assemble as one wreck via a footprint "group"), wardrobe/cabinet/spinning wheel with "face": "wall" (furniture turns its back to the adjacent wall), trash piles for refuse/garbage, bamboo, candle wall sconces and levers (wall mounts), drying racks, broken chairs, mine carts, stone altars, shrouded bodies, fishing nets, curtains, folding screens, blossom trees, scrolls, cooking pots, folded linen, sea chests and a wooden crane (20 CC-BY scans; rejected a bottle row and a pedestal pair). Map-placed doors and gates (not wall-flagged) use the photoscanned DoorLeaf in a frame. Virtue shrine mosaics and dark marble inlay are marble floors; stone/marble/sandstone tables and benches are slabs on plinths in a triplanar photoscan (medieval_blocks_02 sandstone, limewash marble, castle wall stone) and never take owner-library timber; footprint-assembly names skip the old prop grouping (Britain fountain square now shows the scanned fountain). Stone coffins and lids join sarcophagus/coffin footprints. Coverage: 72.7% of 10,762 placed graphics (2,937 open), world 96.3% / Britain 94.0% of placements. Evidence: captures outputs/art-review/wave10..wave10e; ArtFidelity 96/0; scripts/verify.ps1 passes.
- Wave 11, 85% of placed graphics (2026-10-28): long-tail mapping by family keywords onto pinned scans, every new mapping checked on side-by-side sheets against the original art (outputs/item-catalog/compare/tail-*, v2-*, rest-*); about 220 mappings that did not match (folded clothes for garments, generic food, recoloured furniture, jars as bottles, vines as hanging ivy) were removed rather than counted. PropReplacements.applies(): name replacements never override architecture/builder kinds, shared by Reconstruction and the catalogue. New builders: EffectBuilder.gd (GPU particles, soft motes, glows and lights for teleporters, moongates, fire and magic fields, sparkles, runes, pentagrams, vortices; Web.gdshader spider webs), VineBuilder.gd (twisting stems in photoscanned bark, scanned ivy sprigs on leafy graphics, turned to the adjacent wall), tree-slice assembly for the newer facets' multi-tile trees, sinkhole/grave decals. Rules: map doors incl. marble/bar/sliding doors, ship decks/holds/gang planks as timber floors, cave/gargoyle stairs, spire masonry, battlements/trims, rails and banisters through FenceBuilder, posts and supports in timber or masonry, window shutters, ponds/waves as water, and 50 unnamed records identified by id (dungeon walls and floors, wall panels, rugs, crystals, obsidian spires, 13 tropical fish recoloured, placeholder UNUSED art hidden). About 40 new CC0/CC-BY scans (weapons sets reused for 30 weapon names, hides, rope coil, crystal ball, leather pants and gloves, anchor, archery target, skep beehive, bust, cactus, plough, ivy, bare gnarled tree for the bare fruit trees, stone lantern, cabbage, pumpkin, watermelon, shovel, globe, wall clock, longbow, ham). Coverage: 85.0% of 10,762 placed graphics (1,612 open), world 98.4% / Britain 96.0% of placements. Evidence: captures outputs/art-review/wave11; ArtFidelity 96/0; scripts/verify.ps1 passes. Wearable graphics on bodies stay with the character pipeline; these mappings only cover items placed in the world.
- Wave 12 (2026-10-28): reed plants, mandible (jaw bones), stone ankhs, iron chains, kelp (seaweed) scans; portcullis as a barred door. 85.2% of 10,762 placed graphics (1,595 open in 825 names, 468 of them single graphics). Remaining work toward 100%: creature statuettes and trophies, Ter Mur/gargoyle furniture and architecture pieces, clothing and jewellery laid out, hedges and grasses (owner-pack guesses that do not match), tools and kitchenware singletons. Evidence: scripts/verify.ps1 passes (ArtFidelity 96/0).
- Britain push (2026-10-28): the catalogue now also reports Britain coverage by distinct graphics (BRITAIN GRAPHICS), alongside the placement-weighted figure. Map statics that the server also places a few copies of are labelled by their static rule; shop/guild sign boards placed by decoration hang as signs; server decoration uses the static builders (effects, decals, vines, fences) and multi-tile server decoration assembles over its footprint (WorldItems._footprint_replacement). New effects (wisp, gas trap, fizzle), blood/dung/hole/patch decals, poles as posts, portraits framed. About 90 new CC-BY scans sourced name by name for Britain (carcasses, bell, notice board, coffee grinder, conch, chess set, parchment, rolling pin, crook, ribs, dartboard, deer skull, frying pan, dress form, dried flowers, easel, jars, chess board, meat hook, juniper, kabuto, horned helm, cavalier/tricorn/wizard hats, key ring, mortar, nautilus, nest, pickpocket dummy, pizza, cookies, raw meat, scrolls, rune stone, ring, roast pig, old key, safe, scales, shackles, sheet music, seashell, boots, skullcap, lever, ship wheel, tools, pliers, toolbox, newspaper, tribal mask, vault door, cheese, whip, saddle, crystals, sulfur, brain, bees, chisel, backgammon); all checked against the art (outputs/item-catalog/compare/bv-*), 36 mismatches removed. Britain: 87.3% of 2,993 placed graphics (381 open), 98.3% of placements; world 87.5% of 10,762 graphics. Evidence: scripts/verify.ps1 passes (ArtFidelity 96/0).
- Britain push 2 (2026-10-28): deeper per-name sourcing for the remaining Britain graphics; ~45 more CC-BY scans pinned and mapped (anatomy arm, leather bag, yarn ball, skeleton arm, wardrobe, worn dresser, grandfather clock case, wooden club, lab glassware, brick forge, apron, bar glasses, clay pots, sledgehammer, cutting board, purple flower, stone pedestal, meat, cauldron, leather pouch, pulley block, scissors, brass telescope, lion stone chair, hay bales, wand, lockpick set, etc.); every mapping rendered beside the original art and 31 that rendered wrong (broken scans, wrong object) were removed again. Britain: 88.9% of 2,993 placed graphics; world 88.0%. Evidence: outputs/item-catalog/compare/bw-*; scripts/verify.ps1 passes (ArtFidelity 96/0).
- Britain push 3 (2026-10-28): CraftedProps.gd builds simple everyday objects from photoscanned timber, rusty iron, hessian, jacquard and ashlar surfaces (rope, cloth bolts, wool, cotton bales, wire coils, gears, springs, hinges, nails, fittings, barrel staves/hoops, broken and unfinished barrels, boards, shafts, axles, curtain rods, water troughs, hide frames, music stands, upright looms, winches, harrows, millstones, flour mills, hourglasses, cannonballs, arrows, peg boards, spools, metal bars); crafted names skip owner-library slots. Poly Haven CC0 bananas, hand saw, hand plane, onions and ginger root pinned. Smithsonian 3D (CC0) was evaluated as a source but its search matched poorly for these names. Britain: 93.1% of 2,993 placed graphics (206 open); world 89.6%. Evidence: outputs/item-catalog/compare/cp-*; scripts/verify.ps1 passes (ArtFidelity 96/0).
- Britain push 4 (2026-10-28): CraftedProps gained laid-out garments in photoscanned cloth (shirts, pants, skirts, cloaks, robes, kimono, aprons, bandanas), jewellery (necklaces, beads, bracelets, earrings, gold belt), glass mug, dice cup, eggs and egg sac, lockpicks, floor spike traps, trapdoor hatches, rope ladders, brushes and coconuts; bone and gore pieces use the pinned bone/meat scans; strongboxes are the iron chest scan in brass. Britain: 94.9% of 2,993 placed graphics (152 open); world 90.3%. Evidence: outputs/item-catalog/compare/gb-*, cj-*; scripts/verify.ps1 passes (ArtFidelity 96/0).
- Britain push 5 (2026-10-28): CraftedProps recipes for wood curls, cocoons, gruesome standards (pole, deer skull, rag), broken shelving, harps, wall cracks, cakes, pillows, herb bundles, bandages, sewing kits, paint palettes, pies, vial racks, armour on a stand (pinned plate and helm scans in steel), dough, horseshoes, tambourines, reagent piles, sextant parts, carrots, dye pots, knitting, bowls of greens, rudders, bolas, feathers and plank signs; CraftedProps._model places pinned scans inside recipes. Scan mappings for spittoons (Poly Haven brass pot), wash basins, muffins, sextant, fish heads/steaks, skinned carcasses, curtain sashes, nox crystal, ringmail armour, ship models, gems, belt pouch, haramaki-do, plate tunic, virtue painting and wall map; placeholder UNUSED graphics hidden. Names with a replacement or crafted look no longer join the legacy multi-tile prop grouping (harps and fountain-modelled props were stuck on old stand-ins). Covered chair rejected (read as an egg). Britain: 97.8% of 2,993 placed graphics (66 open); world 91.2%. Evidence: outputs/item-catalog/compare/cr-*, cr2-*; scripts/verify.ps1 passes (ArtFidelity 96/0).
- Britain push 6 (2026-10-28): the last 66 open Britain graphics. Deeper Objaverse searches (alternative queries per name) pinned 12 CC-BY scans and a CC0 one: eagle sculpture and dragon statuette for the two bird/dragon statues, zombie head, covered dead body, mannequin leg, pigeon (dead and plucked birds, recoloured), practice pig head, balaclava (ninja mask), Pegasus shaffron (horse barding on its head stand), garden urn (Gwenno memorial columns), orc sculpt (orc frame), tentacle plant (corpser frame) and a CC0 horse bit (bridle). Dead trees 3274-3276 draw bare-tree scans through a new id-restricted tree path; clipped hedges use a one-tile foliage section of hedge_scan (scripts/blender-hedge-section.py drops its posts and tags) fitted with a new "size" key; grasses 3259/3261 use the grass-card scan. New CraftedProps recipes: mail leggings, leather/studded/mail sleeves, gorgets, bone armour/gloves/legs, raw cotton, bridle (with the bit scan), ship prow, dart trap, serpent crest, glowing void essence, dust-sheeted chair, iron maiden, century plant, pampas grass, Gwenno headstone with flowers, barding over a sawhorse, leather backpack. Loose worn pieces placed by decoration are labelled by their drawn look. Every look checked beside its original in compare sheets (last66/after66/fix66). Britain: 100.0% of 2,993 placed graphics final (0 open); world 92.1% of 10,762 (849 open). Verify: ArtFidelity 96/0, WORLD ITEM 35/35, 0 errors. Remaining: the world tail (849 graphics, mostly other facets), the gorget and bone pieces are simple shapes, and the century plant/pampas are crafted rather than scanned.
- Modern quickbar and classic macros (2026-10-28): the first build of the owner-approved modern UI (docs/MODERN_UI.md). ActionCatalog lists all 76 actions: every action of the classic macro list (as ClassicUO implements it) plus party chat and two item actions, with every option (all Magery spells with reagents and mana, every other spell school, usable skills, windows, directions, potions and objects). ActionProtocol builds their packets in ClassicUO/ModernUO byte formats. ActionRunner runs slots and macro sequences: it auto-answers target cursors on yourself, your last target or under the mouse, creatures included, and explains missing reagents, mana or items. The Quickbar has two rows of twelve, with Shift, Ctrl and Alt sets swapped while held (48 actions per row), native item art, counts, warnings, drag-and-drop between sets and per-character saving. SlotEditor is the classic macro editor (steps, aim, label, key binding). ModernSkin brings Cinzel and Inter (OFL) and line icons. World hooks: clicking a creature with an open cursor targets it; otherwise it selects it. QuickbarTests 37/0 (packet bytes, full classic list, runner on a recorded session, layers, keys, saving). Rendered check of bar and editor. Live check scripts/test-quickbar.ps1 passes against the local ModernUO: the server confirms the War/Peace round trip; a self-aimed Anatomy slot answers the cursor ("You know yourself quite well enough already."); Night Sight is held back with the missing reagents named; speech, bow and Select Nearest work; a missing item is explained. verify.ps1 passes. Open: the purpose-built skills/spellbook/backpack/gump windows, drag from them onto slots, the client-only actions (health bars, roofs, ranges...), cooldown display, settings page.
- Modern HUD (2026-10-28): the rest of the approved HUD, wired to the live session (docs/MODERN_UI.md). It adds a shared window frame (drag, close, remembered place), the vitals card (replaces the old box), a target frame with notoriety, health and distance, a journal with talk line and chat prefixes, a window menu (C B K P J M) and fading notices for skill and gold changes. Skills window: groups, search, locks sent to the server, Use, session gains, drag to bar. Spellbook: every school, Magery circles, pack reagents, missing reagents named, words of power for all 64, Cast, add or drag to bar. Backpack: item art grid, search and sort, weight, details, Use, Drop, add or drag to bar. QuickbarTests 42/0. Rendered with sample data and checked live in the game scene over streamed Britain with a real character; verify.ps1 passes. Owner requirement recorded: per-kind action timers on slots. Open: paperdoll, other containers, world map, buffs, party, journal speaker names.
- Britain NPCs and creatures (2026-10-28): the new loopback-only PreviewSpawn extension command builds ModernUO's own Trammel spawners inside the streamed Britain bounds: 110 spawners, all kept on a repeat run, which leaves 415 NPCs and creatures (100 vendors) of 114 kinds alive. There are no core or content changes, and the saves were backed up first. The client asks for creature status on sight (MobileNames.gd), so nameplates carry native names; checked live in the town centre. Open: 3D bodies for animals and monsters (non-human bodies are not drawn yet). Details in docs/WORLD_OBJECTS.md.
- Britain to Trinsic (2026-10-29): the first streamed region beyond Britain. scripts/prepare-region.ps1 converts the union of native towns (408 districts, X 1088–2175, Y 1408–2943). The bake accepts up to 512 districts and logs its memory (planning peak 3.65 GB, run peak 5.55 GB, 14 GB disk for modern), and the region minimap is baked. The client takes --region=britain-trinsic. The stress walk Britain to Trinsic and back twice (54 stops) peaked at 1.52 GB GPU and 1.48 GB CPU, retained +2 MB between laps, with p99 26.6 ms. Server: the region limit is raised to 2048 tiles per side; after a backup and a graceful restart, the region now has 6,899 server items (1,683 decorations, 115 doors and 32 signs new) and 231 spawners holding 1,678 NPCs and creatures (164 vendors) of 147 kinds, with repeats creating nothing. Checked live in a Trinsic shop (a named vendor) and in aerial stills of Trinsic. Open: out-of-core bake and shared assets (disk over budget), classic-mode bake of the region, animals and monsters still undrawn. Measurements in docs/WORLD_SCALE_MEMORY_PLAN.md.
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
