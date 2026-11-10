# SPDX-License-Identifier: GPL-3.0-or-later
"""Seal the Enhanced Ettin rise, alert, hammer and terrain handoff."""

SPRITES = {
    18: {
        23: ("EttinRise", 45, "a2829a8475a62096a6aefd5f5f1d16e4cde271333679349adb175862eccb85c2"),
        28: ("EttinAlert", 35, "7fcfc0a82fc0cd8a562d913b25edbeaf2ea52dc04c4857d01258d16990282c89"),
    },
}


def prepare_ettin(root, source, common):
    sha, read = common["sha"], common["read"]
    scripts, viewer = root / "scripts", root / "Viewer"
    work = root / "work/creatures"
    scenes = work / "native-form-audit/enhanced-source-gaps/bird-ettin"
    types = (8, 15)
    groups = common["source_tables"](root, source, SPRITES, types)[18]
    assert sha(scenes / "ettin-hammer-corners.json") == "00f4cbde48e6e37d02d81d9aa79aad14e066a23958e5be896263f768a8d8f2e0"
    assert sha(scenes / "ettin-hammer-atlas.png") == "52f14344eeadc7b0d1472eaa76e4eb1bec1f2293684873059132521762674166"

    candidate = read(scenes / "ettin-enhanced-candidate.json")
    assert candidate["test_sha256"] == sha(scripts / "test-ettin-enhanced.gd")
    assert candidate["renderer_sha256"] == sha(viewer / "Presentation/SourceEnhancedEttinVisual.gd")
    assert (candidate["routes"], candidate["classic_comparisons"], candidate["terrain_poses"],
            candidate["fall_poses"], candidate["handoffs"], candidate["corpse_hues"]) == (48, 36, 930, 1230, 30, 3)
    assert min(candidate["min_action_gap"], candidate["min_fall_gap"]) > .001
    assert candidate["max_handoff_gap"] < .025 and candidate["max_hammer_lift"] < .005

    folder = work / "native-ettin-enhanced"
    path = folder / "ettin-enhanced-native.json"
    native = read(path)
    receipt = read(folder / "ettin-enhanced-native-runtime.json")
    assert sha(path) == receipt["report_sha256"].lower()
    assert sha(root / "Server/runtime/Server.dll") == receipt["server_sha256"].lower()
    assert sha(root / "Server/runtime/Assemblies/UOContent.dll") == receipt["content_sha256"].lower()
    assert native["test_sha256"] == sha(folder / "NativeEttinEnhancedLive.gd")
    assert native["dispatcher_sha256"] == sha(viewer / "Presentation/EnhancedCreatureActions.gd")
    assert native["checks"] == 90
    record = native["record"]
    assert record["body"] == 18 and record["corpse"] >= 0x40000000
    assert record["asset_sha256"] == candidate["scene_sha256"]["modern"]
    cases = record["cases"]
    assert len(cases) == 24 and {(case["flags"], case["type"], case["variation"]) for case in cases} == {
        (flags, action, variant) for flags in (0, 64) for action in types
        for variant in (0, 1, 2, 127, 128, 255)
    }
    for case in cases:
        action = str(case["type"])
        classic = "Pillage" if action == "8" else ""
        assert case["default"] == classic
        assert case["enhanced"] == (groups["0"][action][0] if case["variation"] <= 127 else classic)

    hashes = candidate["scene_sha256"]
    row, copies = common["fitted_row"](viewer, 18, groups, [],
                                       {name: scenes / f"ettin-{name}.scn" for name in hashes}, hashes)
    return {"18": row}, copies, sha(path)
