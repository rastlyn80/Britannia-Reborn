# SPDX-License-Identifier: GPL-3.0-or-later
"""Seal the fitted Grey Wolf and Grizzly Bear against source frames and native trials."""

import runpy

SPRITES = {
    25: {
        4: ("GreyWolfSnap", 35, "14f5d35957ee892fe683b884a13ee2675703cea7acb73a0ce47b19049f1dc23b"),
        15: ("GreyWolfLowRecoil", 35, "68c6263a609b7deaf19bfc27476816899fa17bc9af421fa02610b3f9b241b236"),
        25: ("GreyWolfQuietStand", 60, "eb921f0dbbafab94e1ebc8aa899a2e043c976ed7e9df4f3c62bda152977cb7c0"),
        26: ("GreyWolfScentWatch", 80, "c1ad708254ec22b7f9756a3f1ce946d40caeef001c80d37d1b8613aa7c3c498b"),
        27: ("GreyWolfHowl", 55, "2ff6b74aedfa9c49e8299855f4edc7601d0fc3f3820a7270bad14bd5dc82da43"),
        28: ("GreyWolfEarAlert", 30, "5c3ee566a45b2bd42cd87b126b81b4fed62add9566942f3c60383aeb95f38517"),
    },
    212: {
        4: ("GrizzlyHighSwipe", 40, "69c1d4f2f9227d0216831ca58e02cf0cc7612c92eb4ba6f9f719a0e25d8abd0f"),
        15: ("GrizzlyUprightWarning", 35, "e69baeabfe6c3454ddc907156031ced60f21d7606ea043a99dd97b633a6730e7"),
        23: ("GrizzlyWakeAndRise", 55, "6a4ab206c9f9687d866294a44022e3030791de50d90c06f840ccc9087588a722"),
        25: ("GrizzlyQuietStand", 55, "1e1f105f1034e3b6ac88834540254e1f5a94746564a1ea9de1fa5767204d8d04"),
        26: ("GrizzlyScentTurn", 55, "0764eb257c444c40717c9c24a1505ecdc856b716a61a78037a652b264f235918"),
        27: ("GrizzlyRaisedGuard", 40, "7fbe596b58a9b3f91ce4d3834f42ead7f1a06ee5a12b05fc184bb3a54fae1e58"),
        28: ("GrizzlyRearAlert", 45, "0307e0002b72b762623ad77b380a036770887bb58a312da72493d218ce2fe5ad"),
    },
}
TYPES = (2, 5, 8, 11, 14, 15)
WOLF_SWINGS = {5: "Attack", 6: "Attack2"}
BEAR_SWINGS = {4: "LookSide", 5: "Attack", 6: "Attack2"}
FORMS = {
    "wolf-25": ("GreyWolf", 25, 0x8035, WOLF_SWINGS),
    "wolf-27": ("GreyWolf", 27, 0x455, WOLF_SWINGS),
    "grizzly": ("GrizzlyBear", 212, 0x455, BEAR_SWINGS),
    "raging-grizzly": ("RagingGrizzlyBear", 212, 0x8035, BEAR_SWINGS),
}


def prepare_wolf_grizzly(root, source, common):
    sha, read = common["sha"], common["read"]
    work = root / "work/creatures"
    viewer = root / "Viewer"
    scenes = work / "native-form-audit/enhanced-source-gaps/wolf-grizzly"
    groups = common["source_tables"](root, source, SPRITES, TYPES)
    inspect = runpy.run_path(str(root / "scripts/uo-human-sequences.py"))["inspect"]
    assert not inspect(source / "AnimationSequence.uop", {27})
    candidate = read(scenes / "wolf-grizzly-candidate.json")
    assert candidate["test_sha256"] == sha(root / "scripts/test-wolf-grizzly-enhanced.gd")
    assert candidate["bodies"].keys() == {"25", "212"}
    rows, copies = {}, {}
    for body, table in groups.items():
        result = candidate["bodies"][str(body)]
        clips = [clip for clip, _, _ in SPRITES[body].values()]
        assert (result["routes"], result["classic_comparisons"], result["corpse_hues"]) == (144, 108, 3)
        assert result["terrain_poses"] == 465 * len(clips)
        assert result["gaps"].keys() == set(clips) and all(gap >= .0019 for gap in result["gaps"].values())
        geometry = result["geometry"]
        assert geometry["hind_drift"] < .004
        if body == 212:
            assert geometry["paw_height"] > 1.30 and geometry["paw_span"] > 1.2
            assert geometry["rest_chest_drop"] > .28 and geometry["rest_paw_reach"] > .25
        else:
            assert geometry["head_sweep_rad"] > .55 and geometry["jaw_open_rad"] > .19
        assets = {name: scenes / f"{body}-{name}.scn" for name in ("original", "rounded", "modern")}
        row, body_copies = common["fitted_row"](viewer, body, table, clips, assets, result["scene_sha256"])
        rows[str(body)] = row
        copies.update(body_copies)
    path = work / "native-wolf-grizzly-enhanced/wolf-grizzly-native.json"
    verify_native(root, path, candidate, groups, common)
    return rows, copies, sha(path)


def verify_native(root, path, candidate, groups, common):
    sha, read = common["sha"], common["read"]
    native = read(path)
    receipt = read(path.with_name("wolf-grizzly-native-runtime.json"))
    assert sha(path) == receipt["report_sha256"].lower()
    assert sha(root / "Server/runtime/Server.dll") == receipt["server_sha256"].lower()
    assert sha(root / "Server/runtime/Assemblies/UOContent.dll") == receipt["content_sha256"].lower()
    assert native["test_sha256"] == sha(path.with_name("NativeWolfGrizzlyLive.gd"))
    assert native["inputs_sha256"] == candidate["test_sha256"]
    presentation = root / "Viewer/Presentation"
    assert native["dispatcher_sha256"] == sha(presentation / "EnhancedCreatureActions.gd")
    assert native["renderer_sha256"] == sha(presentation / "SourceEnhancedFieldVisual.gd")
    assert native["checks"] == 423 and native["records"].keys() == FORMS.keys()
    expected_cases = {(flags, kind, variant) for flags in (0, 64) for kind in TYPES for variant in (0, 1, 255)}
    for form, record in native["records"].items():
        name, body, hue, swings = FORMS[form]
        assert record["class"] == name and record["hue"] == 0 and record["stock_weapon"] == "Fists"
        assert record["corpse_body"] == body and record["corpse_hue"] == hue and record["corpse"] >= 0x40000000
        if body == 27:
            assert record["phases"] == []
        else:
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
