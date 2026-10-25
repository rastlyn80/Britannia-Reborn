# Local preview recovery extension

This separate GPL-3.0-or-later assembly links to the pinned ModernUO server/content assemblies. It does not patch upstream source. The included LICENSE is GPLv3, matching ModernUO's compatible licensing.

Enabled only by `ultimaClone.previewTools=True`; commands also require a loopback client address. No account is promoted and no staff permission checks are bypassed.

- `[PreviewHome`: move the caller to Trammel (1602,1591,20), ending combat.
- `[PreviewWhere`: server coordinates, map and access level.
- `[PreviewCommands`: available preview commands and native staff-command examples.

Use `scripts/build-preview-tools.ps1 -BuildOnly` to compile without touching a running server. Omit the switch to install the assembly and local configuration; a saved, graceful server restart is needed to load a new assembly. `scripts/setup-server.ps1` installs it on fresh setup. Core assemblies and game data remain unchanged.

Native commands are sent over the normal UO speech protocol. `[Where` and `[Go x y z]` require Counselor or higher in the pinned server. Menus, targeting and other server-specific UI are not implemented by this text panel. Recovery deliberately works for a normal Player account without granting staff powers.
