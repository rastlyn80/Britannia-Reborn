# Native interaction and comparison pass

## Implemented

- Gumps support draggable frames, native nomove/noclose state, classic item pictures (including hues), cropped pictures and safe bold/italic/underline/center/color text. Native control IDs and reply packets are retained. Unknown controls remain explicitly read-only.
- The item browser retains separate server-owned container caches, classic icons, a matching 3D preview, equipment, backpack/last-container navigation and actions to use, take, deposit, equip and place items in the world. Click-to-place converts a nearby physical hit to a native grid coordinate. Escape cancels before an item is lifted.
- Lift/drop/equip packets are batched as one requested operation, serialized by a single pending action and paced for this shard's one-second native cooldown. No optimistic ownership change occurs. Native item/container/equipment updates confirm completion; rejection, bounce and timeout remain visible.
- Native NPC context menus and shop stock/price packets drive the shop interface. Prices and stock serials are paired in native display order. Buying submits the normal vendor response; no client-created items or free purchases.
- PreviewCommerce is a loopback-only extension enabled by the existing development flag. It places native TavernKeeper and InnKeeper classes at matching entries from the pinned upstream spawn file within the crop. Repetition preserves existing vendors. Their native AI, inventory, payment and prices are unchanged. No vendor was hand-placed outside the source coordinates.

## Evidence

The hung server was force-stopped only after explicit user approval, with saves/config backed up first. It restarted from the existing saved world and loaded the bounded native innkeeper extension. Normal automatic saves resumed (08:40 and 08:45).

scripts/test-commerce.ps1 and -Visual both pass: 35 native tavern stock/price records, real dice delivery and two-gold debit; valid adjacent-ground drop/pickup; native shoe unequip/re-equip; public-drawer ownership rejection; fifteen-gold native backpack purchase and owned-container deposit/withdrawal; immovable-item rejection; return to the development start. GPU screenshots use the production UI. Action pacing now also follows received server acknowledgements to cover delayed graphical frames; it never retries rejected transfers automatically.

The latest verification includes 22 commerce checks, 13 UI checks and 33 world-object checks. Frames stay within native resize bounds; icons/hues remain local. Offline presentation captures are explicitly labelled fixtures and are not used as live-transaction evidence.

## Comparison

scripts/audit-classic-parity.py independently decodes the owned Trammel MUL/UOP data and diffs all coordinates/elevations/IDs/hues against the current IR. Current result: 4,096 terrain samples and 2,689 static records match exactly; all 187 static IDs have mappings. Native population remains 12 door leaves (8 singles plus 4 leaves in two pairs) and 5 signs. The local report is outputs/validation/classic-parity.local.json and is excluded from Git.

The existing ClassicUO window was directly inspected through the Computer Use skill. Its inn street, entrance, sign, timber/plaster facade, roof and cobblestone paving are recognizable in the source-aligned 3D reconstruction. This does not establish identical silhouettes: roof materials, wall opening dimensions and modular details remain deliberate presentation differences. After recovery the separate development ClassicUO profile entered the live street. Clicking its sign returned The Wayfarer’s Inn, confirming the native name and projecting placement. A systematic native door/trade UI comparison remains incomplete. A separate -Development profile is now available in scripts/launch-classic.ps1 to avoid touching the user's saved primary login.

## Reproduce

1. Load the extension with scripts/build-preview-tools.ps1 and a saved server restart.
2. Run scripts/test-commerce.ps1 for a real development-account transaction sequence. It buys normal dice and an owned backpack using existing development gold; it never resets or funds accounts. Test purchases remain native persistent items.
3. Run scripts/prepare-client-art.ps1 to refresh local classic icons/hue palettes. Original files are read only; the caches remain ignored.
4. Restart Launch.cmd. Click an NPC, choose the native Buy action, then buy an item. Open B, select an item and use the explicit action controls. Public furniture ownership restrictions still apply.
5. Run scripts/audit-classic-parity.py and scripts/verify.ps1. Use scripts/test-commerce.ps1 -Visual for local screenshots with the server running.

Known limits: whole-stack movement only; no stack-splitting UI, vendor selling, full 3D wardrobe replacement, full native font/HTML parity or arbitrary special gumps. Equipping is authoritative and reflected in the equipment view; the current base character outfit is still a presentation asset. Live gameplay/population remains within the validated crop. The separate full-landmass explorer is documented in BRITANNIA_EXPLORER.md.
