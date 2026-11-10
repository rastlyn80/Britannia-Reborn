# SPDX-License-Identifier: GPL-3.0-or-later
"""Check the two official small bird sprite groups and optional profile evidence."""

SPRITES = {
    6: {
        25: ("BirdQuietSettle", 10, "1cf48de96e5c45da4e189fa1497cf5536528dfd7a610fb53695cbe7d5d303d0d"),
        26: ("BirdGlance", 35, "5647772305d4834a6933c1677361c0bfb11b37a5d5de3d58393678c7ebbe935f"),
    },
}


def prepare_bird(root, source, common):
    sha, read = common["sha"], common["read"]
    scripts, viewer = root / "scripts", root / "Viewer"
    work = root / "work/creatures"
    scenes = work / "native-form-audit/enhanced-source-gaps/bird-only"
    types = (2, 5, 8, 11, 14, 15)
    groups = common["source_tables"](root, source, SPRITES, types, flight_fallback=True)[6]
    candidate = read(scenes / "bird-enhanced-candidate.json")
    assert candidate["test_sha256"] == sha(scripts / "test-bird-enhanced.gd")
    assert (candidate["routes"], candidate["classic_comparisons"], candidate["terrain_poses"],
            candidate["corpse_hues"]) == (96, 72, 310, 3)
    assert candidate["min_gap"] >= .001

    folder = work / "native-bird-enhanced"
    path = folder / "bird-enhanced-native.json"
    native = read(path)
    receipt = read(folder / "bird-enhanced-native-runtime.json")
    assert sha(path) == receipt["report_sha256"].lower()
    assert sha(root / "Server/runtime/Server.dll") == receipt["server_sha256"].lower()
    assert sha(root / "Server/runtime/Assemblies/UOContent.dll") == receipt["content_sha256"].lower()
    assert native["test_sha256"] == sha(folder / "NativeBirdEnhancedLive.gd")
    assert native["dispatcher_sha256"] == sha(viewer / "Presentation/EnhancedCreatureActions.gd")
    assert native["checks"] == 461 and native["records"].keys() == {"bird", "tropical"}
    for record in native["records"].values():
        assert record["body"] == 6 and record["corpse"] >= 0x40000000
        assert 0 < record["hue"] <= 0xffff
        assert record["asset_sha256"] == candidate["scene_sha256"]["modern"]
        cases = record["cases"]
        assert len(cases) == 72 and {(case["flags"], case["type"], case["variation"]) for case in cases} == {
            (flags, action, variant) for flags in (0, 4, 64, 68) for action in types for variant in (0, 1, 255)
        }
        for case in cases:
            action, variant = str(case["type"]), case["variation"]
            mode = "0" if case["flags"] else "1"
            choices = groups[mode].get(action, groups["0"][action])
            classic = "Cast" if action == "11" else ""
            assert case["default"] == classic
            assert case["enhanced"] == (choices[variant % len(choices)] if variant <= 127 else classic)
    row, copies = common["fitted_row"](viewer, 6, groups, [],
                                       {"modern": scenes / "bird-enhanced.scn"}, candidate["scene_sha256"])
    row["flight_falls_back_to_combat"] = True
    return {"6": row}, copies, sha(path)
