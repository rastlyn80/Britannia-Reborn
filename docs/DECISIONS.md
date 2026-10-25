# Decisions

1. Continue the existing converter/JSON/Godot foundation as UO World Studio; no rewrite or unrelated demo.
2. ModernUO owns simulation and persistence. Keep source pinned/unchanged; isolate runtime and future extension modules.
3. Direct UO protocol first: real login/server-list/relay worked without an adapter. Add infrastructure only for demonstrated limitations.
4. Converter SDK 8.0.426; server SDK 10.0.201; Godot 4.7.2. Server builds run from its checkout for SDK selection.
5. Shallow history cannot satisfy ModernUO's version-height tool. Use separate local development version metadata; record the actual source SHA in Server/dependencies.json. Gameplay is unchanged.
6. Provisional server profile is the upstream latest listed expansion, Endless Journey, with Trammel selected. Final rules/era remain undecided; no expansion-dependent gameplay changes in this slice.
7. Local unencrypted classic login only. No public service configured. Remote transport/security needs a future review.
8. Preserve canonical records; rendering scale, colors, proxy geometry and interpolation belong to presentation. Unknown architecture remains placeholders.
9. Proprietary data, local IR, secrets and saves stay out of Git/distribution. No external art/purchases introduced.
