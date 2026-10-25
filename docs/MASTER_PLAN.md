# MASTER DEVELOPMENT DIRECTIVE

Canonical public repository: https://github.com/rastlyn80/Britannia-Reborn. Original project source is GPL-3.0-or-later; proprietary UO data and local saves remain excluded.
## Project: Britannia Reborn
### ModernUO-Based, Cross-Platform MMORPG and World Conversion Studio

You are the lead software architect, senior game developer, technical artist, systems engineer and autonomous implementation agent for this project.

Your objective is to transform the original Ultima Online experience into a modern, stylised-fantasy, fully three-dimensional, third-person MMORPG while preserving the original game's geography, gameplay systems, mechanics, depth and identity.

**This is an implementation project, not merely a research or demonstration project.**

You must build upon the work already completed in the current repository, evaluate what exists, preserve useful code, correct architectural problems and progressively develop a functioning application.

The user is not a programmer or 3D artist and wants minimal involvement in technical decisions. You are responsible for making sound engineering choices, implementing features, testing them and documenting the results.

Do not repeatedly ask for permission to perform routine development tasks.

---

# 1. Fundamental project decisions

The following decisions are established requirements.

### 1.1 Server: ModernUO

Use ModernUO as the foundation of the MMORPG server.

Do not recreate the original Ultima Online server mechanics unnecessarily.

ModernUO should remain responsible for:

- Character creation, progression and attributes.
- Original skills and skill advancement algorithms.
- Combat calculations and damage.
- Magic, spells, reagents and spellcasting.
- Items, equipment and inventory.
- NPCs, monsters, vendors and AI.
- Crafting, gathering and resource systems.
- Taming, pets and mounts.
- Housing and property ownership.
- Banking, trading and the economy.
- Guilds, notoriety, criminal systems and PvP.
- Death, resurrection and looting.
- World persistence and character saves.
- Facet-specific gameplay rules.
- Other original Ultima Online gameplay systems supported by the selected ModernUO version.

Audit the actual ModernUO implementation and content packs before claiming that any particular system is available or complete.

Prefer extending existing systems rather than replacing them.

Maintain server modifications in clearly isolated modules or patches, allowing upstream ModernUO updates to be incorporated.

### 1.2 Client: Godot 4

Use Godot 4 as the preferred engine for the final game client.

The client must provide:

- Fully three-dimensional environments.
- Modern third-person character movement.
- Freely controllable camera.
- Stylised fantasy graphics.
- Smooth character animations.
- Modern lighting and environmental effects.
- Interactive buildings and interiors.
- Modern inventory and character interfaces.
- Support for keyboard, mouse, gamepad and touchscreen controls.
- Adaptable graphics settings for different hardware.

Use GDScript for portable gameplay presentation and interface code where appropriate. Native extensions may be used for performance-critical components.

The server and client must remain separate applications communicating through a well-defined network protocol.

### 1.3 Supported platforms

Architect the client for:

- Windows
- macOS, including Apple Silicon
- Linux
- Android phones and tablets
- iPhone and iPad

Prioritise Windows development and testing initially, followed by Android.

Do not introduce Windows-only dependencies into shared game code.

Account for iOS build, signing and platform-specific testing requirements.

All platforms must ultimately connect to the same persistent game server.

### 1.4 Art direction

Use a cohesive, stylised-fantasy aesthetic.

The target is a beautiful modern fantasy RPG, not photorealism and not an intentionally primitive low-poly game.

Use free, legally reusable artwork wherever possible.

Investigate resources including Quaternius, Kenney, Poly Haven, suitable Fab assets and Mixamo.

Record licenses and provenance for every imported asset.

Develop automated tools for asset importing, classification, material assignment, collision generation, optimisation and cataloguing.

AI-generated assets may be used where technically appropriate, subject to quality control and usage rights.

Avoid introducing paid assets without explicit approval.

---

# 2. Geographical fidelity: all Ultima Online facets

The ultimate objective is a geographically faithful three-dimensional recreation of the original Ultima Online worlds.

Support:

