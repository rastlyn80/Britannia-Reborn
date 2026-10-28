# Britannia Reborn

**A modern, stylized 3D reimagining of the Ultima Online experience, built with ModernUO, a faithful world converter and Godot 4.**

Britannia Reborn is an independent, open-source project exploring how Britannia's original geography and rich, skill-based MMORPG systems can become an interactive third-person world. The aim is to preserve the places and mechanics that make Ultima Online distinctive while presenting them through smoother movement, modern lighting and a coherent fantasy art style.

This is an early playable proof of concept under active development. It is not a complete game, an official Ultima Online client or a production-ready shard. The live client now streams the converted city of Britain in Trammel. Native population and the verified shopping/inventory loop remain concentrated in the original district; full facets and most gameplay interfaces remain future work.

Double-click **Launch.cmd** for live Britain. The first preparation builds local streaming resources and takes several minutes; later prepared startup is roughly three to four seconds on the development machine. The lower-right minimap uses original UO radar colours; wheel over it or use +/− to zoom. Use **Explore-Britain.cmd** for the separate offline explorer. See [live Britain scope and checks](docs/LIVE_BRITAIN.md).

## What works today

- **Read-only world conversion:** C#/.NET reads compatible MUL/UOP terrain, statics, tile metadata and supported local diffs into engine-independent JSON. Synthetic fixtures let you test the parser without game data.
- **Shared reconstruction rules:** source-driven terrain, joined walls, floors, stairs and roofs. Repairs belong to the shared conversion/presentation pipeline rather than hand-edited building placements. Baking and runtime viewing use the same rules.
- **Interactive Godot 4 viewer:** stylized CC0 environment and character assets, blended PBR terrain and shorelines, water ripples, foliage sway, architectural collision and a camera that retracts around solid geometry.
- **Server-owned world objects:** bounded upstream population of doors, containers, signs and decoration. Single/double door layouts stay native; timber leaves use human-scaled lintels. Click doors to open/close, containers for real contents, and signs for their server-confirmed building names.
- **Prepared live city streaming:** 704×512 source tiles, nine nearby physical districts, background resource/source loading, incremental scene activation/eviction and bounded distant scenery. Unloaded destinations are gated before sending movement packets. Local retained engine memory fell from about 1.49 GB to 311 MB in the OpenGL test; rapid moves still expose loading hitches. See [performance, limits and original radar](docs/STREAMING_AND_MINIMAP.md).
- **Zoomable original-data minimap:** native land/statics and radar colours, character position/facing, coordinates and bounded tile textures. Game-derived imagery stays local.
- **Real ModernUO sessions:** account login, character creation/selection, server-confirmed movement, two-client movement replication and backpack contents. Native ClassicUO can connect to the same local server for comparison.
- **Smoother traversal:** continuous presentation between server coordinates, gradual 360-degree facing, running/walking animation, stair foot contact and a ceiling-aware cosmetic jump. The server remains authoritative; jumping is not a replicated gameplay ability.
- **Prepared human motion:** both fitted human bodies use free CC0 locomotion, armed/unarmed guards and a native action subset, with garment-safe strides/attacks and independent server hair/beard properties. **Review-Human-Motion.cmd** opens the animated before/after. Preparation and unfinished action families: [human motion pass](docs/HUMAN_MOTION_PASS.md).
- **Server-driven environment:** native light and rain/snow packets drive lighting and precipitation. An isolated local server extension supplies ModernUO's regional clock and initial/region-exit weather snapshots. Soft moving clouds, horizon haze and day/night presentation follow those inputs.

The original reference crop (still available with `./launch.ps1 -ReferencePatch`) spans Trammel X=1576–1639, Y=1568–1631: 4,096 terrain samples and 2,689 static placements across 187 mapped IDs. These figures describe local validation; the map and converted data are not included. Passing that crop does not establish fidelity for every building, source ID or facet.

