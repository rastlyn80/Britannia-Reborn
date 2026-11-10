# SPDX-License-Identifier: GPL-3.0-or-later
"""Seal the fitted Corpser and Boar against source frames and native trials."""

SPRITES = {
    8: {
        4: ("CorpserTripleSweep", 35, "c49ed62089515671ab9cc4890a54a4de55d6b9ac173421664f7650f758df32d9"),
        15: ("CorpserClosedCanopy", 30, "1a73cf3163a199c2d24a518332b18fcbdb7a7dafb85b8eec5d7337089c5efaed"),
        23: ("Emerge", 45, "68678e2552636af7096124cfebe404608d888f3a40a164e9c2dd5f60162e935e"),
        25: ("CorpserQuietBloom", 60, "2d66dcb5804bb5dc01f77468b308bde37221ad89093133b2d66ba301e9205978"),
        26: ("CorpserClosePetals", 55, "6d67dd2772f849828dd7700d99f71343f25e36faa94b0b9e3613e3f83ddfda85"),
        27: ("CorpserSplay", 45, "a0ec9aeedc597e07dd676615bd00a398782d2bc0dd745bbce3b8639a5079dcf6"),
        28: ("CorpserRaisedTendrils", 35, "dafd3edfd07f0ed94c8066160d9cddb3377da248923fc2b11f0ec9eba5e51345"),
    },
    290: {
        4: ("BoarTuskFlick", 25, "8e615e93e1898f510fcc7b928dc30a85b027e6a685ba8ce6adb6636199dd4a41"),
        15: ("BoarSnoutRecoil", 30, "c47913666daa7241cb0ffbdb33dd270fb4d61d023cb73d8955d63550494224d2"),
        25: ("BoarQuietStand", 50, "4a9e23724a83b5ec73102850fa93a0d80b897dbb7d31e8a3abfdda4980bbdba2"),
        26: ("BoarScentCheck", 45, "d6bac4cccb5f31340db12fd39b9a942d72023b9a3ef716adb9acf715e1b54f84"),
        27: ("BoarLowGuard", 40, "17c2cdf5f3e6925deb72c6bae180a03b0380aeb930ee74daa824d87419b1178b"),
        28: ("BoarEarAlert", 35, "83c9b5685458436df3d539eff6a8d21b4ca69ab898bbe02029ff1ec43bdadf47"),
    },
}
TYPES = (2, 5, 8, 11, 14, 15)
FORMS = {
    "corpser": ("Corpser", 8, 0x8035, {4: "InwardHook", 5: "Attack", 6: "DoubleLash"}),
    "boar": ("Boar", 290, 0x455, {4: "LookSide", 5: "Attack", 6: "Attack2"}),
}
CORPSER_CLASSIC = {5: ("Fidget", "TendrilCurl"), 11: ("Emerge", "Emerge")}


def prepare_corpser_boar(root, source, common):
    sha, read = common["sha"], common["read"]
    work = root / "work/creatures"
    viewer = root / "Viewer"
    scenes = work / "native-form-audit/enhanced-source-gaps/corpser-boar"
    groups = common["source_tables"](root, source, SPRITES, TYPES)
    candidate = read(scenes / "corpser-boar-candidate.json")
    assert candidate["test_sha256"] == sha(root / "scripts/test-corpser-boar-enhanced.gd")
    assert candidate["bodies"].keys() == {"8", "290"}
    rows, copies = {}, {}
    for body, table in groups.items():
        result = candidate["bodies"][str(body)]
        clips = [clip for clip, _, _ in SPRITES[body].values() if clip != "Emerge"]
        assert (result["routes"], result["classic_comparisons"], result["corpse_hues"]) == (144, 108, 3)
        assert result["terrain_poses"] == 2790
        assert result["gaps"].keys() == set(clips) and all(gap >= .0019 for gap in result["gaps"].values())
        assert result["emergences"] == (15 if body == 8 else 0)
        assert result["trunk_drift"] < .075
        if body == 8:
            assert all(gap >= .0039 for gap in result["gaps"].values())
        assets = {name: scenes / f"{body}-{name}.scn" for name in ("original", "rounded", "modern")}
        row, body_copies = common["fitted_row"](viewer, body, table, clips, assets, result["scene_sha256"])
        rows[str(body)] = row
        copies.update(body_copies)
    path = work / "native-corpser-boar-enhanced/corpser-boar-native.json"
    verify_native(root, path, candidate, groups, common)
    return rows, copies, sha(path)


def verify_native(root, path, candidate, groups, common):
    sha, read = common["sha"], common["read"]
    native = read(path)
    receipt = read(path.with_name("corpser-boar-native-runtime.json"))
    assert sha(path) == receipt["report_sha256"].lower()
    assert sha(root / "Server/runtime/Server.dll") == receipt["server_sha256"].lower()
    assert sha(root / "Server/runtime/Assemblies/UOContent.dll") == receipt["content_sha256"].lower()
    assert native["test_sha256"] == sha(path.with_name("NativeCorpserBoarLive.gd"))
    assert native["inputs_sha256"] == candidate["test_sha256"]
    presentation = root / "Viewer/Presentation"
    assert native["dispatcher_sha256"] == sha(presentation / "EnhancedCreatureActions.gd")
    assert native["renderers"] == {
        "boar": sha(presentation / "SourceEnhancedFieldVisual.gd"),
        "corpser": sha(presentation / "SourceEnhancedCorpserVisual.gd"),
    }
    assert native["checks"] == 273 and native["records"].keys() == FORMS.keys()
    expected_cases = {(flags, kind, variant) for flags in (0, 64) for kind in TYPES for variant in (0, 1, 255)}
    for form, record in native["records"].items():
        name, body, hue, swings = FORMS[form]
        assert record["class"] == name and record["hue"] == 0 and record["stock_weapon"] == "Fists"
        assert record["corpse_body"] == body and record["corpse_hue"] == hue and record["corpse"] >= 0x40000000
        assert record["can_move"] == (body == 290)
        phase, = record["phases"]
        assert phase["body"] == body and phase["asset_sha256"] == candidate["bodies"][str(body)]["scene_sha256"]["modern"]
        assert len(phase["cases"]) == len(expected_cases)
        assert {(case["flags"], case["type"], case["variation"]) for case in phase["cases"]} == expected_cases
        for case in phase["cases"]:
            kind, variant = str(case["type"]), case["variation"]
            mode = "0" if case["flags"] else "1"
            choices = groups[body][mode].get(kind, groups[body]["0"][kind])
            classic_choices = CORPSER_CLASSIC.get(int(kind), ("", "")) if body == 8 else ("", "")
            classic = classic_choices[variant & 1]
            assert case["classic"] == classic
            assert case["enhanced"] == (choices[variant % len(choices)] if variant <= 127 else classic)
        swing = record["swing"]
        packet = swing["packet"]
        assert packet["protocol"] == "classic" and packet["body"] == body and packet["serial"] == record["serial"]
        assert swing["clip"] == swings[packet["action"]]
