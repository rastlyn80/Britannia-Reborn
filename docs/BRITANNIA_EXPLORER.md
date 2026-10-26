# Britain city scope — clarified 2026-10-26

The user clarified that the requested expansion is **the whole city of Britain**. Double-click **Explore-Britain.cmd**. The older Explore-Britannia.cmd now opens the same city view. Live Launch.cmd continues to use the tested playable patch.

scripts/prepare-britain.ps1 reads the native Trammel Britain TownRegion from the installed, pinned ModernUO regions.json. Its six region areas cover the city, castle and western outskirts. Their bounding rectangle is rounded outward to 64-tile chunk boundaries: X=1088–1791, Y=1408–1919 (704×512). The extra border is rendering context, not a changed town/guard boundary. The manifest records the original areas and region-file hash; no server boundary is modified.

All 360,448 terrain samples and 136,662 statics across 88 chunks independently match the owned source files. There are 1,597 distinct static IDs. The city overview renders 42,382 simplified wall/roof/tree features in batched meshes, keeping source anchors and elevations. These are explicitly distant geometric approximations, not finished asset replacements. Nearby districts still use shared detailed reconstruction; art mapping and architecture seams remain incomplete. Native population and gameplay are not expanded by the explorer.

The launcher opens the whole city; WASD pans, right mouse orbits and wheel zooms. The Whole Britain button resets to the city overview. Britain district focuses the existing reference patch. Render detail here inspects the selected chunk. Source data and generated city outputs stay ignored locally. Reproduce source parity with scripts/audit-atlas.py --data-dir "YOUR UO DATA DIRECTORY" --atlas outputs/britain. City evidence is outputs/validation/britain-city-overview.png and britain-parity.local.json.

The larger landmass export prepared before this clarification remains as an optional local dataset; it is not the default expansion target. Its implementation/evidence is recorded below.

# Earlier landmass explorer and projecting signs

The retained outputs/atlas dataset covers the full Trammel Britannia landmass, X=0–5119, Y=0–4095. WASD pans, right mouse orbits, wheel zooms. Britain district focuses the reference area; Render detail here loads the selected source chunk. Detail also loads when zoomed close. Launch.cmd retains the validated playable district.

These bounds follow the pinned ModernUO WorldMap.SetDisplay(0,0,5119,4095) and Sextant implementation. The installed Trammel facet is 7168×4096; the additional atlas-space areas include the Lost Lands and other regions and are not part of the classic Britannia landmass requested here. Online references consulted: the official [facet maps](https://uo.com/wiki/ultima-online-wiki/world/facet-maps/) and [UOAM geography](https://uoam.net/geo.html). All geographic input comes from the user's read-only local map1, statics1 and local diffs.

## Reproduction and exact scope

- scripts/prepare-britannia.ps1 builds the C# converter and exports 5,120 separate 64×64 chunks plus a manifest and an eight-tile overview mesh sample grid, including the outermost sample edges. Whole-world data is never expanded into one enormous JSON object of every tile.
- Current conversion: 20,971,520 terrain records; 2,376,103 static records; 4,505 distinct static IDs. scripts/audit-atlas.py --data-dir "YOUR UO DATA DIRECTORY" independently compares every terrain ID/elevation and static XYZ/ID/hue against the owned base+diff files. All match. Source hashes include map, static index/data, tiledata and overlays. A conversion lock prevents opening a partly rewritten atlas.
- Nearby detail adapts binary chunks to the original IR and reuses TerrainSurface and Reconstruction. Neighboring chunks supply a two-tile halo; decoded source cache is limited to 16 chunks. Only one district's detail meshes are retained. Far terrain is hidden beneath the detail region to prevent competing surfaces.
- This is an offline geographic explorer, **not full-world playable multiplayer**. Existing ModernUO account state, native population and live movement remain in the proven Britain crop. No global spawn/decorate or account changes occur.
- New-area art remains incomplete. The atlas preserves every static record, but the shared 187-ID art catalogue does not cover all 4,505 IDs. Unmapped records are visible as gold markers and their count is displayed. The tested new district has 2,596 statics, 581 still unmapped. Large buildings crossing detail-chunk boundaries need assembly ownership/seam work; this is not a claim that all buildings have finished interiors.
- Whole-landmass terrain uses coarse overview color/elevation; detailed chunks reuse source-constrained terrain smoothing. The explorer is not yet the final world-streaming gameplay client or a finished visual pass.

## Binary IR (BRW1)

All values little-endian. Header: uint32 magic 0x31575242, originX, originY, width, height, staticCount. Each row-major terrain sample: uint16 graphic ID, int8 Z. Each static: uint16 graphic ID, uint8 relative X/Y, int8 Z, uint16 hue. Coordinates are recovered by adding chunk origin; the elevation scale is 0.2. Atlas JSON carries source hashes, metadata, bounds and chunk inventory. Files are local derived data in ignored outputs/atlas, never distributed or committed. An interrupted preparation can be rerun.

## Signs

Shared SignPlan derives wall orientation and outward projection from nearby source facades, keeping source XYZ in its report. Building plaques hang perpendicular to the wall on an iron bracket, with two-sided local classic artwork and a matching click volume. Native sign serials/name replies remain authoritative. Noticeboards keep their own mounting style. Opposite-facing and perpendicular-wall fixtures verify rotation and click offsets; no house-specific coordinate patch is used.

Evidence remains local in outputs/validation: britannia-overview.png, britannia-district.png, atlas-parity.local.json and live interaction captures. Proprietary inputs, derived geography/art and screenshots remain excluded from the public repository.
