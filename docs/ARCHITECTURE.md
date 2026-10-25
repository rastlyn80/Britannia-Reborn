# Architecture

Separate applications: Converter (.NET 8) reads local UO files into canonical JSON; Viewer (Godot 4/GDScript) renders it; Server/ModernUO (.NET 10) remains authoritative. Server/runtime owns configuration/saves; .tools holds SDKs, Godot and package caches.

Viewer/Network/LoginProtocol.gd owns login framing; GameSession.gd owns the game TCP session, streaming Huffman, calibrated framing and canonical entity state. LoginPanel presents account/character selection and inventory. World.gd presents interpolated avatars and a third-person keyboard controller. LoginSmoke, PlaySmoke, MultiplayerSmoke and PlayVisual exercise actual ModernUO and the actual scene. No gateway or replacement game simulation. Movement is sent only as a request; displayed targets come from server responses, including classic resync for exact Z.

Canonical x/y/z are preserved. Render transform: east +X, south +Z, UO signed elevation ×0.2 to +Y, with horizontal crop origin subtracted. The scale is a convention, not a metres claim. Proxy sizes/colors are presentation only.

Target: extract reusable WorldData/Parsing libraries, deterministic chunk manifests and overrides; UO World Studio exports regenerable worlds to the shared client. Shared code avoids Windows-only APIs. Windows automation/testing first, Android next; iOS builds/signing require Apple tooling and remain unverified.
