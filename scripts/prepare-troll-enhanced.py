# SPDX-License-Identifier: GPL-3.0-or-later
"""Check the official Troll frames, retained axe and native profile evidence."""

SPRITES = {
    54: {
        4: ("TrollOverheadChop", 55, "12ddb7016bf9bbc28ecdc60e4e053e4239ea0c15098621b42a9c18f1fbcfa1ec"),
        23: ("TrollRise", 55, "81aee22ec1564550d12d6efc54f04dcedd2b12b689bb6bc2922304fac06988ce"),
        26: ("TrollWatch", 65, "fea1754472380a9d6184e1f45e931dfb859f5995747bd51f9ea36fa1524cd694"),
        27: ("TrollRaiseAxe", 50, "6185c61d185678fe8a4e68169ee333eafcd9681c6ff64172ab6ac6943fe4dbad"),
        28: ("TrollAlert", 40, "8c19a4eaf99c8da3754495bf00ce0f27f3fc4da80d75e854afe6e4d387b6bc6b"),
    },
}


def prepare_troll(root, source, common):
    sha, read = common["sha"], common["read"]
    scripts, viewer = root / "scripts", root / "Viewer"
    work = root / "work/creatures"
    scenes_folder = work / "native-form-audit/enhanced-source-gaps/amou"
    types = (5, 8, 11, 15)
    groups = common["source_tables"](root, source, SPRITES, types)[54]
    weapon = work / "late-client-inputs/troll-action-trial"
    assert sha(weapon / "weapon-sources.json") == "7156e6e122603ebf9cd407f9b97ad3f8b8b821e7edc6adc760fd3b9231cb7e6e"
    assert sha(weapon / "weapon-atlas.png") == "52f14344eeadc7b0d1472eaa76e4eb1bec1f2293684873059132521762674166"

    candidate = read(scenes_folder / "troll-enhanced-candidate.json")
    assert candidate["test_sha256"] == sha(scripts / "test-troll-enhanced.gd")
    assert (candidate["routes"], candidate["classic_comparisons"], candidate["terrain_poses"],
            candidate["collapse_poses"], candidate["corpse_hues"]) == (96, 72, 2325, 205, 3)
    assert candidate["skin_gap"] > .0004 and candidate["axe_gap"] > .25

    folder = work / "native-troll-enhanced"
    report_path = folder / "troll-enhanced-native.json"
    report = read(report_path)
    receipt = read(folder / "troll-enhanced-native-runtime.json")
    assert sha(report_path) == receipt["report_sha256"].lower()
    assert sha(root / "Server/runtime/Server.dll") == receipt["server_sha256"].lower()
    assert sha(root / "Server/runtime/Assemblies/UOContent.dll") == receipt["content_sha256"].lower()
    assert report["test_sha256"] == sha(folder / "NativeTrollEnhancedLive.gd")
    assert report["checks"] == 162
    record = report["record"]
    assert record["body"] == 54 and record["corpse"] >= 0x40000000
    assert record["asset_sha256"] == candidate["scene_sha256"]["modern"]
    cases = record["cases"]
    assert len(cases) == 48 and {(case["flags"], case["type"], case["variation"]) for case in cases} == {
        (flags, action, variation) for flags in (0, 64) for action in types
        for variation in (0, 1, 2, 127, 128, 255)
    }
    for case in cases:
        action, variation = case["type"], case["variation"]
        mode = "0" if case["flags"] & 0x40 else "1"
        choices = groups[mode].get(str(action), groups["0"][str(action)])
        classic = ("KnuckleCheck" if variation % 2 else "Fidget") if action == 5 else (
            "KneelingSwing" if action == 8 else "")
        assert case["default"] == classic
        assert case["enhanced"] == (choices[variation % len(choices)] if variation <= 127 else classic)

    hashes = candidate["scene_sha256"]
    scenes = {name: scenes_folder / f"troll-{name}.scn" for name in hashes}
    grounded = ["TrollWatch", "TrollRaiseAxe", "TrollAlert", "TrollOverheadChop", "TrollRise"]
    row, copies = common["fitted_row"](viewer, 54, groups, grounded, scenes, hashes)
    return {"54": row}, copies, sha(report_path)
