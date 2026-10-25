# Contributing to Britannia Reborn

Welcome. This is an early C#/.NET and Godot 4 project with ModernUO as the authoritative server. Keep changes small, explain observable behavior, and include reproducible validation.

## Workflow

1. Follow README.md for setup. Begin with synthetic fixtures when you do not have game data.
2. Read AGENTS.md and the architecture/progress documents before changing parsing, networking or reconstruction.
3. Keep parser output engine-independent and retain source coordinates, elevation and provenance. Put general reconstruction fixes in shared rules, with translated/rotated fixtures where appropriate, rather than special-casing one house.
4. Keep ModernUO pinned and its core unchanged. Use isolated extensions for project integration; discuss dependency updates before changing pins.
5. Run scripts/verify.ps1. Include appropriate live checks for networking changes and GPU evidence for rendering changes. Distinguish fixtures, relay authentication and actual world entry.
6. Open a pull request explaining the problem, resulting behavior, validation and limits. Include only code and assets you have the right to share.

## Data and assets

Do not commit or attach proprietary UO files, converted real-map data/screenshots, local configuration, credentials or saves. Report a source ID and minimal synthetic reproduction where possible. Do not paste passwords, account tokens or private logs into an issue. Third-party assets need retained notices, exact sources, checksums and modification records.

Original project contributions are made under GPL-3.0-or-later. Third-party files retain their own licenses and notices. No contributor agreement is currently required.

## Useful first contributions

- Parser fixtures for unsupported or truncated inputs.
- Synthetic corner, floor, roof, stair and terrain regressions.
- Server packet handling and malformed-input tests.
- Source-independent asset mappings with documented licenses.
- Profiling and rendering improvements with measured results.

Full facets, production hosting and cross-platform exports remain unfinished. Discuss large changes in an issue first.
