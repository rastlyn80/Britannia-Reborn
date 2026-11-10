# SPDX-License-Identifier: GPL-3.0-or-later
"""Seal the fitted Hound and Black Bear actions against official and native evidence."""

SPRITES = {
    217: {
        4: ("HoundBowSnap", 35, "d6d3b090b2a81836734b997c7ba5b47cc9786de616cd245c43830634c6dbdb02"),
        15: ("HoundRearBark", 35, "dfcab4b7a0a7cb9e956c0560196bd2e321e1ba61fe56aa67efaf2e7f8281b7bc"),
        25: ("HoundQuietStand", 50, "106c23d37399c03a828ca4c14a26be3d7c4ea3f984acf46c52de702040ac3181"),
        26: ("HoundScentCheck", 55, "843af28966cc2f25d81120a3b632d70a4f0ef0b049aa496fb59bc96ef3631f80"),
        27: ("HoundTailCheck", 35, "d478c8eabb0dce0f07092a4cc66140edd4af7b1053f12b907bcbdcdfbf38601d"),
        28: ("HoundAlert", 30, "10f1611919fae0401a49a1e4614dd88cbf7f82ae48b357c04d2546244717a8fd"),
    },
    211: {
        4: ("BlackBearHighSwipe", 40, "5962b1d797914fc0e35d687eac03410cedf4c92b5d45a15281f437a8a655136c"),
        15: ("BlackBearUprightWarning", 30, "7e6d6948bda8895e73c4e677b10063e5f3f23867c2977cc8e877ded3a383687c"),
        23: ("BlackBearWakeAndRise", 50, "6eb0dfd721c16c3004e5634d7a271356b03e931abd33d88d6cb92854706e899f"),
        25: ("BlackBearQuietStand", 50, "534ea186ec211f9bc8b8714f987f0361baa40eaab8dd9daf9fb869de1f9035cf"),
        26: ("BlackBearScentTurn", 55, "65e87c5825990a07ba740ef8bfe946d657cafe7cf3878ce4d3a9af1bd369e12a"),
        27: ("BlackBearRaisedGuard", 40, "6898768ff0e744260260e1d6f0a18c860dc8e59f07a53a07c5720a8ed2402793"),
        28: ("BlackBearRearAlert", 40, "60e2482d0b9f9ca5a3ae3421b4951a0b5d0d101d5abc481d40c83530d2f1a0af"),
    },
}
TYPES = (2, 5, 8, 11, 14, 15)
FORMS = {
    "dog": ("Dog", 217), "black-bear": ("BlackBear", 211), "grobu": ("Grobu", 211),
    "enraged-black-bear": ("EnragedBlackBear", 211),
}


def prepare_hound_bear(root, source, common):
    sha, read = common["sha"], common["read"]
    viewer = root / "Viewer"
    work = root / "work/creatures"
    scenes = work / "native-form-audit/enhanced-source-gaps/hound-black-bear"
    group_tables = common["source_tables"](root, source, SPRITES, TYPES)
    candidate = read(scenes / "hound-bear-enhanced-candidate.json")
    assert candidate["test_sha256"] == sha(root / "scripts/test-hound-bear-enhanced.gd")
    assert candidate["bodies"].keys() == {"211", "217"}
    rows, copies = {}, {}
    for body, groups in group_tables.items():
        result = candidate["bodies"][str(body)]
        clips = [clip for clip, _, _ in SPRITES[body].values()]
        assert (result["routes"], result["classic_comparisons"], result["corpse_hues"]) == (144, 108, 3)
        assert result["terrain_poses"] == 465 * len(clips)
        assert result["gaps"].keys() == set(clips) and all(gap >= .0019 for gap in result["gaps"].values())
        geometry = result["geometry"]
        assert geometry["hind_drift"] < .004
        if body == 217:
            assert geometry["paw_height"] > .55 and geometry["bow_chest_drop"] > .025
        else:
            assert geometry["paw_height"] > 1.3 and geometry["paw_span"] > 1.2
        assets = {name: scenes / f"{body}-{name}.scn" for name in ("original", "rounded", "modern")}
        row, body_copies = common["fitted_row"](viewer, body, groups, clips, assets, result["scene_sha256"])
        rows[str(body)] = row
        copies.update(body_copies)
    path = work / "native-hound-bear-enhanced/hound-bear-native.json"
    verify_native(root, path, candidate, group_tables, common)
    return rows, copies, sha(path)


def verify_native(root, path, candidate, groups, common):
    sha, read = common["sha"], common["read"]
    folder = path.parent
    native = read(path)
    receipt = read(folder / "hound-bear-native-runtime.json")
    assert sha(path) == receipt["report_sha256"].lower()
    assert sha(root / "Server/runtime/Server.dll") == receipt["server_sha256"].lower()
    assert sha(root / "Server/runtime/Assemblies/UOContent.dll") == receipt["content_sha256"].lower()
    assert native["test_sha256"] == sha(folder / "NativeHoundBearLive.gd")
    assert native["inputs_sha256"] == candidate["test_sha256"]
    presentation = root / "Viewer/Presentation"
    assert native["dispatcher_sha256"] == sha(presentation / "EnhancedCreatureActions.gd")
    assert native["renderers"] == {"field": sha(presentation / "SourceEnhancedFieldVisual.gd")}
    assert native["checks"] == 283 and native["records"].keys() == FORMS.keys()
    for form, record in native["records"].items():
        name, body = FORMS[form]
        assert record["class"] == name and record["corpse_body"] == body and record["corpse"] >= 0x40000000
        if form == "dog":
            assert record["hue"] in range(2301, 2319)
        else:
            assert record["hue"] == (0x455 if form == "grobu" else 0)
        phase, = record["phases"]
        assert phase["body"] == body and phase["asset_sha256"] == candidate["bodies"][str(body)]["scene_sha256"]["modern"]
        kinds, variants = (TYPES, (0, 1, 255)) if form in ("dog", "black-bear") else ((5,), (1,))
        expected = {(flags, kind, variant) for flags in (0, 64) for kind in kinds for variant in variants}
        assert len(phase["cases"]) == len(expected)
        assert {(case["flags"], case["type"], case["variation"]) for case in phase["cases"]} == expected
        for case in phase["cases"]:
            kind, variant = str(case["type"]), case["variation"]
            mode = "0" if case["flags"] else "1"
            choices = groups[body][mode].get(kind, groups[body]["0"][kind])
            assert case["classic"] == ""
            assert case["enhanced"] == (choices[variant % len(choices)] if variant <= 127 else "")
