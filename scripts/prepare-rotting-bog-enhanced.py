# SPDX-License-Identifier: GPL-3.0-or-later
"""Seal the exact Enhanced groups for Rotting Corpse and Bog Thing."""

MEMBERS = {155: "0x29e342164e92e540", 780: "0x535b1e5dfab48d7b"}
SPRITES = {
    155: {
        11: ("RottingCorpseCradle", 50, "de12489651e753d0c15f4806ae23d3c9e5c08f8ceffe96b34bad16e9545989ea"),
        15: ("RottingCorpseSkullShield", 35, "4dabb985fd8fd334eeac2f4a80e166a474f39856887f3a33629b66b2fc8439d6"),
        23: ("RottingCorpseUncurl", 50, "6b2eafaf6b8f5ad73069058b2af79703246a7cc3f98072c7dd30beafb1f4c4d1"),
        26: ("RottingCorpseStrayReach", 50, "8da177217539cbc92352f6775b5a3c4beba1806876bda6c05c9fcc2992aaa725"),
        27: ("RottingCorpseRaggedFlail", 50, "c2b136881cd85de18598d455b4a9a849719da143e7a25552b83054c2d9c26254"),
        28: ("RottingCorpseThreatStep", 45, "e0eef78eee4ee20df7af77e56a1401c2e3927f637fe6ba911422b039c52a1900"),
    },
    780: {
        4: ("BogThingMawSnap", 35, "4f010f617930ef354449eada2b324c7f44a992d1f81ba161b5dc4ce6a7bbcd23"),
        23: ("BogThingSprout", 45, "d3e68497854c64b7ecf7408bf92f20b45ff6bb6ed79023ee9ff0542075a0e07d"),
        25: ("BogThingQuietMaw", 60, "68bd435d240b1c2d020218254b2b01f46bd253d0aa2e30272f187ff3d2b4b6a2"),
        26: ("BogThingMawTaste", 40, "ba54130070dbaf0c45a8586da81dceff4df0a6d752aa1cd154aa71bc9c587aef"),
        27: ("BogThingRaisedBranches", 55, "867dbcb41a10558bd0879feb0e14e2cd7da4230c1a520d86ead1345ec443b583"),
        28: ("BogThingAlertBend", 35, "ef43c67b73ab9c6acf01c0735f2513a7ebd0fa6fb59f2ecd95ed953430a04b75"),
    },
}
TYPES = {155: (2, 5, 8, 14, 15), 780: (5, 8, 11, 14, 15)}
TEST = "test-rotting-bog-enhanced.gd"
FORMS = {
    "rotting": ("RottingCorpse", 155, 0, 0x8035, "MeleeAI", "SourceEnhancedRottingCorpseVisual.gd"),
    "mummy": ("UnfrozenMummy", 155, 0x480, 0x455, "MageAI", "SourceEnhancedRottingCorpseVisual.gd"),
    "bog": ("BogThing", 780, 0, 0x8035, "MeleeAI", "SourceEnhancedBogThingVisual.gd"),
    "tangle": ("Tangle", 780, 0x21, 0x455, "MeleeAI", "SourceEnhancedBogThingVisual.gd"),
}


