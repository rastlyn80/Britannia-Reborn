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
10. The first playable slice adapts ClassicUO's Huffman tree and packet sizes under BSD-2-Clause, retaining its full notice. Session logic and Godot presentation remain project code; no ModernUO core/gameplay changes.
11. Temporarily request classic resync after each accepted move for exact server XYZ, reset the sequence accordingly, and pace requests at 450 ms minimum. This favors verifiable correctness in a tiny region over throughput; replace before wider multiplayer/streaming.
12. User-selected art direction: Quaternius Medieval Village MegaKit is primary for architectural statics; Quaternius Stylized Nature MegaKit is primary for vegetation and natural statics. Kenney is a fallback only for uncovered needs, with style matching before use. Start with free editions; paid editions still require explicit purchase authorization. Selection does not imply assets have been imported.
13. First art pass now imports the selected free environment packs plus Quaternius Universal Base Characters, Universal Animation Library and Fantasy Outfits Standard. Fixed peasant appearance is a presentation preview. Preserve licenses/hashes; no purchases. Piecewise continuous rendering follows confirmed server XYZ, preserves corners and never extrapolates; server collision remains authoritative. Cadence is now 410 ms, superseding decision 11's 450 ms. Per-step elevation resync remains until a tested replacement exists.