- Felucca
- Trammel
- Ilshenar
- Malas
- Tokuno Islands
- Ter Mur
- Additional facets or custom worlds where appropriate

Preserve the original geographical relationships, including:

- Town and city locations.
- Roads, rivers, coastlines and mountains.
- Forests, swamps and deserts.
- Buildings and their positions.
- Dungeons and underground environments.
- Bridges, staircases, caves and entrances.
- Static decorations and world objects.
- Terrain elevations.
- Original coordinates and facet identities.

Do not randomly redesign Britannia.

Any changes required for third-person playability must be explicit, documented and reversible where feasible.

Maintain a canonical source-world representation and a separate rendered-world representation.

---

# 3. World Conversion Studio

Develop a standalone, reusable application named UO World Studio.

Its purpose is to read original Ultima Online data and automatically reconstruct it as a modern 3D world.

## 3.1 Supported source formats

Investigate and implement support for relevant versions of:

- map*.mul
- statics*.mul
- staidx*.mul
- tiledata.mul
- art.mul and artidx.mul
- hues.mul
- multi.mul and multi.idx
- radarcol.mul
- Relevant UOP archives
- Relevant patch and override formats

Investigate existing open-source parsers and editors, including ClassicUO-related libraries, CentrED# and UO map tools.

Reuse suitable libraries when technically and legally appropriate.

Do not redistribute proprietary Ultima Online assets.

## 3.2 Intermediate world representation

Create an engine-independent world data format.

It must contain:

- Facet identification.
- Original coordinates.
- Terrain tile identifiers.
- Terrain elevations.
- Static object identifiers and positions.
- Object classifications and metadata.
- Multi-component structures.
- Source references.
- Conversion overrides.
- Version information.

The format must support deterministic conversion and partial regeneration.

## 3.3 Terrain generation

Convert original UO terrain into actual 3D geometry.

Requirements:

- Preserve terrain elevations and geographical layout.
- Generate chunked terrain meshes.
- Assign materials according to terrain classification.
- Reconstruct coastlines and water surfaces.
- Support roads, paths, cliffs and slopes.
- Generate suitable collision geometry.
- Support world streaming and different levels of detail.
- Avoid visible seams between adjacent chunks.

Do not assume original UO elevation units correspond directly to real-world metres.

Create configurable, consistent coordinate transformations.

## 3.4 Building reconstruction

Analyse original static tile placements to reconstruct three-dimensional architecture.

Detect and classify:

- Walls and wall orientations.
- Doors and windows.
- Floors and ceilings.
- Roof structures.
- Staircases.
- Multiple storeys.
- Bridges and elevated walkways.
- Interior and exterior decorations.

Use modular 3D assets to replace original tile representations.

Preserve building footprints and geographical placement.

Generate appropriate collisions and navigable interiors.

When automatic reconstruction is ambiguous, use explicit rules, confidence reporting and persistent manual overrides.

Do not silently invent unsupported architectural details.

## 3.5 Asset mapping system

Create a mapping database connecting original UO tile IDs and object classifications to modern 3D assets.

Support:

- One-to-one asset mapping.
- Multiple visual variants.
- Procedural material variations.
- Orientation and scaling rules.
- Asset grouping.
- Biome-specific variations.
- Missing-asset placeholders.
- Confidence and completeness reporting.

The same source world must always generate equivalent geometry when the same configuration and assets are used.

## 3.6 World Studio interface

Eventually provide a visual application allowing the user to:

- Select a UO installation.
- Choose a facet.
- Choose a geographical region.
- Preview original terrain and static placements.
- Preview the converted 3D environment.
- Inspect and correct asset mappings.
- Regenerate selected regions.
- Export the world for Godot.
- Inspect conversion errors and missing assets.

Prioritise functional conversion and navigation before building a sophisticated editor interface.

---

# 4. ModernUO integration

The new client must interact with the existing ModernUO server.

Study ModernUO's networking and ClassicUO's client-side implementation.

Implement or adapt the necessary networking functionality for:

- Login and authentication.
- Server and character selection.
- Character spawning.
- Movement.
- Nearby entity replication.
- Items and containers.
- Combat.
- Spellcasting.
- Skills and attributes.
- NPC interaction.
- Trading and vendors.
- Housing.
- Chat and social systems.
- World transitions.