def prepare_rotting_bog(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    stage = staged or root
    folder = root / "work/creatures/native-form-audit/enhanced-source-gaps/rotting-corpse-bog-thing"
    receipt = read(folder / "terrain-receipt.json")
    assert digest(stage / "scripts" / TEST) == digest(folder / TEST) == receipt["test_sha256"]
    terrain = receipt["bodies"]
    render = read(folder / "motion-render-receipt.json")
    dense = read(folder / "dense-geometry-receipt.json")
    assert dense["sample_rate"] == 240
    assert terrain.keys() == render.keys() == dense["bodies"].keys() == {str(body) for body in SPRITES}
    groups, rows, copies = {}, {}, {}
    for body, slots in SPRITES.items():
        clips = [clip for clip, _, _ in slots.values()]
        groups.update(common["source_tables"](root, source, {body: slots}, TYPES[body], member_hashes=MEMBERS))
        key = str(body)
        motion, views, measurements = terrain[key], render[key], dense["bodies"][key]
        assert (motion["poses"], motion["falls"], motion["routes"], motion["classic"]) == (2790, 180, 120, 90)
        expected = (15, 2790, 30) if body == 780 else (0, 0, 0)
        assert (motion["growth_recoveries"], motion["prop_poses"], motion["classic_continuations"]) == expected
        assert min(motion["gap"], motion["fall_gap"]) >= (-.0008 if body == 780 else .0018)
        assert motion["jump"] < .002 and views["scene_sha256"] == motion["hashes"]["modern"]
        assert views["poses"] == 60 and set(views["clips"]) == set(clips)
        assert views["minimum_foreground_box_pixels"] >= (9 if body == 780 else 4900)
        assert measurements.keys() == motion["hashes"].keys() == {"original", "rounded", "modern"}
        for treatment, measurement in measurements.items():
            assert measurement["scene_sha256"] == motion["hashes"][treatment]
            assert measurement["clips"].keys() == set(clips)
            assert sum(clip["samples"] for clip in measurement["clips"].values()) == (1467 if body == 780 else 1409)
            assert max(clip["unsupported_gap"] for clip in measurement["clips"].values()) < .0005
            if body == 780:
                sprout = measurement["clips"]["BogThingSprout"]
                assert .08 < sprout["first_height"] < .20 and sprout["last_height"] > 1.8
        assets = {name: folder / f"{body}-{name}.scn" for name in sorted(motion["hashes"])}
        rows[key], local = common["fitted_row"](root / "Viewer", body, groups[body], clips, assets, motion["hashes"])
        copies.update(local)
    return rows, copies, verify_native(root, stage, folder, groups, terrain, common)


def verify_native(root, stage, folder, groups, terrain, common):
    read, digest = common["read"], common["sha"]
    native_dir = root / "work/creatures/native-rotting-corpse-bog-thing-enhanced"
    path = native_dir / "rotting-corpse-bog-thing-native.json"
    native, runtime = read(path), read(native_dir / "rotting-corpse-bog-thing-native-runtime.json")
    fixture = native_dir / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert digest(file) == runtime[f"{key}_sha256"].lower()
    assert digest(native_dir / "NativeRottingBogLive.gd") == native["test_sha256"]
    assert digest(folder / TEST) == native["inputs_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["records"].keys() == FORMS.keys() and native["checks"] >= 420
    for form, record in native["records"].items():
        name, body, hue, corpse_hue, ai, renderer = FORMS[form]
        assert digest(stage / "Viewer/Presentation" / renderer) == native["renderers"][str(body)]
        assert (record["class"], record["hue"], record["stock_weapon"], record["ai"]) == (name, hue, "Fists", ai)
        assert record["can_move"] and not (record["tamable"] or record["can_swim"] or record["can_fly"])
        assert len(record["step_delta"]) == 2 and max(map(abs, record["step_delta"])) == 1
        assert record["corpse"] >= 0x40000000 and (record["corpse_body"], record["corpse_hue"]) == (body, corpse_hue)
        combat, loot = record["combat"], record["carved"]
        assert loot["gold"] > 0 and combat["target"] > 0
        if body == 780:
            assert loot["seed"]
        if form == "mummy":
            assert combat["damage"] > 0 and 1 <= combat["cast_attempts"] <= 4
        else:
            packet = combat["packet"]
            assert (packet["protocol"], packet["body"], packet["serial"]) == ("classic", body, record["serial"])
            assert packet["action"] in (4, 5, 6) and combat["clip"]
        if form == "rotting":
            poison = combat["poison"]
            assert poison["target"] == combat["target"] and poison["damage"] > 0 and poison["lethal"]
        if form == "bog":
            bogling = combat["bogling"]
            assert bogling["serial"] > 0 and bogling["body"] == 779 and bogling["healed"] > 0 and bogling["removed"]
        phase, = record["phases"]
        assert phase["body"] == body and phase["asset_sha256"] == terrain[str(body)]["hashes"]["modern"]
        cases = phase["cases"]
        expected = {(flag, kind, variant) for flag in (0, 64) for kind in TYPES[body] for variant in (0, 1, 255)}
        assert len(cases) == len(expected) and {(c["flags"], c["type"], c["variation"]) for c in cases} == expected
        for case in cases:
            mode = "0" if case["flags"] & 64 else "1"
            kind, variant = str(case["type"]), case["variation"]
            choices = groups[body][mode].get(kind, groups[body]["0"][kind])
            assert case["enhanced"] == (choices[variant % len(choices)] if variant <= 127 else case["classic"])
    return digest(path)
