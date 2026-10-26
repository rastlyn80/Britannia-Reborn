# Streaming stall reduction — 26 October 2026

`Presentation/StreamingProfile.gd` drives a fixed continuous run route (1602,1591 → 1780,1591 → 1780,1700 → 1480,1700 → 1480,1480 → 1602,1480 → home; 8 tiles/s; fixed per-frame advance; movement waits for destination districts as native movement does). It records wall-clock frames, GPU/render time, engine process/physics time, per-phase main-thread timings (`LiveDistricts.phases`) and a load/decode/install/retire event timeline for the worst frames. `--laps=2` repeats it. Before and after runs used the same route and renderer, one at a time, with no other graphical test running.

Profiling found the dominant stall: collision shapes created by the background resource loader (~176k triangles per district) are built on the main thread in one burst (~0.8 µs per triangle; isolated: a collision-only district file stalled an idle frame 150–160 ms, the mesh-only remainder ~20 ms). The bake now stores collision as plain triangle slices of at most 2,000 faces; the runtime materializes them within the existing 2 ms frame budget and a district counts as loaded — and native movement into it is allowed — only after all its collision exists. Before world entry everything materializes immediately. Second: the merged source window (~50k records) was rebuilt and support-indexed on every install/retirement (up to 93 ms); support lookups are now registered per district from the worker-built indices, and the merged arrays are rebuilt one district per frame and released in slices (worst slice ~5 ms).

| Same route, Windows / RTX 2070 SUPER | OpenGL before | OpenGL after | Forward+ before | Forward+ after |
|---|---:|---:|---:|---:|
| Startup to world-ready | 3.665 s | 2.659 s | 3.940 s | 3.067 s |
| Frame p50 / p95 / p99 | 16.7 / 16.9 / 32.1 ms | 16.7 / 16.8 / 18.7 ms | 16.8 / 19.8 / 29.3 ms | 16.8 / 19.6 / 21.3 ms |
| Worst frame | 326.2 ms | 40.4 ms | 306.4 ms | 79.6 ms |
| Frames > 33 ms / > 100 ms | 75 / 22 | 5 / 0 | 73 / 24 | 6 / 0 |
| Engine memory start / end / peak | 311 / 325 / 412 MiB | 315 / 364 / 453 MiB | 428 / 447 / 549 MiB | 433 / 489 / 592 MiB |

Nine-district retention, instancing, prepared source parity (360,448 / 136,662) and native movement are unchanged. Retained engine memory rises ~40 MiB because per-district cell indices are kept for incremental support lookup. Remaining: a few 60–80 ms Forward+ frames tied to specific districts (single mesh parts that instantiate in ~14 ms in isolation take ~72 ms in the run; unresolved), and the deliberate instant-teleport stress test still reaches ~2 s worst frames in Forward+ / 0.55 s in OpenGL. These are local measurements, not a sustained-frame guarantee.

# Prepared streaming and original radar — 26 October 2026

Launch.cmd prepares local district resources and radar tiles when their source/rule fingerprints change, then opens live Britain. Later launches reuse the verified cache. Initial conversion takes several minutes; the measured three-second startup below is from already prepared data. The separate offline explorer still has its older planning path.

## Runtime

The shared converter/reconstruction plan runs offline, retaining city-wide wall/roof/floor topology. It produces 88 near scenes with baked physical collision and packed native source records, 88 simpler material/shadow variants for the middle distance, and nine coarse terrain sectors. Local prepared resources occupy about 299 MB on disk. These outputs are ignored and must never be distributed.

The client reads a lean index and retains at most nine decoded source/physical districts, a five-by-five middle-distance window and a five-by-five coarse-terrain window. Source dictionaries and movement indices are evicted with districts. Disk reads and native-source decoding use background jobs (maximum two); scene parts are activated and retired incrementally on the main thread with a soft two-millisecond budget. An indivisible GPU/physics operation can exceed this budget. Replacement parts become visible progressively so GPU work is warmed up across frames. As the first near terrain part arrives, its far/coarse overlap is removed; native movement stays gated until the complete district collision/render set is installed. Existing native dynamic items retain their separate authoritative ownership.

