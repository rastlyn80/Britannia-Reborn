# Shared conversion and reconstruction pipeline

The supported end-to-end entry point is scripts/prepare-play-world.ps1. It now performs both stages automatically:

1. Converter/Program.cs reads local MUL/UOP/diffs/tiledata into unchanged engine-independent JSON. Original coordinates/elevations remain the authority.
2. scripts/reconstruct-world.ps1 runs Viewer/Presentation/ConversionPass.gd, which invokes the exact same World/Reconstruction/FloorPlan/Facade/InteriorShell/TerrainSurface rules as the interactive viewer. It saves a corrected 3D scene, source placement/repair coverage, and a manifest with the IR hash and every presentation rule's SHA-256. Unmapped IDs stop the export with a report.

Default outputs: outputs/conversions/play-world/converted-world.tscn, reconstruction.json, conversion-manifest.json. The .tscn uses the installed Viewer project's res:// assets. It is a local Godot scene, not an engine-independent replacement for source JSON. Dynamic character motion/contact/camera remain viewer runtime behavior. The regular viewer rebuilds with current shared rules, so it does not load stale baked meshes.

The script accepts DataDir, X, Y, Width, Height, WorldPath and OutputDirectory; defaults remain the current Britain/Trammel crop. For an existing JSON export, scripts/reconstruct-world.ps1 -WorldPath <absolute JSON path> applies the reconstruction stage without reading source game files again. Direct C# convert is intentionally the low-level extraction stage only.

Stair material correction: solid supports and landing decks now use the same world-space wood/stone PBR material as treads. Source anchors and heights are unchanged.

Floor flicker correction: the basement liner's top originally coincided with the terrain-encoded ground floor. Its upper face is now 2 cm below that floor; its underside remains at the ceiling level. When a zero-height static board floor coincides with a flat terrain cell, only the static floor emits the visible surface. Duplicate static floor records share one owner, retaining all source records in coverage. No depth bias or transparent workaround.

Validation: 201 offline checks, including ceiling separation, terrain/static surface ownership, duplicate floor ownership, and shared wood/stone stair materials. The full real conversion pipeline and bake/reload passed; final bake reload matched all 6,294 meshes, with 2,689 accounted source records, zero unmapped IDs, 752 ceiling panels, 190 grouped contributors and 121,112 collision triangles. Source input remained read-only. New tavern/upstairs/stair captures are in ignored outputs/validation; conversion output and all game-derived files remain ignored. Existing renderer/movement limitations are recorded in INTERIOR_CONTACT_PASS.md.
