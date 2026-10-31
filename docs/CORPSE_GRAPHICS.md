# Static cadaver graphics

Owner direction: supply a cadaver for every completed body and every future model, visible in the graphics-ID catalogue. Keep creature work progressing.

## Identity and presentation

Native corpses use **graphic 0x2006 (8198)**. The item's **amount selects the original body ID**; hue remains the raw native hue, including partial-hue bits. Per-species graphic IDs must not be invented or overwrite unrelated static art. Catalogue keys such as `corpse-0190` distinguish variants; they are not new network graphic IDs.

`Viewer/Presentation/CorpseModels.gd` discovers available male/female humans, equines, distinct mounts, bovines and accepted generic creatures from their runtime registries. It evaluates the final Death/death frame, disables living contact/modifiers, freezes visible skinned surfaces and rigid fittings into static meshes, retains materials/UVs/indices and places the deformed underside on the floor. Reins and transient death-effect meshes are omitted. The returned cadaver has no skeleton or animation player. No original mesh/rig/input is modified. Corpses are built on demand; the ignored browser output holds previews and variant metadata, not a distributable model pack.

World items, inspect previews and parameterised static records use that same builder. Static records require `id:8198` and `body` (or `amount`), plus optional hue/direction; original static records without a body keep their existing fallback. Existing developer-placement messages that carry only a graphic number cannot choose a corpse species. The graphics browser lists the required body parameter explicitly.

Native 0x89 corpse equipment contains layer-plus-one and item serials, not model IDs. The client resolves those serials against native container items, preserving worn graphic/hue and cosmetic layers. Server-confirmed looting removes the corresponding rendered garment. Unknown/unavailable bodies retain the generic fallback. Available artwork does not override server death refusal, summoned-creature corpse suppression or loot permissions.

0xAF starts a temporary generic-creature Death visual that survives mobile removal, holding the final native corpse hidden until playback ends. The victim's last native facing is cached for the corpse; optional legacy 0x1A direction is also decoded. The pinned server's F3 byte 10 is reserved, not facing. Summoned actors can announce a transient corpse in 0xAF and delete it during native OnDeath; that is distinct from a surviving corpse.

## Catalogue and repeatable checks

- Run `scripts/build-corpse-catalogue.ps1 -Render`; review `Reviews/Review-Corpses.cmd` or ignored `outputs/corpses/index.html`.
- JSON/JS list canonical graphic, unique variant key, body/amount, provider, compatibility status, death clip, bounds and preview. All generated art/data stay ignored.
- The existing item catalogue includes a **Corpses** tab. `scripts/build-item-catalog.ps1` refreshes its corpse browser too.
- `scripts/test-creatures.ps1` rebuilds/checks corpse coverage after each accepted batch. Candidate cadavers are checked before their runtime routes are accepted. Newly accepted bodies appear automatically; missing Death poses fail the complete-catalogue check rather than silently producing living statues.
- Direct offline tests: Godot `--headless --path Viewer --script res://Presentation/CorpseCatalogue.gd`, `WorldItemTests.gd`, `CreatureDeathTests.gd` and the existing bovine/distinct-mount/equine checks. These are not native gameplay evidence.
- Native checks: existing approved disposable two-client harness `scripts/test-horses.ps1 -Live -SkipContact -CreatureFamily <family>`, port 2594. Production and saves remain untouched.

Initial rendered catalogue: **135 available body variants**, **1,266 checks**, **zero failures**, including final skinned/baked bounds within 0.2 mm, finite geometry, floor placement, original body/hue, no live skin bindings and future-registry discovery. World-item packet tests: **95/95**, including actual robe geometry, layer decoding, dye retention, looting equipment-cache removal, playback visibility holds and parameterised static placement. Generic death-transition packet tests: **68/68**. Broader native/regression evidence remains recorded separately in `CREATURE_MONSTERS.md` and ignored per-family reports.

Scope limits: final death poses inherit the current source/authored animation quality; terrain fitting uses the corpse's local support plane, not arbitrary multi-point ragdolls. Human wardrobe support remains bounded by existing wearable coverage. Catalogue presence is not an all-actions, all-modern-bodies, final-art or asset-distribution claim. Original/derived local art retains its existing provenance and exclusion rules.
