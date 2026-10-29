# Second blueprint: the full client–server protocol

The first blueprint (MASTER_PLAN.md) set the direction: ModernUO is the authority and our client presents it in 3D. This second blueprint is the order in which our client learns **everything ModernUO sends and accepts**, so that every gameplay system the server already runs works in Britannia Reborn.

**Reference implementation:** ClassicUO (`work/reference/ClassicUO`, BSD-2-Clause). For every packet we port its parser (`Network/PacketHandlers.cs`), its sender (`Network/OutgoingPackets.cs`), its state manager (`Game/Managers/*`) and its UI flow (`Game/UI/Gumps/*`). ClassicUO already does all of this in 2D. Ported code keeps the BSD notice, as the Huffman decoder already does. ModernUO (`Server/ModernUO`, pinned) is the ground truth for formats and for which packets this shard actually uses; its source stays unmodified.

## Where we stand (measured 2026-10-29)

**Shard and client:**
- **Shard:** ModernUO at expansion **Endless Journey** (id 11), Trammel only, MobileStatusVersion 6, context menus and AOS/SE/ML character-list flags on.
- **Owner's client:** the local install is `client.exe` 7.0.102.3. We announce 7.0.104.0; the two should match (Phase 0).

**Census (live, 50 s in Britain):** walking, backpack, status, war mode and context-menu requests. 30 packet types arrived; 9 of them we drop:

| Packet | Count | What it is | Handled? |
|---|---|---|---|
| 0xDC | 1,580 | Tooltip revision per object (OPL) | **no**: no tooltips |
| 0xF3 | 1,455 | World item/multi (SA format) | yes |
| 0x17 | 192 | Health bar flags (poison, mortal, yellow bar) | **no** |
| 0x78 | 111 | Mobile appears | yes |
| 0x20, 0x22, 0x77 | 17/15/14 | Player update, walk confirm, mobile moves | yes |
| 0xBF | 10 | Extended (context menu, facet, stat locks…) | partly |
| 0x11 | 8 | Status | yes |
| 0x4E, 0x4F, 0x65 | 6/6/4 | Personal light, world light, weather | yes |
| 0x5B, 0x6D, 0xB9, 0xBC | 1/1/3/2 | Time, music, feature flags, season | **no** |
| 0x73 | 3 | Ping reply | ignored (fine) |

**Coverage:**
- **Server to client:** ModernUO can send about 90 packet types. Our `GameSession` handles 37, and 0xBF partly (subcommands 0x04, 0x08, 0x14 and stat locks).
- **Client to server:** ModernUO accepts 71 main packets, 23 extended (0xBF) and 16 encoded (0xD7). We send about 30: login, walk, speech, use, click, lift/drop/equip, target, gump reply, buy, context, skills, war, help, quickbar actions, bandage, abilities, guild and quest.

**Known gaps beyond packets:**
- **Clilocs:** only a local subset (`cliloc.local.json`). Many server messages are cliloc numbers, so we need the full `Cliloc.enu` from the owner's install, read at run time and never committed.
- **Audio:** none yet; sounds and music come from the install (local only).
- **Monster and animal bodies:** not drawn, which limits combat feedback even once the packets work.

## Status: protocol layer complete (2026-10-29)

Phase 0 is done, and the protocol layer of every later phase is in place: our client now parses everything ModernUO sends and can build everything it accepts. What remains in each phase is presentation: windows, visuals and audio that use this state. Per the owner's rule, these must look good and draw items with our 3D models everywhere.

- **Dispatch:**
  - `GameSession.route`/`route_extended` feed 14 modules in `Network/Packets/`: Tooltips, Mobiles, Messages, Environment, Effects, Combat, Connection, Items, Player, Buffs, Dialogs, Social, WorldSystems and Requests.
  - The original 42 handlers stay in `GameSession` (`OWN_PACKETS`).
  - Anything else is counted in `unhandled` for the census.
