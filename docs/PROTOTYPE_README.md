# Britannia geography converter — runnable proof of concept

**Working real-data Britain crop plus a separate synthetic demo.** C#/.NET parses MUL and map UOP into JSON; Godot 4 renders that same IR interactively. The discovered local Trammel map converted successfully: 2,304 samples and 1,616 static placements. No proprietary art is extracted or bundled.

## Launch now on this machine

Double-click **Launch.cmd**, or run `powershell -NoProfile -ExecutionPolicy Bypass -File .\launch.ps1` from this folder. Portable Godot is already prepared in workspace work/tools.

Drag with the left mouse button to orbit, wheel to zoom, WASD to pan, Tab to show/hide static proxies, R to reset, Esc to close. The launcher prefers local-world.json when present; run `launch.ps1 -Synthetic` for the fixture demo. The banner identifies each data source.

## Rebuild and test

```powershell
.\build.ps1
```

Uses .NET SDK 8.0.426, no external packages. Runs 15 assertions and regenerates fixture files and Viewer/world.json. On a fresh Windows x64 machine, run `setup.ps1` first (downloads pinned portable .NET and Godot). Alternatively pass `-Dotnet C:\path\dotnet.exe` to build and `-Godot C:\path\godot.exe` to launch. PowerShell execution policy may require `powershell -ExecutionPolicy Bypass -File .\setup.ps1`.

## Import real Britain

This machine's data was found under `C:\Users\gabri\OneDrive\Electronic Arts\Ultima Online Classic`; no files are needed from you. Reimport with `build.ps1 -DataDir` pointing there. On another machine provide a local folder containing map1.mul or map1LegacyMUL.uop and matching staidx1.mul/statics1.mul. The converter opens all source files read-only. Real imports write Viewer/local-world.json, preserving the synthetic world.json.

```powershell
.\discover.ps1
.\build.ps1 -DataDir 'D:\Your UO Data'
.\launch.ps1
```

Default crop: **Trammel x=1408..1455, y=1664..1711**, 48×48 samples around the Britain area. Map height defaults to 4096, supporting ordinary 6144/7168-wide base maps through block addressing. No Felucca fallback. Complete map/static diff overlays are applied, including last-entry precedence for duplicate blocks. Profile: base map1 + all local diffs, excluding alternate map1x extended-world variants. Incomplete patch sets and legacy verdata are refused; a live server may select a different patch profile.

For another real crop, run the built converter: `dotnet Converter/bin/Release/net8.0/Converter.dll convert 'DATA' Viewer/local-world.json X Y WIDTH HEIGHT MAPHEIGHT`. Width/height are 2..256. The code is cross-platform .NET/Godot, but the supplied launch/setup scripts target Windows x64.

## Evidence and limits

See build-log.txt (zero build warnings/errors, 15 passing checks), viewer-log.txt (synthetic render), local-import-log.txt and local-viewer-log.txt (real UOP import/render). Tests cover column-major blocks, row-major cells, signed elevation, absolute/static coordinates, hue/IDs, unaligned crops, raw/zlib UOP, MUL/UOP equivalence, truncation, incomplete-patch refusal, terrain diff precedence and duplicate static diff replacement. Production map1 UOP hash lookup/decode succeeded on local input. Compressed production UOP remains tested with generated zlib fixtures only.

Screenshots: local-screenshot-overview/close.png show real coordinates as generic geometry; screenshot-overview/close.png show synthetic fixtures. Run `capture.ps1` or `capture.ps1 -Local` to reproduce. The source ZIP intentionally excludes all local game-derived IR, real-data screenshots and local manifests; a fresh ZIP launch uses synthetic data.

The viewer uses a continuous diagnostic height mesh and generic boxes at exact static bases. It does not recreate building meshes, textures, tiledata heights, multis, navigation, characters, or game rules. Stacked roof/wall records reveal footprints, but each record remains an arbitrary box. Below-ground records remain below ground. Real coordinates and elevations are preserved under the documented profile; independent in-game landmark comparison remains outstanding.

See IR.md for coordinate conventions and AUDIT.md for parser licenses, local discovery, toolchain, and redistribution boundaries. Do not package real game files or game-derived IR for distribution.
