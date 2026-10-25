# Britain graphics and traversal pass

Scope: the existing 64×64 Trammel crop; original source installation and canonical records remain unchanged.

Status: implemented and tested locally. See GRAPHICS_PASS.md for final coverage, 73 checks, live evidence and limitations; the steps below record the implementation plan.

1. Inspect all 187 used static IDs with local-only original art references. Replace broad name guesses with a persistent ID catalogue, orientation/part/group rules, and per-placement coverage/confidence report.
2. Add missing modular architecture/nature from the already selected CC0 packs; use Kenney CC0 furniture only for gaps. Reconstruct continuous roofs, walls/corners, stairs, trim, furniture, carpets, foliage groups and water. A semantic substitute must not be called an exact art match.
3. Generate presentation collision from solid reconstructed geometry and terrain. Use a swept third-person camera with close-range recovery, full yaw/pitch controls and useful zoom.
4. Add actual server run requests, timed walk/run segments and blended locomotion. Add a bounded, ceiling-aware animated jump. Original UO has no physical jump packet: this initial hop does not change canonical server Z, bypass walls or grant obstacle traversal; a replicated physical jump requires a separate server extension.
5. Verify catalogue coverage, coordinates, grouped contributions, orientations, roof seams, collision/camera behavior, movement and jump lifecycle. Run offline suite and live wall/run/render tests. Inspect and retain local screenshots, reports and continuity documentation.

Acceptance distinguishes all placements accounted for from exact matching: grouped foliage, hidden data and procedural/semantic substitutions must appear in the coverage report rather than being counted as exact kit matches. No full-facet or arbitrary-angle physics claim.