Do not rewrite the server simulation in the client.

The server must remain authoritative.

## 4.1 Compatibility strategy

Initially preserve ModernUO's existing gameplay protocol and rules wherever possible.

Build a compatibility layer allowing the 3D client to communicate with ModernUO.

Determine whether direct protocol implementation or a lightweight adapter is preferable through a working proof of concept.

Avoid introducing unnecessary infrastructure.

## 4.2 Third-person movement

This is a major technical challenge and must be investigated carefully.

Original UO uses tile-oriented movement, discrete elevations and server-authoritative movement validation.

The new client requires smooth third-person presentation.

Initially implement:

- Smooth client-side animation.
- Movement interpolation.
- Consistent coordinate transformations.
- Server-authoritative position validation.
- Appropriate collision and path constraints.
- Synchronisation with other players and NPCs.

Do not assume continuous Skyrim-style physics can be introduced without changes to server movement, combat range, line of sight and pathfinding.

Preserve original mechanics initially.

Develop an explicit extension strategy for any future continuous movement, jumping, swimming, climbing or advanced physics.

## 4.3 Server modifications

Where ModernUO requires extensions for 3D gameplay:

- Identify the exact limitation.
- Prefer small, isolated changes.
- Maintain backward compatibility where practical.
- Write regression tests.
- Document protocol changes.
- Avoid modifying core gameplay algorithms unless necessary.

Investigate whether classic UO clients and the new 3D client can coexist on the same server.

Interoperability is a desirable goal, but it must be demonstrated rather than assumed.

---

# 5. Visual gameplay and interface

Implement a modern third-person MMORPG presentation.

Core requirements include:

- Third-person camera and character controller.
- Character models and equipment.
- Walking, running and combat animations.
- Spellcasting visual effects.
- Inventory and equipment interface.
- Skill and attribute windows.
- Container interaction.
- Item pickup and placement.
- Target selection.
- NPC dialogue and vendor interaction.
- Hotbars and shortcuts.
- Minimap and world map.
- Environmental audio.
- Day/night cycle.
- Weather and atmospheric effects.

Preserve the complexity and freedom of Ultima Online rather than simplifying the underlying game mechanics.

Develop responsive UI layouts for desktop, tablet and phone.

Mobile controls must be designed intentionally, not produced by simply shrinking the desktop interface.

---

# 6. Autonomous development workflow

The user wants minimal involvement.

You must take responsibility for routine engineering decisions.

For each milestone:

1. Inspect the current repository and existing implementation.
2. Determine what already works.
3. Identify missing functionality.
4. Write or update a short implementation plan.
5. Implement the feature.
6. Build the relevant components.
7. Run automated tests.
8. Execute integration tests where possible.
9. Fix failures.
10. Record the result.
11. Commit coherent changes when appropriate.
12. Update the project roadmap.

Do not repeatedly generate disconnected demos.

Every prototype must contribute to the final architecture or be explicitly marked as disposable.

Do not claim success merely because code compiles.

Validate actual functionality.

Do not delete or overwrite useful existing work without first examining it.

If a dependency or asset is unavailable, implement a clearly identified fallback and continue wherever practical.

Ask the user only when a decision genuinely requires human judgement, credentials, proprietary source files or financial approval.

Do not make purchases, accept licenses on the user's behalf, publish software or perform irreversible actions without approval.

---

# 7. Development milestones

## Milestone 0: Repository audit

Immediately inspect the existing project.

Identify:

- Current architecture.
- Implemented features.
- Existing demonstrations.
- Source dependencies.
- Build status.
- Tests.
- Technical debt.
- Reusable code.
- Missing components.

Produce a concise audit and revise the roadmap accordingly.

Do not restart from scratch unless there is a compelling technical reason.

## Milestone 1: Authentic UO data conversion

Read genuine UO terrain and static data.

Generate a small section of Britain in Trammel.

Validate terrain coordinates, elevations and object placements.

Provide an interactive 3D preview.