- **Server to client:**
  - All 99 game-connection packet types ModernUO sends have a handler, and so do all 16 extended subcommands. The login-connection packets are handled by LoginProtocol.
  - That includes tooltips (0xDC/0xD6, queried in batches of 12 every 120 ms), health flags, names, attributes, affixed clilocs, time, season, features, view range, sound, music, all graphic effects, damage, swings, attack target and buffs with timers.
  - It also covers death, paperdoll and profile, character-list changes, menus, hue picker, prompts, URLs, tips, signs and help.
  - And the social and world systems: party, trade, sell lists, chat, arrows, member locations, maps, multi placement, custom houses (planes decompressed and decoded), boats, spellbook contents, corpse equipment and packed item lists.
- **Client to server:** every packet ModernUO accepts has a builder, except ones deliberately not sent (enhanced or assistant clients, crash and hardware reports, the store, new movement), each with its reason in `Requests.gd`. That covers all 23 accepted extended subcommands and the house-designer encoded commands.
- **Client version:** announced as the install's 7.0.102.3. After login the client sends its view range, as ClassicUO does.
- **Evidence:**
  - `ProtocolTests.gd` (verify): 42/0. It covers coverage, builders, ModernUO fixed lengths and fixtures for every new parser family.
  - `scripts/test-protocol-census.ps1` (live): 35 packet types received, **0 unhandled**. Tooltips: 148 lists received, one per object; before the fix it was 970 replies.
  - Requests answered live: paperdoll 0x88, profile 0xB8, name 0x98, and spell cast 0xBF 0x1C (3 replies). The tip request (0xA7) gets no reply on this shard.

### Presentation progress

- **Phase 1** is built: tooltips, health flags, damage numbers, effects, sound and music.
- **Phase 2** is built: context menus, shops, action timers, buff bar, containers, paperdoll, spellbook contents and the death screen.
- **Phase 3** is built: modern gumps for every command, server dialogs and the crafting window.
- **Phase 4** is built: party frames, secure trade, books, bulletin boards, the quest arrow and journal tabs. Two local accounts partied up, chatted and traded live, and a book was written and read back.

- **Phase 5** is built: houses and boats drawn from their components (custom houses from their designs), placement previews, ships, speech keywords, the helm, world and treasure maps, walking to a tile, and the house designer. A house was placed and customised, a boat sailed and a treasure map was read, live. Mounts wait for creature bodies.

See MODERN_UI.md for details and live evidence. Next: Phase 6 (robustness and breadth).

## Ground rules for every phase

1. **One handler module per system:** `Network/Packets/<System>.gd`, registered in a dispatch table. This replaces new `match` arms in `GameSession.gd`, which is shared with another session and already 1,000 lines. GameSession keeps only framing and session state.
2. **Port, then test:**
   - The parser follows ClassicUO's field order exactly.
   - Each packet gets a fixture test (bytes → state) and a builder test (action → bytes), both in verify.
