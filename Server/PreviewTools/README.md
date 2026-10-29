# Local preview recovery extension

This separate GPL-3.0-or-later assembly links to the pinned ModernUO server/content assemblies. It does not patch upstream source. The included LICENSE is GPLv3, matching ModernUO's compatible licensing.

Enabled only by `ultimaClone.previewTools=True`; commands also require a loopback client address. No account is promoted and no staff permission checks are bypassed.

- `[PreviewHome`: move the caller to Trammel (1602,1591,20), ending combat.
- `[PreviewWhere`: server coordinates, map and access level.
- `[PreviewKit house|boat|map|site [multi]|dock` (`PreviewKit.cs`): a test kit for the client's world systems, an owner-approved exception (2026-10-29) to the no-staff-powers rule, still loopback- and previewTools-only. It hands the caller ordinary upstream items (a small brick house deed, a house placement tool with 200,000 gold in the bank, a small boat deed, a level 1 treasure map), or moves the caller beside the nearest spot inside the prepared area where the server's own rules accept a house (`site`, optionally for another multi such as 5100, a 7x7 custom foundation) or a small boat (`dock`).
- `[PreviewCommands`: available preview commands and native staff-command examples.
- `[PreviewSpawn`: builds the upstream Trammel spawners (Data/Spawns, shared plus the era folder, as the world-generation menu selects them) that lie inside the prepared preview bounds, with the upstream DTO builder. Spawners already in place (same GUID) are kept, so repeats create nothing; a free-standing vendor from `[PreviewShop`/`[PreviewInn` next to its native spawner is retired. `[PreviewSpawnAudit` writes spawner and creature counts to Data/UltimaClonePreview/spawns.local.json.

Use `scripts/build-preview-tools.ps1 -BuildOnly` to compile without touching a running server. Omit the switch to install the assembly and local configuration; a saved, graceful server restart is needed to load a new assembly. `scripts/setup-server.ps1` installs it on fresh setup. Core assemblies and game data remain unchanged.

Native commands are sent over the normal UO speech protocol. `[Where` and `[Go x y z]` require Counselor or higher in the pinned server. Menus, targeting and other server-specific UI are not implemented by this text panel. Recovery deliberately works for a normal Player account without granting staff powers.

Developer edit session (`DevEditSession.cs` pure logic, `DevEditCommands.cs` adapter): disabled unless `ultimaClone.devEdit=True`, loopback only, and only for accounts listed in `ultimaClone.devEdit.accounts` (set by `scripts/configure-dev-edit.ps1`). `[DevEdit join|set|place|brush|undo|redo|lock|unlock|preview|save|load|status|leave` edits a visual overlay journal in `DevEdit/`; it never changes the map, items, accounts or world saves. Offline tests: `Server/PreviewTools.Tests`. See docs/DEV_EDIT.md.
