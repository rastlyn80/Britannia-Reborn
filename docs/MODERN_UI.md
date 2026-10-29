# Modern interface: quickbar and classic macro actions

Design reference: the owner-approved mockups on the "Britannia Reborn Modern UI" canvas (HUD, quickbar, skills, spellbook, backpack, server gumps, style sheet). This first build delivers the quickbar, every classic macro action behind it, and the shared modern look. The other windows follow.

## What is built

| Piece | File | What it does |
| --- | --- | --- |
| Look | `Viewer/Network/ModernSkin.gd` | Dark glass panels with brass edges, Cinzel titles and Inter text (`Viewer/Art/Fonts`, SIL OFL 1.1, see NOTICE.md), line icons drawn from SVG paths original to this project, and a theme for modern windows. |
| Classic actions | `Viewer/Network/ActionCatalog.gd` | Every action from the classic client's macro list, as ClassicUO's `MacroManager` implements it, plus every option: all 58 skill names (usable ones offered), 64 Magery spells with reagents and mana, and the Necromancy, Chivalry, Bushido, Ninjitsu, Spellweaving and Mysticism spells, 24 windows, 8 walk directions, potions, "best potion" objects, virtues and selection scans. Two modern additions: Use Item Type (any stack of that graphic/hue, e.g. "a bandage") and Use Item (one exact item). |
| Packets | `Viewer/Network/ActionProtocol.gd` | Byte formats from ClassicUO's `OutgoingPackets` and checked against ModernUO's incoming handlers. 0x12 text commands are used for casting (0x56), opening a spellbook (0x43), opening doors (0x58), bow and salute (0xC7) and virtues (0xF4). The other packets: 0x05 attack, 0x06 use, 0x09 click, 0xAD speech (say, emote, whisper, yell), 0xBF 0x2C bandage, 0xBF 0x06 party chat, 0xBF 0x32 flying, and 0xD7 weapon specials, last weapon, guild and quest menus. |
| Runner | `Viewer/Network/ActionRunner.gd` | Runs a slot's steps in order (with Delay and Wait For Target). It remembers the last skill, spell, object and target. A slot can be aimed "on myself", "on my last target" or "under the mouse"; the runner then answers the server's target cursor itself, creatures included. Before it sends anything it checks whether the slot can work: missing reagents, too little mana, no bandages, or that potion not in the pack. It says why instead of failing silently. |
| Quickbar | `Viewer/Network/Quickbar.gd`, `QuickbarSlot.gd` | Two rows of twelve at the bottom centre. Row one is on keys 1–0, −, =; any slot can be bound to any key. Holding Shift, Ctrl or Alt swaps every row to that modifier's own set, so twelve keys reach 48 actions per row. Shift doubles as run, so the Shift set only shows while you stand still. The layer chips show which set is up; click one to edit that set without holding its key. Slots show native item art for items, a count of what is left, a red frame with the reason when they cannot be used, a lit frame for active toggles (war mode, always run) and a dot for their aim. Click or press to use, right-click to edit, drag to move or swap (across sets too). Saved per account and character in `user://quickbar/`. |
| Slot editor | `Viewer/Network/SlotEditor.gd` | The classic macro editor in the new look. Sets one action or a sequence of steps (add, remove, reorder); kind, action and choice; free text for speech and delays; a picker of carried items with their art; how the slot targets; a label; and its key (press a key; Escape clears; one key, one slot). |
| World hooks | `Viewer/World.gd`, `Viewer/Presentation/WorldItems.gd` | The quickbar and editor are added to the HUD. Paperdoll, Status, Skills and Backpack open the existing windows, and Zoom drives the camera. Clicking a creature while a target cursor is open now targets it, where it used to open its menu. Clicking a creature otherwise selects it, so Attack Selected and Last Target work. |

## HUD and windows (second build)