The first reviewed art pass adds explicit per-graphic replacements, richer furniture, detailed doors/windows, masonry surfaces and source-backed support placement. Double-click **Review-Art.cmd** to build a local original-art/model comparison gallery and automatic scene captures. The catalogue has 108 choices (88 reviewed, 20 provisional); most Britain IDs still need detailed artistic review. See [art checkpoint, evidence and remaining gaps](docs/ART_CATALOGUE_PASS.md).

## Architecture

```text
Your local UO data (read only)
        |
        v
C#/.NET converter --> engine-independent JSON --> shared Godot reconstruction
                                                      |
ModernUO server <--- login, movement, interactions ---> Godot 4 client
```

ModernUO is a pinned, separately fetched dependency. Its core is unchanged; preview recovery and environment bridging live in `Server/PreviewTools`. Rendering substitutions never rewrite original source coordinates or game files.

## Try it on Windows

Current scripts target Windows x64 and PowerShell. Cross-platform exports are a goal, not a verified feature. Downloaded tools, generated data and saves stay inside the local checkout and are ignored by Git.

### Synthetic preview — no game files required

```powershell
git clone https://github.com/rastlyn80/Britannia-Reborn.git
cd Britannia-Reborn
.\setup.ps1
.\launch.ps1 -Synthetic
```

This generates clearly labeled synthetic terrain/statics. It does not recreate Britain or provide a running shard. Tool versions are pinned; Godot's archive and art inputs have recorded checksums. The .NET SDK archive digest is not yet pinned.

### Local playable Britain slice — bring your own compatible UO data

```powershell
.\scripts\setup-server.ps1 -DataDir 'C:\Path\To\Ultima Online Classic'
.\scripts\prepare-play-world.ps1 -DataDir 'C:\Path\To\Ultima Online Classic'
```

Then double-click **Start-Server.cmd**, followed by **Launch.cmd**. The launcher refuses a duplicate local server. Follow any upstream console initialization prompts on first setup. Use the local development account or enter a new local username/password, then create/select a character in Britain. A fresh shard does not include pre-created characters or a fully populated world. After creating a development character, run **Populate-Britain.cmd** with the server running, then restart the viewer. This populates only the prepared crop and checks a repeated run creates no duplicates. The helper requires Python 3. It also prepares local-only item metadata and English client labels; neither is committed.

The development server binds to loopback. Credentials, encrypted remembered logins and saves remain local. This configuration is for local development, not public hosting. **Launch-Compatibility.cmd** selects the fallback renderer. **Launch-Second-Client.cmd** uses a separate development account. The separately fetched ClassicUO comparison client uses the same local server; see [the comparison guide](docs/CLASSIC_COMPARISON.md).

Controls: **WASD** move, **Shift** run, **Space** cosmetic jump, **right mouse drag** orbit, **wheel** zoom, **B** backpack, **left click** use/inspect an object, **E** use nearest object, **F6** return to the preview start. Submitted logins can be remembered using Windows user-bound encryption. The rename preserves the existing vault location.

## Build and validate

```powershell
.\scripts\verify.ps1              # parser, protocol, reconstruction and regressions
.\scripts\test-login.ps1          # live server list and game relay
.\scripts\test-play.ps1           # actual character entry, movement and backpack
.\scripts\test-play.ps1 -Multiplayer
.\scripts\test-world-items.ps1   # native door/container/sign interactions
.\scripts\test-world-items.ps1 -Visual # actual mouse clicks and local captures
.\scripts\test-environment.ps1    # real entry and server clock/light/weather
.\scripts\capture-stability.ps1   # moving-camera floor/doorway checks
.\scripts\capture-environment.ps1 # controlled day/night/rain/snow GPU captures
```

Live checks need the local server and an existing development character. Some reconstruction tests need a locally prepared crop; fixture tests alone do not establish live gameplay. GPU captures and map-derived outputs remain ignored and are not distributed here. See [testing](docs/TESTING.md), [world objects](docs/WORLD_OBJECTS.md) and [server environment](docs/SERVER_ENVIRONMENT.md).

