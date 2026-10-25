# Original 2D comparison

Double-click `Play-Classic-2D.cmd` in the project folder. It opens ClassicUO against the existing ModernUO server at 127.0.0.1:2593, using the latest Windows-encrypted Godot login. The same account cannot remain connected in both clients; use `Play-Classic-2D-Observer.cmd` for side-by-side comparison with the separate development observer character. The observer does not share your character or credentials.

ModernUO is the server; ClassicUO displays the original 2D client graphics. Right-click to move. Type `[PreviewHome` and press Enter to return to Britain; `[PreviewWhere` reports the current position. F6 recovery is a Godot shortcut.

The launcher starts the existing local server if needed, reads installed UO data without changing it, and prepares a separate local profile. Portable binaries are verified against ClassicClient/dependency.json. No proprietary client data is included. First startup can take a minute. OpenGL is selected because the default driver stalled on this machine. Duplicate launches of the same profile are ignored.

The native client requires a temporary compatibility password field while starting; this is cleared after connection or failure. Persistent credentials remain in the Windows DPAPI vault. Passwords are not process arguments. ClassicUO profile/preferences and tools stay ignored locally.

Validation: Windows PowerShell 5 profile preparation passed. The native observer reached its character in-world (window title, game-load logs and established server socket), and the Godot primary independently entered the same running server. No visual inspection of the native window is claimed. ClassicUO is BSD-2-Clause; the pinned release digest and license are in ClassicClient.
