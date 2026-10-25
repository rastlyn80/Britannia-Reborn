# Architecture

Separate applications: Converter (.NET 8) reads local UO files into canonical JSON; Viewer (Godot 4/GDScript) renders it; Server/ModernUO (.NET 10) remains authoritative. Server/runtime owns configuration/saves; .tools holds SDKs, Godot and package caches.

Viewer/Network/LoginProtocol.gd owns direct TCP login framing/state; LoginPanel presents it; LoginSmoke runs against ModernUO. No gateway or replacement game simulation. The next world-session layer owns game login, streaming Huffman, packet framing and authoritative entity snapshots. Presentation will interpolate server positions rather than change UO movement rules.

Canonical x/y/z are preserved. Render transform: east +X, south +Z, UO signed elevation ×0.2 to +Y, with horizontal crop origin subtracted. The scale is a convention, not a metres claim. Proxy sizes/colors are presentation only.

Target: extract reusable WorldData/Parsing libraries, deterministic chunk manifests and overrides; UO World Studio exports regenerable worlds to the shared client. Shared code avoids Windows-only APIs. Windows automation/testing first, Android next; iOS builds/signing require Apple tooling and remain unverified.
