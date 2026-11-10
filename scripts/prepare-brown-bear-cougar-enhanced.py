# SPDX-License-Identifier: GPL-3.0-or-later
"""Seal the fitted Brown Bear and Cougar against source frames and native trials."""

SPRITES = {
    167: {
        4: ("BrownBearHighSwipe", 40, "67b933f817ca411cb036392e714c7a90c4c153ff8ecb06d7b1b59ebc3bb05edb"),
        15: ("BrownBearUprightWarning", 30, "ba635ee4f1ca62f122b76501950c0257a4d5eecc1866ba62c0227af866a3b5db"),
        23: ("BrownBearWakeAndRise", 50, "b7485434d53bfee292f6d1e4d7d8ff60e3efd046c3c4b55715f69b4b3d234deb"),
        25: ("BrownBearQuietStand", 50, "e6f637207a0f9db2e132fa45873ba235628c9f61f0a3eed49bf099dc1fc85c81"),
        26: ("BrownBearScentTurn", 55, "4140d08b149fc825a166a95d4beba99c9c87883c0fbb28898d4b72d56faf884f"),
        27: ("BrownBearRaisedGuard", 40, "f6857dee363353f6988a2f64af34ffcf3482ada99f22158c9e49ab75ed7f2783"),
        28: ("BrownBearRearAlert", 40, "c84b838fb050e1cf3064e673cbc57accb89cb0c62a7370c91c1c631e46ec14e4"),
    },
    63: {
        4: ("CougarHighPawStrike", 45, "d310ff5220459be8a176619428a108d9ba928c7a09aaaf4fea07d45ff78e5730"),
        15: ("CougarLowFeint", 40, "41fadfc53f28567abeea6bbbb1bc4190d4ba2a21ccd9ca2612ff66e0701062e5"),
        23: ("CougarUncoilAndStretch", 50, "4a115f6f9606d6b6c6609df6f0ab6256bb3698f682f4736943909fc7aa97e0a1"),
        25: ("CougarQuietStand", 40, "e7b3aea647db7db1ce7b5b6f9c7d2bc0f8440f4e3d57ad1b831fc2485f9415eb"),
        26: ("CougarScentDip", 65, "c5cee6fd0c818d3280e0fca62ef5bf028cce050c6cbcce26c38d9cbead5c352c"),
        27: ("CougarTailFlick", 45, "0e02284ad3344c1104d05ae3e9c5d451eb24b3ed7f1e77083e10f2090482bd8e"),
        28: ("CougarLoweredAlert", 35, "180904095ad5a34fe8ccb2922d95806eaabf4a20a7fb115bacb81dad2df0353c"),
    },
}
TYPES = (2, 5, 8, 11, 14, 15)
FORMS = {
    "brown-bear": ("BrownBear", 167, 0x455, {4: "LookSide", 5: "BearRearStrike", 6: "Attack"}),
    "cougar": ("Cougar", 63, 0x8035, {5: "Attack", 6: "FelineRearSwipe"}),
}


def prepare_brown_bear_cougar(root, source, common):
    sha, read = common["sha"], common["read"]
    work = root / "work/creatures"
    viewer = root / "Viewer"
    scenes = work / "native-form-audit/enhanced-source-gaps/brown-bear-cougar"
    groups = common["source_tables"](root, source, SPRITES, TYPES)
    candidate = read(scenes / "brown-bear-cougar-candidate.json")
    assert candidate["test_sha256"] == sha(root / "scripts/test-brown-bear-cougar-enhanced.gd")
    assert candidate["bodies"].keys() == {"167", "63"}
    rows, copies = {}, {}
    for body, table in groups.items():
        result = candidate["bodies"][str(body)]
        clips = [clip for clip, _, _ in SPRITES[body].values()]
        assert (result["routes"], result["classic_comparisons"], result["corpse_hues"]) == (144, 108, 3)
        assert result["terrain_poses"] == 3255
        assert result["gaps"].keys() == set(clips) and all(gap >= .0019 for gap in result["gaps"].values())
        geometry = result["geometry"]
        assert geometry["hind_drift"] < .004 and geometry["rest_paw_reach"] > .25
        assert geometry["rest_chest_drop"] > (.28 if body == 167 else .11)
        if body == 167:
            assert geometry["paw_height"] > 1.30 and geometry["paw_span"] > 1.2
        else:
            assert geometry["paw_height"] > .60 and geometry["head_rise"] > .35
        assets = {name: scenes / f"{body}-{name}.scn" for name in ("original", "rounded", "modern")}
        row, body_copies = common["fitted_row"](viewer, body, table, clips, assets, result["scene_sha256"])
        rows[str(body)] = row
        copies.update(body_copies)
    path = work / "native-brown-bear-cougar-enhanced/brown-bear-cougar-native.json"
    verify_native(root, path, candidate, groups, common)
    return rows, copies, sha(path)


def verify_native(root, path, candidate, groups, common):
    sha, read = common["sha"], common["read"]
    native = read(path)
    receipt = read(path.with_name("brown-bear-cougar-native-runtime.json"))
    assert sha(path) == receipt["report_sha256"].lower()
    assert sha(root / "Server/runtime/Server.dll") == receipt["server_sha256"].lower()
    assert sha(root / "Server/runtime/Assemblies/UOContent.dll") == receipt["content_sha256"].lower()
    assert native["test_sha256"] == sha(path.with_name("NativeBrownBearCougarLive.gd"))
    assert native["inputs_sha256"] == candidate["test_sha256"]
    presentation = root / "Viewer/Presentation"
    assert native["dispatcher_sha256"] == sha(presentation / "EnhancedCreatureActions.gd")
    assert native["renderer_sha256"] == sha(presentation / "SourceEnhancedFieldVisual.gd")
    assert native["checks"] == 269 and native["records"].keys() == FORMS.keys()
    expected_cases = {(flags, kind, variant) for flags in (0, 64) for kind in TYPES for variant in (0, 1, 255)}
    for form, record in native["records"].items():
        name, body, hue, swings = FORMS[form]
        assert record["class"] == name and record["hue"] == 0 and record["stock_weapon"] == "Fists"
        assert record["corpse_body"] == body and record["corpse_hue"] == hue and record["corpse"] >= 0x40000000
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