| Piece | File | What it does |
| --- | --- | --- |
| Window frame | `ModernWindow.gd` | Glass panel with a title bar to drag, a close button and its position remembered (`user://ui/windows.json`); shared chips and meters. |
| Vitals | `VitalsCard.gd` | Top left: name, attributes, gold and weight, hits/stamina/mana with numbers (hits turn green when poisoned). Replaces the old vitals box; click opens the character sheet. |
| Target | `TargetFrame.gd` | Top centre: the selected or last-targeted creature, its name in its notoriety colour, health (the server is asked for its status) and distance. |
| Journal | `Journal.gd` | Bottom left: server text and quickbar notes with tabs; Enter to talk, `/e` `/w` `/y` `/p` for emote, whisper, yell, party, `[` for server commands, Escape to stop typing. |
| Window menu | `MenuBar.gd` | Bottom right: Character C, Backpack B, Skills K, Spellbook P, Journal J, Map M. |
| Notices | `Toasts.gd` | Right side: skill gains and losses, gold changes, fading after five seconds. |
| Skills | `SkillsWindow.gd` | The server's skills by group with search, value against cap, raise/lower/lock sent to the server, Use, gains this session, the total; drag a skill onto the quickbar. |
| Spellbook | `SpellbookWindow.gd` | Every school, Magery by circle, reagents in the pack (missing in red), spell cards naming what is missing, words of power, mana, Cast, Add to quickbar, drag onto the quickbar. |
| Backpack | `BackpackWindow.gd`, `ItemTile.gd` | The pack's items with their own art and counts, search and sort, weight against the limit, details, Use, Drop (asks twice), Add to quickbar, drag onto the quickbar (a slot that uses any item of that kind). The plain item list no longer opens on top of it for the pack. |

Checked live: a login in the real game scene over streamed Britain shows the card, journal, quickbar, menu and each window with the character's real values and pack.

## Evidence

- `Viewer/Network/QuickbarTests.gd` (in `scripts/verify.ps1`), 37 checks:
  - **Packet bytes:** every action packet is checked byte for byte.
  - **The classic list:** all 72 classic action names are present. The spell numbers for every school and the skill numbers are correct.
  - **Runner, against a recorded session:**
    - Bandage Self bandages you without a cursor.
    - Missing reagents and too little mana are reported.
    - A self-aimed spell answers the cursor with you.
    - Select Nearest and Select Next Hostile skip innocents.
    - Attack Last works, and Last Target answers a cursor with a creature.
    - A three-step macro with a delay runs in order.
    - An empty potion slot explains itself.
  - **Quickbar:** 24 slots, with keys 1 to =. Shift, Ctrl and Alt each pick their own set. Slots move between sets, a rebound key frees its old slot, and the layout survives a reload.
- Rendered check of the bar (Base and Ctrl sets) and the slot editor, in the modern look with the fonts.
- `scripts/test-quickbar.ps1` → `Viewer/Network/QuickbarLive.gd` is the live check against the local ModernUO server. It covers:
  - **War/Peace:** a round trip that the server confirms.
  - **Targeting:** a self-aimed Anatomy slot answers the server's cursor.
  - **Spells:** a spell request is either processed by the server or held back with its reason.
  - **Speech:** speech and a bow are sent.
  - **Selection:** Select Nearest.
  - **Missing items:** a missing-item slot explains itself.

  It passed on 2026-10-28; the server's replies confirmed each action. It logs in with the dev account, so run it only while the owner's client is closed.

## Names, captions and trees (2026-10-29)

- **Real names only:** a nameplate never shows a placeholder. It starts empty (or with a name already known from an earlier sighting) and fills in when the server's status reply (0x11) arrives. `MobileNames.gd` repeats an unanswered request every 2.5 s, up to 6 times. Before this, a creature that left view and came back showed "Player <serial>" for good, because its name was already known and never sent again.
- **Sharp captions:** nameplates and building names were `Label3D`s drawn into the 3D scene, so they were resampled and looked soft. `Network/ScreenLabels.gd` keeps them as the source of text, colour and visibility, culls them from the cameras, and draws them as 2D labels in Inter at native pixel size, slightly smaller with distance and hidden beyond 32 m. Engravings on sign boards stay 3D because they belong to the surface.
- **See-through trees:** trees between the camera and the player open a soft, ordered-dither circle around the character, instead of leaves dissolving at the lens. The circle is a cone from the camera to the player's chest, 1.5 m wide at the player, and only covers geometry nearer the camera than the player. Shadows keep the whole tree, because the clearance applies only to the main camera's pass. `Presentation/Foliage.gdshader` plus `FoliageClearance.gd` swap the owner-licensed tree materials as near districts load, so no re-bake is needed; World.gd sets the globals every frame. Checked in a GPU render (tree, a stand-in character behind it, shadow intact). CC0 fallback trees and scanned dead trees still use their old shaders.