## Roadmap and contributions

Bounded server-owned doors/containers/signs are now integrated in the current slice. The next priorities are systematic placement/behavior comparison against ClassicUO and a larger converted region with chunk boundaries validated. Longer-term goals include streaming, broader source-ID coverage, equipment and inventory UI, combat, skills, crafting, NPCs and additional facets. None is implied complete by the preview.

Contributions are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md), [the master plan](docs/MASTER_PLAN.md), [progress](docs/PROGRESS.md) and [roadmap](docs/ROADMAP.md). Useful work includes small reproducible geometry fixtures, format validation, asset mappings, protocol regressions and measured rendering improvements. Open an issue to coordinate larger architectural changes. The master plan includes historical implementation instructions; this README describes the current public scope.

## License, assets and game data

Original project code is **GPL-3.0-or-later**; see [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md). Third-party notices remain in place: ClassicUO-derived protocol tables are BSD-2-Clause, and bundled Quaternius/Kenney/Poly Haven art is CC0. Sources and checksums are recorded alongside the assets. ModernUO is fetched separately under its own GPL license.

**No proprietary Ultima Online map, art, sound, credentials, save or converted real-map dataset is distributed.** Obtain compatible game data separately and keep it local. Do not attach game-derived screenshots or source files to public issues. Britannia Reborn is an independent fan project, unaffiliated with or endorsed by Ultima Online's owners. See [the dependency/license audit](docs/LEGAL_AND_LICENSES.md) and its limits.


The native object layer now includes graphic-specific props, local classic sign faces, clickable container contents, readable server books, native dice replies, bulletin-board reading and target selection. Server help opens a reusable native gump renderer with local classic artwork, native control IDs and server-side callbacks. See [world-object and gump scope](docs/WORLD_OBJECTS.md) for supported controls and remaining limits. Use scripts/prepare-client-art.ps1 to refresh local artwork after encountering new windows. Extracted artwork and game data are never included in this repository.


The next interaction pass adds draggable gumps, classic item icons/hues, equipment and native item-placement controls, NPC context menus and a native vendor shop UI. Local setup derives the Salty Dog tavern keeper and innkeeper from the pinned source spawn file. Buying uses native stock/prices and existing character gold. See [commerce evidence and remaining limits](docs/COMMERCE_PASS.md): native purchases/payment, owned-container and ground transfers, equipment and rejection paths pass headless and graphical live checks.

Use scripts/setup-preview-shops.ps1 after loading the new preview extension; Populate-Britain.cmd also invokes it. For ordinary play, click a vendor and choose Buy. B opens the backpack; select an item, then use the explicit inventory action. Place in world waits for a nearby surface click; Escape cancels. Public-container ownership restrictions remain native. scripts/test-commerce.ps1 uses only the development account for real purchases and transfers. scripts/audit-classic-parity.py checks the complete current crop against the owned UO files without modifying them.


Double-click **Explore-Britain.cmd** for the whole city of Britain, including the castle and western outskirts. The city view uses ModernUO's native region bounds, rounded outward to 88 local chunks (704×512 tiles). The older Explore-Britannia.cmd opens this same city scope. A simplified city-wide building/tree overview and nearby district detail are available; detailed art coverage, architecture seams and expanded gameplay remain unfinished. **Launch.cmd** retains the tested playable patch. See [city explorer scope and reproduction](docs/BRITANNIA_EXPLORER.md).


Britain's explorer now has rendering rules for every city graphic ID, joined city-wide architecture and nine nearby detailed chunks. The same shared reconstruction rules feed conversion and rendering. Double-click **Explore-Britain.cmd**; initial preparation bakes the city, and first detailed planning takes about 20 seconds on the development machine. The new models are stylized substitutes; exact bespoke art matching and production streaming remain ongoing. See [mapping and seam evidence](docs/BRITAIN_MAPPING_AND_SEAMS.md). **Launch.cmd** retains the live playable patch.
