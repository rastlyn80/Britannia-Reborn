# SPDX-License-Identifier: GPL-3.0-or-later
"""Check the official Kraken frames and evidence for the optional compact rig."""

SPRITES = {
    77: {
        23: ("KrakenSurface", 55, "4c48e125218f73bb09aff3a71f4aefcd9a56a781973fb1d20ebeff1abb212ffe"),
        25: ("KrakenPoise", 55, "fb2862079387144f033b537f0f438161452662ede6bab9941fbedd9e2651c528"),
        26: ("KrakenScan", 55, "a866185dfc64b7e67f1aca9a62bc8ba82527de4511af961ee62dbad57cdef089"),
        27: ("KrakenFinThrust", 50, "aaa3884b8d79963fff5d06cd0eb987dc8db1c3cd87548ab203f3ee17b99b2eb6"),
        28: ("KrakenAlert", 55, "940d3c53b96ea8265f4d9f7c6c700fcef8430d7bb4497281d5ffaa7dd05affd1"),
    },
}


def prepare_kraken(root, source, common):
    sha, read = common["sha"], common["read"]
    scripts, viewer = root / "scripts", root / "Viewer"
    work = root / "work/creatures"
    scene_folder = work / "native-form-audit/enhanced-source-gaps/amou"
    types = (5, 8, 14, 15)
    groups = common["source_tables"](root, source, SPRITES, types)[77]
    candidate = read(scene_folder / "kraken-compact-candidate.json")
    assert candidate["test_sha256"] == sha(scripts / "test-kraken-enhanced.gd")
    assert (candidate["routes"], candidate["classic_comparisons"], candidate["waterline_poses"],
            candidate["corpse_hues"]) == (96, 72, 930, 4)
    surface = candidate["actions"]["modern:KrakenSurface"]
    assert .30 <= surface[4] <= .40 and surface[3] > 1.5
    assert candidate["actions"]["modern:KrakenPoise"][2] < .20
    assert candidate["actions"]["modern:KrakenFinThrust"][2] > 1.40
    assert candidate["actions"]["modern:KrakenAlert"][2] > .75

    native_folder = work / "native-kraken-enhanced"
    native_path = native_folder / "kraken-enhanced-native.json"
    report = read(native_path)
    receipt = read(native_folder / "kraken-enhanced-native-runtime.json")
    assert sha(native_path) == receipt["report_sha256"].lower()
    assert sha(root / "Server/runtime/Server.dll") == receipt["server_sha256"].lower()
    assert sha(root / "Server/runtime/Assemblies/UOContent.dll") == receipt["content_sha256"].lower()
    assert report["test_sha256"] == sha(native_folder / "NativeKrakenEnhancedLive.gd")
    assert report["checks"] >= 243 and set(report["throws"]) == {"regular", "fabled"}
    assert report["records"].keys() == {"Kraken", "Leviathan", "SeaSerpent", "DeepSeaSerpent", "WaterElemental"}
    for name, hue in (("Kraken", 0), ("Leviathan", 0x481)):
        record = report["records"][name]
        assert record["hue"] == hue and record["body"] == 77 and record["corpse"] >= 0x40000000
        assert record["candidate_sha256"] == candidate["scene_sha256"]["modern"]
        cases = record["enhanced_actions"]
        assert len(cases) == 24 and {(case["flags"], case["type"], case["variation"]) for case in cases} == {
            (flags, action, variation) for flags in (0, 64) for action in types for variation in (0, 1, 255)
        }
        for case in cases:
            action, variation = case["type"], case["variation"]
            mode = "0" if case["flags"] & 0x40 else "1"
            choices = groups[mode].get(str(action), groups["0"][str(action)])
            classic = ("Fidget2" if variation % 2 else "Fidget") if action == 5 else (
                "" if action == 15 else "Fidget")
            assert case["classic"] == classic
            assert case["enhanced"] == (choices[variation % len(choices)] if variation <= 127 else classic)

    hashes = candidate["scene_sha256"]
    scenes = {name: scene_folder / f"kraken-compact-{name}.scn" for name in hashes}
    row, copies = common["fitted_row"](viewer, 77, groups, [], scenes, hashes)
    return {"77": row}, copies, sha(native_path)