## Front end and the end of the right-hand panel (2026-10-29)

The owner approved the plan on the design canvas: a front end with no map district behind it, and the right-hand panel replaced by **Option A**: no dock, with a game menu behind the gear and Esc.

- **Front end (`Network/FrontEnd.gd`, `Presentation/FrontStage.gd`):** the play launchers pass `--front-end`, so `World.gd` prepares the streaming index without loading any district (`LiveDistricts.prepare(scene, true)`). The world's own 3D view is switched off under the front end.
  - **The stage:** a small scene of its own in a SubViewport, built from CC0 Quaternius trees and primitives with nothing from the map. It has a night sky shader with stars and the moon, a castle silhouette with lit windows, a moongate and a brass-trimmed plinth.
  - **Still fallback:** the Compatibility renderer, or `--front-still`, gets a still night gradient instead of the stage.
  - **Sign in:** account and password, remember me (the same Windows-protected store as before), Enter, and a dev-account shortcut when the environment provides one. Settings, Credits and Quit sit in the footer.
  - **Characters:** each name from the server's list, with where it was last seen. The chosen character stands on the plinth, and you can drag to turn it. The list (0xA9) carries names only, so `Network/CharacterLooks.gd` remembers each character's body, skin, worn items and place in `user://characters/<account>.json` (no secrets).
  - **Create:** male or female, skin, hair, hair colour, beard and beard colour (beard rows for male characters only), all as buttons and swatches with a live preview. Only starting cities inside the prepared region are offered, with Britain preselected. Profession and skills stay at the server's defaults for now.
  - **Loading:** the place name and a progress bar of near districts installed at the character's real position. When all are in, the stage and its viewport are freed and the world takes over. Logging out or losing the connection brings the sign-in screen back.