Repeated meshes are instanced; empty source/model nodes are removed while sign anchors and collision survive. Headless Godot does not retain ordinary MultiMesh transform buffers for serialization: exported CPU matrices are saved instead and uploaded by the graphical client. Disk roundtrip tests and actual GPU first/last matrix comparisons guard this failure. Rule hashing follows transitive reconstruction/shader dependencies, including the collision builder, so helper changes invalidate old prepared geometry.

## Measurements and limits

Local Windows / RTX 2070 SUPER / Godot 4.7.2, engine allocations rather than total Windows working set or VRAM:

| Measure | Previous live city, OpenGL | Prepared city, OpenGL |
|---|---:|---:|
| Startup to world-ready preview | 41.864 s | 3.591 s |
| Retained engine memory after route | 1,491 MB | 311 MB |
| Peak engine memory | 1,942 MB | 387 MB |
| Scene nodes after route | 83,705 | 2,916 |

The new stress test makes 14 instant district moves, waits for near/far/coarse installation, and repeats the same journey. Retained allocations increased only 0.17 MB between laps in OpenGL and 0.41 MB in Forward+. Forward+ retained about 430 MB with a 507 MB peak. Its startup was 3.220 s.

Actual wall-clock frame measurements include loading: p95 about 36 ms in both renderers, but p99 about 152–167 ms and worst frames 1.27 s (OpenGL) / 2.05 s (Forward+). These are deliberately aggressive instant moves, not native walking speed. Loading is substantially lighter but not hitch-free. The earlier baseline used engine-clamped delta and a different settling schedule; it cannot establish a precise before/after worst-frame comparison. The real 62-step native route measured p95 18.3 ms in Forward+ and 16.9 ms in OpenGL; each still had a roughly 1.17 s worst loading frame. Native screenshots reported 60 FPS in both renderers. These are bounded local measurements, not a sustained-frame-time guarantee.

Full-facet offline planning is not yet bounded. The prepared baker explicitly rejects more than 128 chunks rather than allocating a whole-facet Godot topology graph. Partitioning that graph without cutting buildings, larger-world art coverage, further upload/collision splitting and additional long native routes remain open. This is live Britain, not fully playable Sosaria.

## Minimap

The lower-right north-up radar uses the converted native land/statics plus local radarcol.mul and hues.mul. Each cell uses its land colour or highest drawable static base Z above the land, including roofs and native hues. Invisible markers are excluded. This reconstructs static radar data; it is not an original-client screenshot and does not include dynamic multis/mobiles.

The arrow follows the native character X/Y and eight-way facing. Wheel over the map or +/− zooms from 0.25 to 4 pixels per source cell; camera wheel zoom is unaffected. Coordinates appear below it. The map is hidden before world entry and outside Trammel. Only visible 256-cell PNG tiles become textures, with a fixed 36-texture ceiling. The Britain dataset produces six tiles. Original data, radar imagery and screenshots remain local/ignored.

## Reproduce

```powershell
./scripts/prepare-streaming.ps1
./scripts/prepare-minimap.ps1 # -DataDir accepts an owned client installation
./scripts/verify.ps1
./scripts/test-login.ps1
./scripts/test-streaming.ps1
./scripts/test-streaming.ps1 -Compatibility
./scripts/test-city-render.ps1
./scripts/test-city-render.ps1 -Compatibility
./scripts/test-live-city.ps1 -Visual
./scripts/test-live-city.ps1 -Visual -Compatibility
```

Owned-data parity: Godot --headless --path Viewer --script res://Presentation/PreparedAudit.gd checks all 360,448 terrain / 136,662 static records and complete-versus-incremental scene placement across 88 districts. Graphical ownership tests compare 25,200 wall pixels with distant scenery on/off; 262 sampled GPU matrices agree with saved placement in each renderer. Native tests enter ModernUO, use a real door, complete 62 accepted run steps across the old crop/district boundaries, reconcile XYZ (1599,1567,20), exercise real mouse-wheel minimap zoom without changing the camera, then return the development character home. The user's character, vault and original data are unchanged. Captures/logs in outputs/validation and work are excluded from Git.

These checks establish streaming/source behavior, not finished art. See ART_FIDELITY.md for the next exterior/interior quality gate.