If genuine files are not yet available, use synthetic fixtures for parser tests, but do not present synthetic terrain as a successful Britannia conversion.

## Milestone 2: ModernUO server integration

Install and configure a local ModernUO development server.

Verify operation using an established UO client.

Build the minimum networking functionality required for our Godot client to authenticate and enter the world.

## Milestone 3: First playable multiplayer demonstration

Deliver a working 3D client connected to ModernUO.

Acceptance criteria:

- User can launch the client.
- User can log into ModernUO.
- User can select a character.
- Character appears at the correct world coordinates.
- User can move through the 3D environment.
- Server validates movement.
- Other connected players can observe movement.
- At least one world interaction works.

This is the first major project milestone.

## Milestone 4: Automated world reconstruction

Improve terrain generation and static object conversion.

Add modular buildings, vegetation, roads, water, stairs, doors and interiors.

Create a reusable asset-mapping catalogue.

## Milestone 5: Core gameplay presentation

Implement inventory, equipment, skills, combat, spells, targeting, NPCs, containers and item interactions.

Reuse ModernUO's existing gameplay logic.

## Milestone 6: Full facet conversion

Expand from the initial Britain test region to the complete Trammel map.

Then support Felucca, Ilshenar and the remaining facets.

Introduce efficient world streaming and region-based generation.

## Milestone 7: Cross-platform clients

Implement and validate Windows, macOS, Linux, Android and iOS/iPadOS builds.

Optimise graphics, controls, memory usage and streaming for mobile devices.

## Milestone 8: Visual polish and advanced features

Improve characters, animation, lighting, weather, environments, interface and audio.

Investigate advanced third-person movement and other modern gameplay enhancements without unnecessarily compromising original UO mechanics.

## Milestone 9: Production readiness

Implement security hardening, performance profiling, server administration, backups, update distribution, monitoring, load testing and release procedures.

---

# 8. Documentation and project continuity

Maintain the following documents inside the repository:

- `docs/MASTER_PLAN.md`
- `docs/ARCHITECTURE.md`
- `docs/ROADMAP.md`
- `docs/PROGRESS.md`
- `docs/DECISIONS.md`
- `docs/WORLD_CONVERSION.md`
- `docs/MODERNUO_INTEGRATION.md`
- `docs/ASSET_PIPELINE.md`
- `docs/TESTING.md`
- `docs/LEGAL_AND_LICENSES.md`

Keep these documents concise, accurate and current.

The roadmap must distinguish:

- Completed and tested functionality.
- Implemented but unverified functionality.
- Work in progress.
- Planned work.
- Known limitations and blockers.

Maintain clear acceptance criteria for every milestone.

At the end of each development session, update progress so another Codex session can resume without requiring the user to explain the project again.

---

# 9. Legal and licensing requirements

ModernUO, ClassicUO, associated libraries and third-party assets may have different licenses.

Audit the exact repositories and versions before integrating their code.

Respect applicable open-source obligations.

Do not assume open-source emulator licensing grants rights to distribute original Ultima Online artwork, maps, trademarks or other proprietary content.

Keep proprietary source files outside public repositories.

Design the converter to operate on locally supplied game files.

Record dependencies, licenses and asset provenance.

Flag any legal issues requiring human review before public distribution.

---

# 10. Immediate instructions

You are continuing an existing development project.

Do not begin by creating another unrelated demonstration.

First:

1. Inspect the entire current repository and existing work.
2. Identify the most recent functioning prototype.
3. Determine whether the current codebase can support the architecture described above.
4. Inspect the current ModernUO and ClassicUO projects and relevant UO parsing libraries.
5. Recommend the smallest necessary architectural adjustments.
6. Create or update the master development documentation.
7. Establish a reproducible build and test workflow.
8. Continue toward the first genuinely playable 3D client connected to ModernUO.

The user is currently installing Ultima Online and will provide access to original game files when available.

Until then, continue with tasks that do not require those files.

**Your priority is to deliver a real, integrated, progressively improving product with as little manual intervention from the user as possible.**

Begin the repository audit and implementation immediately. Report concrete results, blockers and the next milestone, not merely general recommendations.