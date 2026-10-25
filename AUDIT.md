# Parser and data audit — 25 October 2026

This is a bounded source/license audit, not a legal opinion or full security review. No third-party parser source is bundled or linked. The C# reader is a standalone implementation of the documented binary layout and lookup3 algorithm. No NuGet dependencies.

| Candidate | Source reviewed | License at reviewed location | Decision |
|---|---|---|---|
| ClassicUO | [MapLoader.cs](https://github.com/ClassicUO/ClassicUO/blob/main/src/ClassicUO.Assets/MapLoader.cs), [UOFileUop.cs](https://github.com/ClassicUO/ClassicUO/blob/main/src/ClassicUO.IO/UOFileUop.cs) | Files identify BSD-2-Clause; [current license](https://github.com/ClassicUO/ClassicUO/blob/main/LICENSE.md) | Most useful reference: map dimensions, block/chunk layout, hash naming, patches, compression. Reuse would require retaining its notice and disclaimer. No source copied into prototype. |
| ModernUO | [repository](https://github.com/modernuo/ModernUO), [license](https://github.com/modernuo/ModernUO/blob/main/LICENSE) | GPL v3 text | C# server-oriented candidate; no integration or source copying. Copyleft terms need review before combining implementation code into a distributed product. Parser internals were not fully audited. |
| ServUO | [repository](https://github.com/ServUO/ServUO/tree/pub57), [license](https://github.com/ServUO/ServUO/blob/pub57/LICENSE) | GPL v2 text | Alternative server stack; no integration or source copying. Parser internals not audited in this milestone. |

Links point to moving branches, reviewed on the date above; this is not a pinned vendor dependency. Beware similarly named forks: ModernUO-Client's license text differs from the current ClassicUO source. Do not infer a license from a repository badge alone.

## Local discovery

Read-only searches of standard installation locations and registry locations found `C:\Games\Electronic Arts\Ultima Online Classic`. It contains `staidx1.mul` (5,505,024 bytes), `statics1.mul` (20,393,786 bytes), tiledata, diff files, extended statics, and `map0xLegacyMUL.uop` (89,923,808 bytes). No `map1.mul`, `map1LegacyMUL.uop`, or regular `map0` was found there. A wider user-directory search was started; it is not evidence of an exhaustive whole-machine inventory. No client was launched and no game files were modified or copied.

The wider search subsequently found a readable Trammel map at `C:\Users\gabri\OneDrive\Electronic Arts\Ultima Online Classic\map1LegacyMUL.uop` (89,965,541 bytes), alongside matching staidx1/statics1 and stadifl1/stadifi1/stadif1 files. Although Windows reported cloud attributes, a read-only open succeeded. These files were read directly in place; no edits or game-file copies were made. Reading OneDrive files can change their local cache availability. A real import at x=1408, y=1664, 48×48 succeeded with 2,304 terrain samples and 1,616 statics. The base + all local diffs profile found 7,910 unique static patch blocks in a list of 10,931 entries (last duplicate wins). No terrain diff files were present. The map1x extended variant was deliberately not selected. That profile is explicit in the IR/viewer; equivalence to a particular live server's patch selection is not claimed. Source fingerprints are recorded in local-input-manifest.json.

The local launcher prefers Viewer/local-world.json. The shareable ZIP excludes that file, real-data screenshots and manifests; it includes only synthetic Viewer/world.json and synthetic screenshots. Patch precedence and duplicate handling now have regression tests. An independent in-game visual comparison remains future work.

The prototype does not extract or distribute UO art, textures, sounds, or models. Real converted coordinates/static IDs may also constitute game-derived data: keep local-world.json and local-screenshot files local and out of distributable packages. Files named screenshot-overview/close and world.json are synthetic; local-screenshot files and local-world.json use the locally owned map.

## Toolchain

Verified here: .NET SDK 8.0.426, Godot 4.7.2 stable Windows x64, compatibility renderer on NVIDIA RTX 2070 SUPER. setup.ps1 pins these downloads; Godot ZIP SHA-256 is checked. The SDK download uses Microsoft's HTTPS version URL; no SDK digest is pinned. Tools reside under workspace work/tools, not the game directory. Godot is MIT licensed; its standard engine distribution retains its bundled notices. .NET distribution retains Microsoft notices. Neither engine nor SDK is included in the source ZIP.
