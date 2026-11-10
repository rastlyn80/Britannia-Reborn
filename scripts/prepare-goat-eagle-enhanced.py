# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the fitted Goat and Eagle source groups and their local trial evidence."""

SPRITES = {
    209: {
        25: ("GoatQuietStand", 55, "968ce06d41397a4479d1f119b56559b52cab1f08ccf1f6a0ea9a21354377b127"),
        26: ("GoatLoweredHornCheck", 65, "8920c6249daa1648d7a29e69e214d777ed460e4c79916200c137cb27b00733bf"),
    },
    5: {
        4: ("EagleWingBeat", 40, "62810b944bc8c13ada21054c7e898afd2cd4d98f34c51522c3863d7f188f8251"),
        25: ("EagleQuietWatch", 55, "d07cb892de557051da35e9cfd0495998c3aa33744e78b1b9ced643a77350fe08"),
        26: ("EagleGlance", 50, "94997bc756e9fca813e80016e171ed7f0e99143e457063ca94c3b7ff2d1e1d83"),
    },
}
TYPES = (2, 5, 8, 11, 14, 15)
FORMS = {
    "goat": ("Goat", 209, 0x455, {4: "LookSide", 5: "Attack", 6: "Attack2"}),
    "eagle": ("Eagle", 5, 0x8035, {4: "Alert", 5: "Attack", 6: "Attack2"}),
}
FALLS = {"ground": "Death", "air": "AirDeath", "explicit_air": "AirDeath", "hopping": "AirDeath"}


def prepare_goat_eagle(root, source, common, runtime_folder=None):
    sha, read = common["sha"], common["read"]
    viewer = root / "Viewer"
    work = root / "work/creatures"
    scenes = work / "native-form-audit/enhanced-source-gaps/goat-eagle"
    source_tables = common["source_tables"]
    groups = source_tables(root, source, {209: SPRITES[209]}, TYPES)
    groups.update(source_tables(root, source, {5: SPRITES[5]}, TYPES, flight_fallback=True))
    candidate = read(scenes / "goat-eagle-candidate.json")
    render = read(scenes / "motion-render-receipt.json")
    assert candidate["test_sha256"] == sha(root / "scripts/test-goat-eagle-enhanced.gd")
    assert candidate["bodies"].keys() == render.keys() == {"5", "209"}
    rows, copies = {}, {}
    for body, table in groups.items():
        result = candidate["bodies"][str(body)]
        fitted = render[str(body)]
        clips = [clip for clip, _, _ in SPRITES[body].values()]
        grounded = [clip for clip in clips if clip != "EagleWingBeat"]
        names = ("original", "rounded", "modern") if body == 209 else ("modern",)
        expected = (144, 108, 930) if body == 209 else (48, 36, 620)
        assert (result["routes"], result["classic_comparisons"], result["terrain_poses"]) == expected
        assert result["corpse_hues"] == 3 and all(gap > .0019 for gap in result["gaps"].values())
        assert fitted["scene_sha256"] == result["scene_sha256"]["modern"]
        assert fitted["minimum_foreground_box_pixels"] > 300
        if body == 209:
            assert result["geometry"]["horn_drop"] > .25 and not result["handoffs"]
            assert result["flight_fallback_checks"] == 0
        else:
            clips.append("AirEagleWingBeat")
            assert result["flight_fallback_checks"] == 15
            flight = result["geometry"]["AirEagleWingBeat"]
            assert flight["maximum_wing"] - flight["minimum_wing"] > .70
            assert flight["lowest_beak"] < -.14 and result["gaps"]["AirEagleWingBeat"] > .24
            assert len(result["handoffs"]) == 20
            for case, clip in FALLS.items():
                examples = [row for row in result["handoffs"] if row["case"] == case]
                assert len(examples) == 5 and all(row["clip"] == clip for row in examples)
                assert all(row["jump"] < .002 and row["minimum_gap"] > -.003 for row in examples)
        assert set(fitted["clips"]) == result["gaps"].keys() == set(clips)
        assert fitted["poses"] == 6 * len(clips)
        assets = {name: scenes / f"{body}-{name}.scn" for name in names}
        row, body_copies = common["fitted_row"](viewer, body, table, grounded, assets, result["scene_sha256"])
        if body == 5:
            row["flight_falls_back_to_combat"] = True
        rows[str(body)] = row
        copies.update(body_copies)
    native = work / "native-goat-eagle-enhanced/goat-eagle-native.json"
    verify_native(root, native, scenes, candidate, groups, common, runtime_folder or viewer / "Presentation")
    return rows, copies, sha(native)