3. **Live proof per phase:** a `scripts/test-<system>.ps1` check against the local shard, run only while the owner's client is closed.
4. **Census as the scoreboard:** `scripts/test-protocol-census.ps1` (promoted from today's scratch census) plays a scripted route and fails on any packet that is neither handled nor on an explicit "deliberately ignored" list. Coverage is reported in PROGRESS.md each phase.
5. **UI comes last within a phase:** state first (managers), then the modern window in the HUD style (MODERN_UI.md). The server's own gump is always the fallback.

## Implementation order

The order follows three rules: what arrives most often in real play first, then what blocks other systems, then breadth. Each phase ends playable.

### Phase 0: protocol foundation (prerequisite)

**Goal:** a clean place for every later packet, and a client that identifies itself correctly.
- Dispatch table and handler modules; move the existing 37 handlers out of `GameSession.gd` with no behaviour change, in agreement with the other session.
- Client version: send the install's version (0xBD); honour 0xB9 feature flags; complete the packet-length table against ModernUO's.
- Packet logger (opt-in, local) and the census script with the "ignored" list.
- **Full cliloc reader:** `Cliloc.enu` from the install, with argument substitution (`~1_NAME~`, `#1234`). ClassicUO reference: `Resources/ClilocLoader.cs`.
- **Done when:** census runs in verify-live, the version matches the install, and all existing tests pass unchanged.

### Phase 1: see the world truthfully (the bulk of real traffic)

**Goal:** everything the server says about the world is visible.
- **Tooltips and names:** 0xDC, 0xD6 (batch query out: 0xD6 / 0xBF 0x10), 0x98 and 0x34. This gives tooltips on hover in the backpack, paperdoll and world, and real item names everywhere. ClassicUO: `ObjectPropertiesListManager`.
- **Health:** 0x16/0x17 (poison and other bar flags), 0x2D, 0xA1–0xA3 (done) and 0x11 (done). This gives health bars over mobiles, poison colour and the target frame. ClassicUO: `HealthLinesManager`, `HealthBarGump`.
- **Messages:** 0x1C and 0xAE (done; add overhead bubbles), 0xC1 (done), 0xCC (affixed cliloc). These appear as speech over heads, system messages and journal channels. ClassicUO: `MessageManager`, `WorldTextManager`.
- **Environment:** 0x5B time, 0xBC season, 0x65 weather (done) and 0x4E/0x4F light (done). The sky and season follow the server.
- **Effects:**
  - 0x70, 0xC0 and 0xC7 (moving, fixed and particle effects) draw spell and skill visuals. ClassicUO: `EffectManager`.
  - 0x54 sound and 0x6D music play audio from the install. ClassicUO: `AudioManager`.
- **Combat feedback:** 0x0B damage numbers, 0x2F swing, 0xAA attack target, 0xBF 0x22 damage and 0x6E/0xE2 animations (done).
- **Done when:** census shows 0xDC, 0x17, 0x5B, 0x6D, 0xB9 and 0xBC handled; hovering any item shows its server tooltip; poisoned mobiles show green bars; casting a spell shows its effect and sound.

### Phase 2: act on the world (core interactions)

**Goal:** every basic verb works, with the server's answer shown.
- **Items:**
  - Packets: lift 0x07, drop 0x08 and equip 0x13 (done), with acks 0x27/0x28/0x29 and drag animation 0x23.
  - Containers by gump type: backpack, bank, corpse and chests (0x24 and 0x3C done). Plus 0x89 corpse equipment.
  - **UI:** proper loot windows and split-stack amounts. ClassicUO: `ContainerManager`, `GridLootGump`, `SplitMenuGump`.
- **Context menus:** 0xBF 0x13/0x14/0x15. Today's census sent requests and got no replies, so fix the request first. This unlocks pets, vendors, banking and training. ClassicUO: `PopupMenuGump`.
- **Paperdoll and profile:** 0x88, 0xB8 and 0x2E (done), giving the modern paperdoll window. ClassicUO: `PaperdollGump`, `ProfileGump`.
- **Spells and skills done right:** 0xBF 0x1C cast spell (ClassicUO's preferred path), targeted spell and skill (0xBF 0x2D/0x2E), spellbook contents 0xBF 0x1B, and 0x12 (done).
- **Combat abilities:** 0xD7 0x19 (done) plus 0xBF 0x21 clear-ability.
- **Buffs and debuffs:** 0xDF. This is the buff bar, and it is also the **source for the quickbar action timers** (owner requirement), together with the server's "you must wait" messages. ClassicUO: `BuffGump`.
- **Death and resurrection:** 0x2C and 0xAF, with the 0x2C response. Ghost state, the death screen and the resurrection gump flow.
- **Movement robustness:** 0x97 move player, 0x22 resync (done), 0xC8 view range, and denial and recovery.
- **Done when:** a live script loots a corpse, uses a pet or vendor context menu, casts with a target, dies and is resurrected; the buff bar and slot timers match server durations.

### Phase 3: every dialog the server can open

**Goal:** no server window is ever invisible or inert.
- **Generic gumps 0xB0/0xDD:** complete all control types: pages, radios, text entries, tiled backgrounds, item art, html and cliloc html. Plus close (0xBF 0x04, done) and reply 0xB1 (done). ModernUO runs crafting, banking, help, house, pet, quest and staff UIs as gumps, so this one item unlocks dozens of systems.
- **Legacy menus and prompts:**
  - Menus 0x7C/0x7D.
  - Text entry 0xAB/0xAC.
  - Prompts 0x9A/0xC2 (rename, house sign, guild name).
  - Hue picker 0x95.
  - Tips 0xA6/0xA7.
  - Open URL 0xA5 (with confirmation).
- **Modern purpose-built windows** for the most used server gumps, keeping the gump as fallback: crafting (all trades), runebook, bank, trade. These follow the HUD style.
- **Done when:** a live script walks through crafting an item, recalling via runebook, renaming a pet by prompt and dyeing with the hue picker.

### Phase 4: commerce and social

- **Vendors:** buy 0x74/0x3B (done), sell 0x9E/0x9F, close 0x3B.
- **Secure trade:** 0x6F (window, accept/cancel, gold and platinum).
- **Party:** 0xBF 0x06 (invite, accept, chat, loot rights), member locations 0xBF 0x00 on the minimap, and party frames.
- **Guild and quests:** 0xD7 0x28 / 0xD7 0x32 (done as requests) plus their gumps; quest arrow 0xBA.
- **Chat:** 0xB2/0xB3/0xB5 (channels, private messages, ignore).
- **Books and boards:** 0x66, 0x93 and 0xD4 (read and write), bulletin boards 0x71 (done for reading; add posting).
- **Rename and logout:** rename 0x75; logout 0xD1/0x01 (clean exit).
- **Done when:** two local accounts trade, party up, chat and write in a book.

### Phase 5: world systems

- **Maps:** 0x56, 0x90 and 0xF5 (treasure and cartography maps with pins).
- **Houses:**
  - Placement: 0x99 multi target (preview the house footprint).
  - Customisation: 0xD8 custom house, 0xBF 0x1D revision, and 0xD7 designer commands 0x02–0x1A.
  - House signs and gumps (Phase 3).
- **Boats:** 0xF6 boat movement and smooth multi motion.
- **Mounts:** layer 25 and rider animations (the human motion set has rider clips as previews); dismount and stabling through context menus.
- **Tracking and pathfinding:** 0xBA arrows and 0x38.
- **Done when:** a house is placed and customised, a boat sails, and a treasure map is read.

### Phase 6: robustness and breadth

- Logout and reconnect, ping, idle and anti-macro gumps, throttling responses, 0x86 character-list updates, 0x83 delete character (front end) and 0xBF 0x18 map patches.
- **Other facets:** Felucca, Ilshenar, Malas, Tokuno and Ter Mur. The protocol already carries the facet (0xBF 0x08, done); this needs converted data per facet (world pipeline work, not protocol).
- **SA/HS/TOL specifics:** gargoyle flying 0xBF 0x32 (sender done), race change 0xBF 0x2A, and the new spellbook types.
- **Done when:** the census has zero unhandled packets over a long mixed session, and malformed-packet fuzz tests pass.

## Cross-cutting tracks (alongside the phases)

- **Art for what the protocol reveals:** monster, animal and mount bodies (0x78 bodies we cannot draw yet), item art where tooltips now name items, and effect visuals. This follows the asset pipeline and "Complete all items".
- **Action timers:** designed in Phase 2 from 0xDF and server messages. Slots grey out and count down per kind.
- **Settings:** each new system adds its options to the game menu.

## Suggested first sprint

1. **Phase 0:** the dispatch table and module move (coordinated), the version match, the census script and the cliloc reader.
2. **Phase 1:** tooltips (0xDC/0xD6) and health bars (0x16/0x17). These are the two most frequent dropped packets, and both are visible on day one.

Each later sprint takes the next items in order and closes with census numbers and a live script in PROGRESS.md.
