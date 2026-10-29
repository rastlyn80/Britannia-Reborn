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
- **Original idea:** any item (in the backpack, a container, the paperdoll, a vendor or trade window, or the world) can be opened in an inspect view, as in modern games. It shows the item's 3D model, lit, with drag to rotate and wheel to zoom, and its server tooltip lines (name, properties) beside it. It uses the same model as the world and the 3D icon renderer.
- **Front end still to do:** deleting characters, profession and skill choice at creation, a server-status probe before sign-in, and remembered looks updating while you play (they are saved on entering and on logging out).
- **Windows still to modernise:** the character sheet (paperdoll), other containers, the world map, buff bar, party frames. Speaker names in the journal need the session to pass them on (0x1C/0xAE carry them; GameSession emits text only).
- **Server gumps:** the modern rendering of server gumps, and the purpose-built crafting, vendor, runebook, bulletin and book windows.
- **Actions that only report "not in this client yet":** these need client features that do not exist yet.
  - Windows: health bars, buff icons, Close Gump and Kill Gump Open, chat visibility, Save Desktop, Minimize and Maximize.
  - Grab, Set Grab Bag, Paste and Razor Macro.
  - Visual toggles: roofs, vegetation, tree stumps and cave tiles, update range, range colour, aura and circle of transparency.
  - Camera: Look At Mouse and Look Forwards/Backwards.
  - Use Counter Bar Slot.
- **Action timers (owner requirement):** each kind of action (skill, spell, potion, bandage) gets a visible timer on its slot and is refused until it expires, then the slot refreshes. The protocol carries no cooldown packet, so durations must come from server feedback (buff 0xDF, "you must wait" messages, ModernUO's delays), not guesses.
- **Settings:** interface scale, bar sets that switch on war mode, crafting or riding, a gamepad wheel and a settings page for rows, slots per row and which modifier sets are enabled. The profile format already stores rows, slots and keys.
