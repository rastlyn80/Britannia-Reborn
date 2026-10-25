# Britain material, terrain and lighting refinement

## Result and scope

This pass refines the existing reference district: verified seamless PBR surfaces, smoother source-backed banks, blended ground and shore materials, window glass/sills, roof-following rafters, warm interior fixtures and restrained environmental motion. The modern desktop default is Forward+; Launch-Compatibility.cmd retains the OpenGL path. It is still a small crop, not completed art for all Britannia.

## Surface provenance

Seven Poly Haven CC0 texture sets supply 21 unmodified 1K JPEG maps (albedo, OpenGL normal and roughness): cobblestone_floor_03, forest_ground_04, brown_planks_03, rock_wall_04, rock_face_03, plastered_wall_02 and grey_roof_tiles_02. The natural rock-face set is used on banks; masonry is reserved for building materials. The manifest at Viewer/Art/Surfaces/manifest.json records source URLs, authors, provider MD5, pinned SHA-256 and measured metre scale. NOTICE.md explains the license. Raw files are unchanged; shaders grade and blend them. Run scripts/prepare-surfaces.ps1 to restore missing files, or -VerifyOnly for offline checks. Existing Quaternius/Kenney provenance remains unchanged. No proprietary game art was added.

All shared surface materials retain a source-coordinate origin, so loading a larger crop does not rephase their detail. Material instances keep their own origin when another scene is created.

## Terrain and shorelines

TerrainSurface retains every original grid XYZ anchor. Gentle slopes use the original gentler diagonal and support heights. Steeper cells use bounded monotone interpolation with quarter-metre subdivisions; gentle cells use half-metre subdivisions. Shared edges agree, extrema cannot overshoot the source range, and collision is generated from the same visible mesh. Normal sampling smooths lighting across the surface. The source IR and authoritative navigation remain unchanged. There is no broad erosion or flattening of authentic elevations.

ShorelinePlan derives a signed bank/water distance field, water level and seabed depth from the source crop. Grass/soil/paving blend through interpolated source masks and small noise variation. Steep faces use triplanar natural rock with an upper vegetation blend. Damp bank shading, shallow-water colour and a low-intensity moving water-edge wash soften intersections. The source has steep banks, so cliffs remain; smoothing is not a promise to turn every river into a shallow beach. Out-of-crop context is not invented, and future streamed chunks still require a neighboring data halo.

## Buildings, lighting and animation

Building surfaces, floors and bevelled furniture use the new metre-scaled maps. Windows have thin tinted glass and projecting sills. Joined roof samples also position periodic interior rafters; these follow roof slopes rather than adding arbitrary hanging infill. Client-only hanging fixtures are inferred from indoor furniture and overhead roof coverage. Their lights cast architecture/furniture shadows in Forward+, while fixture meshes do not block their own lights. These are presentation fixtures, not new server inventory items.

Forward+ adds temporal antialiasing, screen-space ambient occlusion and indirect light, screen-space/sky reflections, restrained glow, ACES tonemapping and light aerial haze. Compatibility keeps the shared materials and geometry, disables unavailable temporal/indirect/reflection effects and avoids interior shadow-map cost. ReflectionProbe atlases were intentionally omitted because the pinned engine emits a reproducible seven-texture shutdown leak (https://github.com/godotengine/godot/issues/122498); the final pass uses sky and screen-space reflections and shuts down cleanly.

Tree sway is limited to 0.22m at crowns, with zero deformation weight at mesh bases. Grass uses a smaller height-derived amplitude and flutter. Water has low-amplitude world-continuous ripples and at most 2cm combined vertical wave movement; adjacent source sheets share the same phase. Source/map comparison disables deformation. Runtime materials use the engine clock by default. Both controlled-time and freely running-clock GPU comparisons pass for trees, grass and water.

## Validation and reproduction

- scripts/verify.ps1: 150 offline checks, converter/extension builds, 21 surface-map checksum checks and real crop load.
- scripts/capture-visual-pass.ps1: six actual GPU animation checks, fixed-camera building/interior/shoreline screenshots, 30 forest and 30 water frames, and optional GIF previews using the bundled Python/Pillow runtime.
- scripts/test-graphics.ps1 -PreviewOnly: the existing development character entered the running server with the upgraded viewer. The user's account/login vault was not changed.
- res://Presentation/PolishProbe.gd: repeatable district render timing. An isolated Forward+ run on RTX 2070 SUPER measured about 16.5ms/frame with vertical sync, not an uncapped throughput or full-map benchmark.

All 2,689 source placements remain accounted for, with zero unmapped IDs in this crop. Current presentation collision is 123,384 triangles; source anchors, existing grouping/suppression metadata and server state are preserved. New tests cover interpolation bounds, source anchors, continuity, overlap between regions, walkable support, mesh coverage/normals, signed shore data and PBR origin/scale bindings.

Local ignored outputs: britain-interior.png, visual-street.png, visual-roof-corners.png, visual-shoreline.png, living-environment.gif, moving-water.gif, source coverage and controlled-time frame images. GIFs are ping-pong previews of actual rendered frames, not game simulations or generated concept art. The viewer itself runs continuous animation. Further work remains on full-region asset coverage, complex roof intersections, terrain silhouettes at a larger scale, foot IK and streaming ownership/halos.
