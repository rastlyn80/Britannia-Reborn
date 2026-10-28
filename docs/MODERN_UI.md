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

## Open

- **Purpose-built windows:** skills, spellbook, backpack, character and journal as on the canvas. Dragging a skill, spell or backpack item onto a slot needs those windows to offer drag data. Until then the slot editor's pickers do this job.
- **Server gumps:** the modern rendering of server gumps, and the purpose-built crafting, vendor, runebook, bulletin and book windows.
- **Actions that only report "not in this client yet":** these need client features that do not exist yet.
  - Windows: health bars, buff icons, Close Gump and Kill Gump Open, chat visibility, Save Desktop, Minimize and Maximize.
  - Grab, Set Grab Bag, Paste and Razor Macro.
  - Visual toggles: roofs, vegetation, tree stumps and cave tiles, update range, range colour, aura and circle of transparency.
  - Camera: Look At Mouse and Look Forwards/Backwards.
  - Use Counter Bar Slot.
- **Cooldowns:** the protocol carries no cooldown timers, so slots only flash on use. Buff timers (0xDF) can show real durations once the buff bar exists.
- **Settings:** interface scale, bar sets that switch on war mode, crafting or riding, a gamepad wheel and a settings page for rows, slots per row and which modifier sets are enabled. The profile format already stores rows, slots and keys.
