# SPDX-License-Identifier: GPL-3.0-or-later
"""Seal the optional Skeleton and Mongbat source fits and native action witnesses."""

SPRITES = {
    50: {
        4: ("SkeletonCastingStep", 35, "017b58cef7a58088f4b22b0d7b881b2f1c01c8b0b9df10139dc3b606b7508733"),
        23: ("SkeletonAssemble", 70, "548ff6af7c7bc4bdb1f6c2c76cc2a04244a686166d275c24ab4f992eb0fae876"),
        26: ("SkeletonSkullCheck", 50, "df083418220d2696bbd0ed7c95ed39ef546ec947f753dcb86b0a56b859765693"),
        27: ("SkeletonLooseGuard", 55, "41c018c4b02e4b2a5d9ba15a17e2736a7b30de962e45bda8618a01ffd7988db0"),
        28: ("SkeletonReadyStagger", 25, "8a4fbcb0fc566dbc745b2a981adcc2ca68a99bb4ea0174ea1ce3dfe77a1c5950"),
    },
    39: {
        4: ("MongbatDivingSwoop", 35, "076aed4313bf24e40aaabefcffdd2d85541ebbaa4ac7c0997aee6c7133759f2c"),
        23: ("MongbatUnfoldAndRise", 45, "1fec4b01d2667b3c2124a6b6e6239e22ab33f251eefc83386062641c0507f533"),
        26: ("MongbatQuietHover", 60, "94546cf027be492d3491f786d3e90da4d104a3081cc283d12c1e367e46f7dcf9"),
        27: ("MongbatHoverRebalance", 50, "d59123ae9ae6b79d5735ea6b28fd5f2f19f4c2d6148d0edef6c6c88145b84386"),
        28: ("MongbatWingAlert", 30, "c7bee2561e86423607f082f37f4cc674b72ca4eaf444031792bbc2bd952645c9"),
    },
}
TYPES = (5, 8, 11, 15)
FORMS = {
    "skeleton": ("Skeleton", 50), "skeleton-other": ("Skeleton", 56), "szandor": ("SkeletonOfSzandor", 50),
    "mongbat": ("Mongbat", 39), "greater-mongbat": ("GreaterMongbat", 39), "strong-mongbat": ("StrongMongbat", 39),
}
CLASSIC = {
    50: {5: ("BoneStretch", "Fidget2"), 8: ("Reach", "Reach")},
    39: {5: ("MongbatArmLift", "Fidget2"), 8: ("WingSettle", "WingSettle")},
}


def prepare_skeleton_mongbat(root, source, common):
    sha, read = common["sha"], common["read"]
    viewer = root / "Viewer"
    work = root / "work/creatures"
    scenes = work / "native-form-audit/enhanced-source-gaps/skeleton-mongbat"
    group_tables = {body: common["source_tables"](
        root, source, {body: sprites}, TYPES, flight_fallback=(body == 39)
    )[body] for body, sprites in SPRITES.items()}
    candidate = read(scenes / "skeleton-mongbat-candidate.json")
    assert candidate["test_sha256"] == sha(root / "scripts/test-skeleton-mongbat-enhanced.gd")
    assert candidate["bodies"].keys() == {"39", "50"}
    rows, copies = {}, {}
    for body, groups in group_tables.items():
        result = candidate["bodies"][str(body)]
        routes = (96, 72, 15) if body == 50 else (192, 144, 30)
        assert (result["routes"], result["classic_comparisons"], result["interruptions"]) == routes
        assert result["terrain"] == 2325 and result["static_corpse_hues"] == 3
        clips = [clip for clip, _, _ in SPRITES[body].values()]
        assert result["gaps"].keys() == set(clips) and all(gap >= .0019 for gap in result["gaps"].values())
        assets = {name: scenes / f"{body}-{name}.scn" for name in ("original", "rounded", "modern")}
        row, body_copies = common["fitted_row"](viewer, body, groups, clips, assets, result["scene_sha256"])
        if body == 39:
            row["flight_falls_back_to_combat"] = True
        rows[str(body)] = row
        copies.update(body_copies)
    native_path = work / "native-skeleton-mongbat-enhanced/skeleton-mongbat-native.json"
    verify_native(root, native_path, candidate, group_tables, common)
    return rows, copies, sha(native_path)


def verify_native(root, path, candidate, groups, common):
    sha, read = common["sha"], common["read"]
    folder = path.parent
    native = read(path)
    receipt = read(folder / "skeleton-mongbat-native-runtime.json")
    assert sha(path) == receipt["report_sha256"].lower()
    assert sha(root / "Server/runtime/Server.dll") == receipt["server_sha256"].lower()
    assert sha(root / "Server/runtime/Assemblies/UOContent.dll") == receipt["content_sha256"].lower()
    assert native["test_sha256"] == sha(folder / "NativeSkeletonMongbatLive.gd")
    assert native["inputs_sha256"] == candidate["test_sha256"]
    presentation = root / "Viewer/Presentation"
    assert native["dispatcher_sha256"] == sha(presentation / "EnhancedCreatureActions.gd")
    assert native["renderers"] == {
        "skeleton": sha(presentation / "SourceEnhancedSkeletonVisual.gd"),
        "mongbat": sha(presentation / "SourceEnhancedMongbatVisual.gd"),
    }
    assert native["checks"] == 320 and native["records"].keys() == FORMS.keys()
    for form, record in native["records"].items():
        name, body = FORMS[form]
        assert record["class"] == name and 0 < record["serial"] < 0x40000000
        if form == "szandor":
            assert record["invulnerable"] and record["hue"] == 0x83f2 and "corpse" not in record
        else:
            assert record["corpse"] >= 0x40000000 and record["corpse_body"] == body and record["hue"] == 0
        if body == 56:
            assert not record["phases"]
            continue
        phase, = record["phases"]
        assert phase["body"] == body and phase["asset_sha256"] == candidate["bodies"][str(body)]["scene_sha256"]["modern"]
        kinds, variants = (TYPES, (0, 1, 255)) if form in ("skeleton", "mongbat") else ((5,), (1,))
        flags = (0, 4, 64, 68) if body == 39 else (0, 64)
        expected = {(flag, kind, variant) for flag in flags for kind in kinds for variant in variants}
        assert len(phase["cases"]) == len(expected)
        assert {(case["flags"], case["type"], case["variation"]) for case in phase["cases"]} == expected
        for case in phase["cases"]:
            kind, variant = case["type"], case["variation"]
            mode = "0" if case["flags"] else "1"
            choices = groups[body][mode].get(str(kind), groups[body]["0"][str(kind)])
            classic = CLASSIC[body].get(kind, ("", ""))[variant & 1]
            assert case["classic"] == classic
            assert case["enhanced"] == (choices[variant % len(choices)] if variant <= 127 else classic)