def verify_native(root, path, scenes, candidate, groups, common, runtime_folder):
    sha, read = common["sha"], common["read"]
    native = read(path)
    receipt = read(path.with_name("goat-eagle-native-runtime.json"))
    assert sha(path) == receipt["report_sha256"].lower()
    assert sha(root / "Server/runtime/Server.dll") == receipt["server_sha256"].lower()
    assert sha(root / "Server/runtime/Assemblies/UOContent.dll") == receipt["content_sha256"].lower()
    assert native["test_sha256"] == sha(path.with_name("NativeGoatEagleLive.gd"))
    assert native["inputs_sha256"] == candidate["test_sha256"]
    viewer = root / "Viewer/Presentation"
    assert native["dispatcher_sha256"] == sha(viewer / "EnhancedCreatureActions.gd")
    shadow = scenes / "EagleVisual.gd"
    fall = scenes / "DisplayedCreatureFallPlayback.gd"
    shadow_path = "res://../" + fall.relative_to(root).as_posix()
    shadow_code = shadow.read_text(encoding="utf-8")
    assert shadow_code.count(shadow_path) == 1
    assert shadow_code.replace(shadow_path, "res://Presentation/DisplayedCreatureFallPlayback.gd") == (
        runtime_folder / "EagleVisual.gd"
    ).read_text(encoding="utf-8")
    assert fall.read_text(encoding="utf-8") == (runtime_folder / fall.name).read_text(encoding="utf-8")
    assert native["fall_renderers"] == {"displayed": sha(fall), "base": sha(viewer / "CreatureFallPlayback.gd")}
    assert native["renderers"] == {"goat": sha(viewer / "SourceEnhancedFieldVisual.gd"), "eagle": sha(shadow)}
    assert native["checks"] == 284 and native["records"].keys() == FORMS.keys()
    expected_cases = {(flags, kind, variant) for flags in (0, 64) for kind in TYPES for variant in (0, 1, 255)}
    for form, record in native["records"].items():
        name, body, hue, swings = FORMS[form]
        assert record["class"] == name and record["hue"] == 0 and record["stock_weapon"] == "Fists"
        assert record["can_move"] and record["corpse_body"] == body and record["corpse_hue"] == hue
        assert record["corpse"] >= 0x40000000
        phase, = record["phases"]
        assert phase["body"] == body and phase["asset_sha256"] == candidate["bodies"][str(body)]["scene_sha256"]["modern"]
        assert len(phase["cases"]) == len(expected_cases)
        assert {(case["flags"], case["type"], case["variation"]) for case in phase["cases"]} == expected_cases
        for case in phase["cases"]:
            kind, variant = str(case["type"]), case["variation"]
            mode = "0" if case["flags"] else "1"
            choices = groups[body][mode].get(kind, groups[body]["0"][kind])
            assert case["classic"] == ""
            assert case["enhanced"] == (choices[variant % len(choices)] if variant <= 127 else "")
        swing = record["swing"]
        packet = swing["packet"]
        assert packet["protocol"] == "classic" and packet["body"] == body and packet["serial"] == record["serial"]
        assert swing["clip"] == swings[packet["action"]]
        flight = record["flight"]
        if body == 5:
            assert flight["rendered"] == "AirEagleWingBeat" and flight["landed"] == "EagleGlance"
            assert flight["strike"] in phase["cases"] and flight["glance"] in phase["cases"]
        else:
            assert not flight