- **Old panel controls, now:**
  - **Game menu (`Network/GameMenu.gd`; Esc or the gear on the menu bar):** Resume, Settings (world look, sky, gamepad), Keys and help (key list plus the server's help request), Developer (console, Return to Britain, world editor), Log out and Quit. Esc used to quit the game outright.
  - **Elsewhere in the HUD:**
    - Peace/War is a switch on the vitals card.
    - Targeting is a prompt above the quickbar with Self and Esc (`Network/TargetPrompt.gd`).
    - Server commands live in a console window on the ` key (`Network/DevConsole.gd`), with history and quick buttons.
    - Connection state is a chip above the minimap (`Network/ConnectionChip.gd`).
    - A blocked move and the first-entry hint show as notices.
  - **Without `--front-end`:** tests and tools keep the original login panel and the preloaded district, unchanged.
- **Nameplates stack:** captions that would overlap are moved above the nearer one.
- **Evidence:**
  - `FrontEndTests.gd` passes 26/26 and is part of verify.
  - **Live run against the local server (2026-10-29):** 0 districts were loaded at sign-in. Choosing the character showed the loading screen, and 9/9 near districts were in about 14 s later. The HUD then appeared without the old panel. The game menu, settings and console worked (`[PreviewWhere` was answered), and logging out returned to the sign-in screen.

## Open

- **3D item icons and inspection (built 2026-10-29):**
  - **The model:** `WorldItems.studio_model` builds an item graphic with the world's own code path and strips physics and labels.
  - **Icons:** `Presentation/ItemStudio.gd` photographs each model once in a three-point-lit studio (192 px), one per frame, cached per session. The backpack grid and detail use the icon; classic art shows only while it renders, or where the world has no model of its own.
  - **Inspect window (`Network/InspectWindow.gd`, "Inspect in 3D" in the backpack):** the lit model turns slowly until dragged; drag rotates and the wheel zooms. Framing fits the narrower view axis. The server tooltip lines sit beside it, and the backpack detail now lists them too.
  - **Live result:** 7 of the 9 item kinds in the test pack draw in 3D (book, gold, dagger, scissors, dice cup, pouches). Bandages and the candle keep classic art until they get models.
- **Phase 1 presentation (built 2026-10-29):**
  - **Health:** the target frame bar turns green when the server flags poison (0x16/0x17) and gold for its yellow "cannot be harmed" bar. The vitals card uses the same flags.
  - **Damage numbers** (`Network/DamageNumbers.gd`): screen text rising from the head and fading, gold on others and red on you, sideways spread for several hits.
  - **Effects** (`Presentation/EffectPresenter.gd`): moving bolts with a glowing core, trail and light, bursting on arrival when they explode. Fixed effects bloom on a creature (following it) or at a spot. Lightning strikes from the sky with a flash. Particles are soft round sprites with a halo. Colour comes from the server hue (the install's hue table), or the art family when the hue is 0: fire, smoke, holy, poison, energy, magic.
  - **Audio** (`scripts/prepare-audio.py`, `Presentation/AudioPlayer.gd`): the owner's install is indexed locally, 1,655 sounds and 57 music tracks (git-ignored), and read straight from the install at run time. Sounds play in 3D at their tile, with 16 voices and a cache. Music crossfades. Volume sliders are in Game menu › Settings.
  - **Live check:** music track 9 started on login, sound 0x1F1 decoded (112 KB), and effects and damage numbers drew over Britain.
- **Context menus and shops (Phase 2, built 2026-10-29):**
  - **Context menu** (`Network/ContextMenu.gd`): the server's menu (0xBF 0x14) opens as a glass card at the cursor, titled with the name and with entries greyed when the server says so. Choosing sends 0xBF 0x15. (An earlier note that the server never answered context requests was wrong: the census never measured them, and the shard answers every one.)
  - **Vendor window** (`Network/VendorWindow.gd`):
    - Buy and Sell tabs. A tab asks the vendor itself when its list has not come yet.
    - Item cards with 3D icons, prices and counts. Sell offers of one kind are grouped.
    - An order with − and + controls, the total against your gold, and one Buy (0x3B with every line) or Sell (0x9F) for the whole order.
    - The old shop panel no longer answers in the modern HUD.
  - **Live check:** 35 stock lines and 12 sell offers (3 cards). Bread bought (903 → 897 gold). Two dice cups sold from one card (897 → 899).
- **Action timers and buff bar (owner requirement, built 2026-10-29):**
  - **Timer model** (`Network/Cooldowns.gd`): every kind waits as ModernUO enforces it, with durations from its pinned source.
    - One shared skill timer: lore skills 1 s; Hiding, Stealth, Tracking, Poisoning, Remove Trap and Meditation 10 s; Spirit Speak 5 s; Discordance 12 s; Detect Hidden, Taming, Begging and Stealing 30 s.
    - Spells: the circle's cast delay plus 1.5 s recovery.
    - Bandages: by dexterity, self or other.
    - Heal potions: 3, 8 or 10 s.
    - The server's "you must wait" messages (500118, 500119, 502644, 500235) restart a timer that ran out early.
  - **On the quickbar:** an action whose kind is waiting is refused with "Skills ready in N s". Every slot of that kind shows a dark clockwise sweep with the seconds left, and flashes when ready.
  - **Buff bar** (`Network/BuffBar.gd`, under the vitals card): one chip per buff from 0xDF, with an icon chosen by name, a ring that empties as time runs out, and the seconds left. Hover shows the server's title and description; debuffs have a red edge.
  - **Evidence:** QuickbarTests 49/0, with 6 new timer checks. Live: using Hiding started the 10 s skill timer on the Hiding and Meditation slots, a second skill was refused, and the server confirmed ("You fail to hide"). No real buff arrived in that session, so the buff bar was shown with one sample Bless packet.
- **Container windows (Phase 2, built 2026-10-29):** every container the server opens other than the backpack gets its own window (`Network/ContainerWindow.gd`): corpses, chests, bags in the pack, the bank box.
  - **In the window:** 3D icons with server tooltips; double-click uses an item (nested bags open their own window).
  - **Moving items:** drag items between containers and the backpack, dropping on a tile or on the window. Take all moves everything to the pack one item at a time.
  - **Closing:** the window closes when the container is gone or more than 3 tiles away.
  - **The old item browser** now only shows books and bulletin boards.
  - **Live check:** bread was moved into a bag and back with Take all.
- **Paperdoll (Phase 2, built 2026-10-29):** C and the menu bar open `Network/PaperdollWindow.gd`.
  - **Layout:** the character's real 3D model with its worn equipment, lit and slowly turning (drag to turn), with 16 equipment slots showing 3D icons and tooltips.
  - **Your own paperdoll:** the server title (from 0x88), attributes and resistances. Drag backpack items onto it to wear them, drag worn items back to the backpack, and double-click to use.
  - **Other characters:** their paperdoll opens when the server sends theirs (Open Paperdoll in the context menu, or double-click). ModernUO honours the paperdoll bit only for yourself, so others are asked with a plain double-click.
  - **Live check:** the weapon was moved to the pack, the dagger worn and removed, and another player's paperdoll opened.
  - **Attributes sheet:** the full sheet stays on the vitals card.
- **Spellbook contents and death (Phase 2, built 2026-10-29):**
  - **Spellbook contents:** opening the spellbook window asks the server for the school's book (0x12 0x43). Its contents (0xBF 0x1B) grey out spells the book lacks ("Not in your spellbook"). With no book in the pack, the window says so. The book opens as a server container, so it never gets a container window.
  - **Death screen** (`Network/DeathScreen.gd`): death (0x2C) or a ghost body darkens the screen with "You have died", then settles into a light grey veil with a reminder while you walk as a ghost. Resurrection lifts it.
  - **Limits:**
    - The test character owns no spellbook, so the contents path is covered only by the protocol fixture.
    - Dying was not attempted live: the death screen was shown with a sample death packet.
- **Phase 3, every server window (built 2026-10-29):**
  - **Gumps** (`GumpView.gd`): every command ModernUO's GumpLayoutBuilder writes, plus ClassicUO's extras.
    - **Panels and text:** background frames become glass panels and alpha regions dark glass. Text uses Inter, with dark parchment hues lifted for readability. Inputs use the HUD theme.
    - **Buttons:** the classic buttons ModernUO uses most become modern buttons: Okay, Cancel, gem arrows, close, check and dots, all taken from a frequency count over UOContent. Rarer art is kept.
    - **Items, tooltips and placement:** items show their 3D icon, and tooltips and item properties attach to the element they describe. Windows the server places in the top-left are centred above the HUD, and Esc closes the top one.
    - **Live check:** the help menu rendered fully modern.
  - **Dialogs** (`ServerDialogs.gd`): item and question menus (with 3D icons), text prompts, a hue palette from the install's hues, web links that open only after confirmation, tips with Next, and sign text. Each is a centred card, and Esc cancels. The hue picker was shown with a sample packet.
  - **Crafting** (`CraftWindow.gd`): ModernUO's craft gump is read by its button scheme (1 + type + index×7).
    - **Layout:** categories and Last ten on the left; item cards with 3D icons (graphic from the item's 1020000+id name) and a details button; Make last, material, smelt, repair, enhance and maker's mark along the bottom, with the server's notice.
    - **Behaviour:** every click answers the server's gump, which sends the next state. CraftTests 8/0 use a fixture built as CraftGump.cs builds it.
    - **Not checked live:** the test character has no crafting tool, and the preview tools cannot give one.
  - **Bank and runebook:** the bank box opens in the container window. The runebook uses the modern-styled generic gump for now.
- **Phase 4, commerce and social (built 2026-10-29):**
  - **Party frames** (`Network/PartyFrames.gd`, under the vitals card): one card per member with name and health. Invite asks the server (0xBF 0x06 1), which opens its own target cursor. An invitation shows Accept and Decline. Leave and a loot-rights switch sit below the cards. Member locations are asked for every 3 s (0xF0). The minimap shows members out of view and the quest target.
  - **Trade** (`Network/TradeWindow.gd`): your offer and theirs as 3D-icon grids, each with its accept state, gold to offer, Accept and Cancel. Backpack items dropped on the window go onto your side.
  - **Books** (`Network/BookWindow.gd`): two facing parchment pages with page turns, title and author. Writable books are edited in place and saved (0xD4 header, 0x66 pages).
  - **Bulletin boards** (`Network/BoardWindow.gd`): messages newest first with author and date, the chosen message's text, Reply, Remove and a form for new posts.
  - **Quest arrow** (`Network/QuestArrow.gd`): a gold diamond with the distance over a target in view, or an arrow on the edge of the open view (clear of the quickbar) pointing the way. Left-click acknowledges, right-click cancels.
  - **Journal tabs:** All, Server, Party, Chat and Quickbar. Party messages and chat channel lines are routed in.
  - **Live check (two local accounts):**
    - The dev character invited a second, auto-created account through the server's cursor; the invitation arrived and was accepted, and both party lists showed both members.
    - A party message was heard by the other member.
    - A dice cup was dropped on the other character, both accepted, and it arrived in their backpack.
    - A writable book in the pack was retitled and written, and read back from the server.
    - Screenshots of the party card, trade window, book, board and arrow were checked.
  - **Limits:**
    - Member locations came back empty because both characters stood together (the server only reports members out of view).
    - The board and the arrow were shown with sample data: no board or quest is near the test character.
    - Chat channels (0xB2) and guild gumps go through the journal and the modern gump renderer; there is no dedicated chat window yet.
- **Phase 5, world systems (built 2026-10-29):**
  - **Houses and boats (multis):** the session keeps multis (0xF3 type 2, legacy 0x1A from 0x4000) instead of dropping them. `Presentation/MultiPresenter.gd` draws them.
    - **Component data:** `scripts/prepare-multis.py` indexes the install's MultiCollection.uop, tiledata and house-designer catalogues (local, git-ignored).
    - **Houses:** built tile by tile with the city's own reconstruction rules, so a classic house looks like Britain's.
    - **Custom houses:** their server design (0xD8, asked for when 0xBF 0x1D announces a newer revision).
    - **Full models:** `Presentation/multi-models.json` maps a multi ID to one fitted model (the owner's idea: classic houses and boats can be single full models). It is empty until models are sourced and approved through the usual pipeline.
    - **Walking:** the components feed local movement, so floors, decks and stairs carry the player.
  - **Ships** (`Presentation/ShipBuilder.gd`): every classic boat (small, medium, large, plain and dragon) is drawn whole: a lofted plank hull, deck, rails, mast, yard, square sail, rigging, a bowsprit or dragon prow, and a rudder, sized from the footprint and turned to its facing. Boats glide to each 0xF6 position, and their passengers move with them.
  - **Placement** (`Presentation/PlacementGhost.gd`): a 0x99 multi target shows a translucent copy of the house or ship following the mouse. Left-click places it and Esc cancels. On water it aims at the water tile itself, which boats need.
  - **Speech keywords** (`Network/SpeechKeywords.gd`, `scripts/prepare-speech.py`): spoken lines are sent with their speech.mul keyword IDs (0xAD encoded), byte-for-byte as ClassicUO. ModernUO recognises "bank", "vendor buy", guards and boat orders this way; before this they went unanswered.
  - **Helm** (`Network/HelmPanel.gd`): opens when you board and closes when you leave. It is a movable window like the others. Arrows sail in eight directions, with turn, come about, stop, anchor and slow; each control speaks the tillerman's order.
  - **Maps:**
    - **World map** (M, `Network/WorldMapWindow.gd`): the whole Trammel radar map from `scripts/prepare-world-map.py` (one pixel per tile, local). It shows you, your party, the quest target, houses and boats; follow, zoom and pan, and right-click to walk there.
    - **Server maps** (`Network/ServerMapWindow.gd`): treasure and cartography maps are drawn as old charts on parchment, with numbered pins and the course between them. Treasure pins are red, as the server's message says. "Plot course" edits pins (0x56).
  - **Walking to a tile** (`Presentation/AutoWalk.gd`): A* over the client's own step prediction, followed one normal step at a time and replanned when a step is refused. It is used for the server's pathfind order (0x38) and the world map.
  - **House designer** (`Network/HouseDesigner.gd`): opens when customising starts (0xBF 0x20).
    - **Palette:** floors 1-4, Build or Erase, the install's catalogues (walls, doors, floors, stairs, roofs, misc, teleporters), styles, and pieces photographed in 3D by the icon studio with the house's own rules.
    - **Editing:** the outlined cell under the mouse builds (left-click) or erases (right-click). Each edit is followed by Sync, so the design shown is always the server's.
    - **Commands:** backup, restore, revert, clear, commit and close.
  - **Test kit** (owner-approved exception, `Server/PreviewTools/PreviewKit.cs`, loopback and previewTools only): `[PreviewKit house|boat|map|site [multi]|dock` hands out ordinary upstream deeds, a placement tool with bank gold and a treasure map, or moves the caller beside the nearest spot the server's own rules accept.
  - **Live checks:**
    - **House:** a small brick house was previewed, placed by the server (144 tiles, none unmapped) and drawn with walls, door, sign and roof.
    - **Boat:** a small boat was placed on the canal and unlocked with its key. The character boarded and gave orders ("raise anchor", "forward", "back", "stop"), and the tillerman answered. The boat sailed 11 to 12 steps with the character aboard, also from the helm.
    - **Treasure map:** decoded after a few tries, then opened over the right area with its pin.
    - **World map:** shown at street and continent scale.
    - **Walking:** an A* walk of 117 steps across Britain to the boat.
    - **Custom house:** on a second account, a 7x7 foundation was placed through the placement tool's gumps (30,500 gold), then the sign's Customize button was used. The designer opened with 182 wall styles; five walls were built (revisions 1-5, each confirmed by the server) and committed (2,500 gold).
  - **Limits:**
    - **Mounts:** need the horse and creature bodies (art track) and the deferred rider clips in the human character work, so riders still stand. Dismounting works through the server's context menu.
    - **Full models:** none are registered for houses or ships yet. Houses use tile building and ships the procedural builder.
    - **Roof and floor previews:** roof pieces in the designer use the default height, and there is no floor-height preview of the piece itself, only the outlined cell.
    - **Leftovers:** the dev character's brick house and two test boats, and the second account's custom house, remain on the local shard.
- **Phase 6, robustness and breadth (built 2026-10-29):**
  - **Malformed-packet fuzzing** (`Network/FuzzTests.gd`, in verify): every packet type ModernUO sends and every 0xBF subcommand get random contents at their real framing, against a fresh session and one that already knows the serials involved. Random gump layouts are built from the real command words and opened as windows. Godot's Logger counts any script error, and any engine error raised from a script. 12,040 packets with no failures.
    - **`--scene` pass:** the same fuzz against the full client with every window and presenter connected: 3,980 packets, clean.
    - **Bugs it found and fixed:** a short character list (0xA9); maps with reversed corners; garbage compressed gumps (0xDD) and house designs (0xD8), now checked for a zlib header and size before use; a prompt focusing after it closed.
  - **Logout and reconnect:**
    - Log out asks the server (0xD1) and closes on its acknowledgement.
    - "Change character" in the game menu signs straight back in to the roster.
    - A dropped connection offers "Reconnect as <name>", which re-enters the same character.
  - **Characters:** the roster can delete a character after a confirmation naming it (0x83). The server's answer shows on the roster: the reason (0x85) or the shorter list (0x86).
  - **Server popups:** 0x53 codes and 0x82 login rejections now say why, in ClassicUO's wording. The idle warning (0x53 code 7) no longer disconnects you; before, the client cut itself off when the server only warned.
  - **Facets:** `scripts/prepare-world-map.py` now renders every facet (Felucca, Trammel, Ilshenar, Malas, Tokuno, Ter Mur).
    - **World map:** follows your facet and can show any other.
    - **Server maps:** use the facet given in 0xF5.
    - **Elsewhere:** away from Trammel, a banner says where you are and points to the map. Building other facets in 3D is world-pipeline work.
  - **Race change** (0xBF 0x2A): a card offers exactly the skin tones, hair (or horns), hair colours and beards ModernUO's race rules accept for the new race and your sex. Not now declines; the server's withdrawal closes it.
  - **Already complete:**
    - Gargoyle flying (quickbar action, 0xBF 0x32).
    - Map patches (0xBF 0x18, kept for diagnostics; the converted world does not use them).
    - All seven spellbook types of the pinned ModernUO, which has no Book of Masteries; their graphics match.
  - **Live:**
    - **Long census** (`scripts/test-protocol-census.ps1 -Long`): minutes of mixed play (walking, vendor speech, skill, spellbook, help, a decoded treasure map, 45 s idle with pings), then a logout the server acknowledged, then a reconnect into the same character. 42 packet types, 0 unhandled, every request answered.
    - **Front end:** enter, Change character (logout acknowledged, roster shown), a simulated lost connection, Reconnect back into the world, and Log out to sign-in.
    - **Deletion:** deleting a new throwaway character was refused by the server ("not old enough to delete"), and the list was resent.
  - **Limits:**
    - Bank speech needs a banker within earshot; the census start point has none.
    - Riding and other creature bodies are in progress in the other session's horse work.
    - The other facets have maps, but no 3D world yet.
- **Movable panels and 3D quickbar icons (2026-10-29, owner request):**
  - Every window that opens on screen can be dragged and is remembered where it was left. Besides the modern windows, this now covers the game menu (settings), the server dialog cards (menus, prompts, dye picker, race change), the macro slot editor, the target prompt, server gumps (per gump type) and the character sheet. The HUD stays fixed.
  - `Network/Movable.gd` drags a panel by any empty part of it, keeps it on screen and stores its place with the windows' places. MovableTests 5/0, in verify. Live: a dialog card dragged with real mouse input moved by (-360, 270) and reopened there.
  - Quickbar item and potion slots show the item's 3D icon, the same as the backpack, with classic art only while it renders. Live: the Heal and Refresh potion slots show their 3D models; Cure has no model yet.
- **Original idea:** any item (in the backpack, a container, the paperdoll, a vendor or trade window, or the world) can be opened in an inspect view, as in modern games. It shows the item's 3D model, lit, with drag to rotate and wheel to zoom, and its server tooltip lines (name, properties) beside it. It uses the same model as the world and the 3D icon renderer.
- **Front end still to do:** deleting characters, profession and skill choice at creation, a server-status probe before sign-in, and remembered looks updating while you play (they are saved on entering and on logging out).
- **Windows still to modernise:** a chat-channel window. Speaker names in the journal need the session to pass them on (0x1C/0xAE carry them; GameSession emits text only).
- **Server gumps:** the modern rendering of server gumps, and the purpose-built crafting, vendor, runebook, bulletin and book windows.
- **Actions that only report "not in this client yet":** these need client features that do not exist yet.
  - Windows: health bars, buff icons, Close Gump and Kill Gump Open, chat visibility, Save Desktop, Minimize and Maximize.
  - Grab, Set Grab Bag, Paste and Razor Macro.
  - Visual toggles: roofs, vegetation, tree stumps and cave tiles, update range, range colour, aura and circle of transparency.
  - Camera: Look At Mouse and Look Forwards/Backwards.
  - Use Counter Bar Slot.
- **Action timers (owner requirement):** each kind of action (skill, spell, potion, bandage) gets a visible timer on its slot and is refused until it expires, then the slot refreshes. The protocol carries no cooldown packet, so durations must come from server feedback (buff 0xDF, "you must wait" messages, ModernUO's delays), not guesses.
- **Settings:** interface scale, bar sets that switch on war mode, crafting or riding, a gamepad wheel and a settings page for rows, slots per row and which modifier sets are enabled. The profile format already stores rows, slots and keys.
