# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the distinct unarmed Troll and archive-armed Ratman fits."""

import runpy


SPRITES = {
    53: {
        4: ("TrollOpenHandSlam", 50, "119c2788cc952ecfb014a326ed3290edd7ce23e83c37dd6307e5805a8f396dda"),
        23: ("TrollBraceAndRise", 55, "6fb720dfba5bff0534b4e034e6c2da79572c7e0138301bef2212bff81d049a6b"),
        26: ("TrollMeasure", 55, "56d85450734db99882ff906649c871140a31d4f14e785dbd5c344748b75f4d01"),
        27: ("TrollOpenGuard", 50, "0288b21b629cd49126e2d0e6f90d43bd3f213c85b8fc2fe0012b6e67864c8801"),
        28: ("TrollBraceAlert", 40, "1bcf6d91ceb1860ff20f18d0c52be065c7f22a13f85460949abf7dfe82c56ed4"),
    },
    42: {
        4: ("RatmanOverheadAxe", 45, "33ce57114e2d3763dbd91955ce2e3b02d5f81150aba402ef00b84e36f2beb9d1"),
        23: ("RatmanAxeSomersault", 50, "7d508a6527a023abf70e7f8eb350be49ee486c1c6a646d8c20bf9b1342d64d24"),
        26: ("RatmanQuietGuard", 45, "bf90b22ce0237f21e6662218766849d8f6a215fc3cf30eedaae9f626445a3f8a"),
        27: ("RatmanAxeCheck", 55, "4a0e4be1f8d971f0b7ae7adaa8a65eb442ad1f6b9facb82b1d1349d10f0be910"),
        28: ("RatmanAxeAlert", 60, "962a6d7899f78b83aad29f84d7ce687ca36379f5861a640b9cf5f0ba972d053d"),
    },
}
TYPES = (5, 8, 11, 15)
FORMS = {"troll-53": ("Troll", 53), "troll-54": ("Troll", 54), "ratman": ("Ratman", 42)}
TROLL_CLASSIC = {5: ("Fidget", "KnuckleCheck"), 8: ("KneelingSwing", "KneelingSwing")}
RATMAN_CLASSIC = {5: ("Fidget", "RatmanSniff"), 8: ("Hunch", "Hunch")}
TROLL_SWINGS = {4: "WideSwipe", 5: "Attack", 6: "RisingSweep"}
RATMAN_SWINGS = {4: "Attack", 5: "RatmanSwipe", 6: "RatmanLunge"}


def prepare_troll_ratman(root, source, common):
    sha, read = common["sha"], common["read"]
    scripts, viewer = root / "scripts", root / "Viewer"
    work = root / "work/creatures"
    folder = work / "native-form-audit/enhanced-source-gaps/troll-ratman"
    tables = common["source_tables"](root, source, SPRITES, TYPES)
    assert sha(folder / "ratman-axe-corners.json") == "70cd62431727ecada08372f094c98b9fe1d42cc5bfb1929753d129d7306014a3"
    assert sha(folder / "ratman-axe-atlas.png") == "52f14344eeadc7b0d1472eaa76e4eb1bec1f2293684873059132521762674166"
    candidate = read(folder / "troll-ratman-candidate.json")
    assert candidate["test_sha256"] == sha(scripts / "test-troll-ratman-enhanced.gd")
    assert candidate["bodies"].keys() == {"42", "53"}
    rows, copies = {}, {}
    for body, groups in tables.items():
        result = candidate["bodies"][str(body)]
        assert (result["routes"], result["classic_comparisons"], result["terrain"], result["corpse_hues"]) == (96, 72, 2325, 3)
        clips = [clip for clip, _, _ in SPRITES[body].values()]
        assert result["gaps"].keys() == set(clips) and min(result["gaps"].values()) > .0019
        if body == 42:
            assert (result["fall_poses"], result["handoffs"]) == (1845, 45)
            assert result["fall_minimum"] > .0019 and result["handoff_gap"] < .025 and result["extra_axe_lift"] < .05
        assets = {name: folder / f"{body}-{name}.scn" for name in ("original", "rounded", "modern")}
        row, body_copies = common["fitted_row"](viewer, body, groups, clips, assets, result["scene_sha256"])
        rows[str(body)] = row
        copies.update(body_copies)
    # The second stock Troll roll is a comparison with the earlier axe profile.
    earlier = runpy.run_path(str(scripts / "prepare-troll-enhanced.py"))
    previous_rows, _, _ = earlier["prepare_troll"](root, source, common)
    previous = previous_rows["54"]
    hashes = {body: result["scene_sha256"]["modern"] for body, result in candidate["bodies"].items()}
    hashes["54"] = previous["assets"]["modern"]["sha256"]
    tables[54] = previous["groups"]
    native = work / "native-troll-ratman-enhanced/troll-ratman-native.json"
    verify_native(root, native, tables, hashes, candidate["test_sha256"], common)
    return rows, copies, sha(native)


def verify_native(root, path, tables, hashes, inputs_sha256, common):
    sha, read = common["sha"], common["read"]
    folder = path.parent
    native = read(path)
    receipt = read(folder / "troll-ratman-native-runtime.json")
    assert sha(path) == receipt["report_sha256"].lower()
    assert sha(root / "Server/runtime/Server.dll") == receipt["server_sha256"].lower()
    assert sha(root / "Server/runtime/Assemblies/UOContent.dll") == receipt["content_sha256"].lower()
    assert native["test_sha256"] == sha(folder / "NativeTrollRatmanLive.gd")
    assert native["inputs_sha256"] == inputs_sha256
    presentation = root / "Viewer/Presentation"
    assert native["dispatcher_sha256"] == sha(presentation / "EnhancedCreatureActions.gd")
    assert native["renderers"] == {
        "troll": sha(presentation / "SourceEnhancedTrollVisual.gd"),
        "ratman": sha(presentation / "SourceEnhancedRatmanVisual.gd"),
    }
    assert native["checks"] == 274 and native["records"].keys() == FORMS.keys()
    for form, record in native["records"].items():
        name, body = FORMS[form]
        assert record["class"] == name and record["hue"] == 0 and record["stock_weapon"] == "Fists"
        assert record["corpse_body"] == body and record["corpse"] >= 0x40000000
        swing = record["swing"]["packet"]
        swings = RATMAN_SWINGS if body == 42 else TROLL_SWINGS
        assert swing["protocol"] == "classic" and swing["body"] == body and swing["serial"] == record["serial"]
        assert swing["frames"] == 7 and swing["repeat_count"] == 1 and swing["delay"] == 0
        assert not swing["repeat"] and not swing["reverse"] and record["swing"]["clip"] == swings[swing["action"]]
        phase, = record["phases"]
        assert phase["body"] == body and phase["asset_sha256"] == hashes[str(body)]
        cases = phase["cases"]
        expected = {(flags, kind, variant) for flags in (0, 64) for kind in TYPES for variant in (0, 1, 255)}
        assert len(cases) == len(expected)
        assert {(case["flags"], case["type"], case["variation"]) for case in cases} == expected
        for case in cases:
            kind, variant = case["type"], case["variation"]
            mode = "0" if case["flags"] else "1"
            choices = tables[body][mode].get(str(kind), tables[body]["0"][str(kind)])
            classic = (RATMAN_CLASSIC if body == 42 else TROLL_CLASSIC).get(kind, ("", ""))[variant & 1]
            assert case["classic"] == classic
            assert case["enhanced"] == (choices[variant % len(choices)] if variant <= 127 else classic)
