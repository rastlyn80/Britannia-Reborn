# SPDX-License-Identifier: GPL-3.0-or-later
"""Check the official Dolphin frame groups and optional waterline motions."""

SPRITES = {
    151: {
        25: ("DolphinHover", 55, "92dcf70e68337170cd9620be9d7d180235c4b337bdef880d22740e040a0f7728"),
        26: ("DolphinBank", 40, "f768cf8f5560678d8f5a183a60687f381b3ce712f7bcdfb325f45be19f83c8a3"),
    },
}


def prepare_dolphin(root, source, common):
    sha, read = common["sha"], common["read"]
    scripts, viewer = root / "scripts", root / "Viewer"
    work = root / "work/creatures"
    scenes = work / "native-form-audit/enhanced-source-gaps/bird-ettin"
    types = (2, 5, 8, 14, 15)
    groups = common["source_tables"](root, source, SPRITES, types)[151]
    candidate = read(scenes / "dolphin-enhanced-candidate.json")
    assert candidate["test_sha256"] == sha(scripts / "test-dolphin-enhanced.gd")
    assert (candidate["routes"], candidate["classic_comparisons"], candidate["waterline_poses"],
            candidate["corpse_hues"]) == (40, 30, 124, 3)
    hover, bank = candidate["body_radians"]
    assert .02 < hover < .08 and .20 < bank < .35

    folder = work / "native-dolphin-enhanced"
    path = folder / "dolphin-enhanced-native.json"
    native = read(path)
    receipt = read(folder / "dolphin-enhanced-native-runtime.json")
    assert sha(path) == receipt["report_sha256"].lower()
    assert sha(root / "Server/runtime/Server.dll") == receipt["server_sha256"].lower()
    assert sha(root / "Server/runtime/Assemblies/UOContent.dll") == receipt["content_sha256"].lower()
    assert native["test_sha256"] == sha(folder / "NativeDolphinEnhancedLive.gd")
    assert native["dispatcher_sha256"] == sha(viewer / "Presentation/EnhancedCreatureActions.gd")
    assert native["checks"] == 108
    record = native["record"]
    assert record["body"] == 151 and record["corpse"] >= 0x40000000
    assert record["can_swim"] and record["cannot_walk"] and -30 <= record["waterline_z"] <= 20
    assert record["asset_sha256"] == candidate["scene_sha256"]["modern"]
    cases = record["cases"]
    assert len(cases) == 30 and {(case["flags"], case["type"], case["variation"]) for case in cases} == {
        (flags, action, variant) for flags in (0, 64) for action in types for variant in (0, 1, 255)
    }
    for case in cases:
        action, variant = str(case["type"]), case["variation"]
        mode = "0" if case["flags"] else "1"
        choices = groups[mode].get(action, groups["0"][action])
        assert case["default"] == ""
        assert case["enhanced"] == (choices[variant % len(choices)] if variant <= 127 else "")

    row, copies = common["fitted_row"](viewer, 151, groups, [],
                                       {"modern": scenes / "dolphin-enhanced.scn"}, candidate["scene_sha256"])
    return {"151": row}, copies, sha(path)
