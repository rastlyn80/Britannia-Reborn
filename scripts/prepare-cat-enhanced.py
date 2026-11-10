# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the six fitted cat motions and the stock Hell Cat windup."""

SPRITES = {
    201: {
        4: ("CatSpring", 50, "5a4aea2cb31e138055b7a3ca6c9ec3f1d1ca70671a1c9e1aed0819d238dcf2df"),
        15: ("CatTailRecoil", 35, "c75e9c7853dfce6e67b3ca7c5d40fcc274ec4132c9066f27609642d67369b8dd"),
        25: ("CatQuietStand", 40, "44f8ac9efc7f1bf92d3c296def8372f93261b11ccfb2e252c0f1f970bfac9f0c"),
        26: ("CatListening", 55, "5112cf9163cf784b277d1727699c7a10631d79d121edfe93ec1cea2fe369d2d8"),
        27: ("CatRearAndSwipe", 45, "dbd13ff13a77a271ed337b0aad5f64fc31130656ddf250220ec9d3ee11ad476f"),
        28: ("CatStartle", 25, "b94154702d758721b6dd097bf1d4e6776ec2501ca8f8b4ce21e20643f6f5ea2e"),
    },
}
TYPES = (2, 5, 8, 11, 14, 15)
FORMS = {"cat": "Cat", "diseased-cat": "DiseasedCat", "hell-cat": "HellCat"}
HELL_HUES = {0x647, 0x650, 0x659, 0x662, 0x66b, 0x674}


def prepare_cat(root, source, common):
    sha, read = common["sha"], common["read"]
    viewer = root / "Viewer"
    work = root / "work/creatures"
    scene = work / "native-form-audit/enhanced-source-gaps/cat-enhanced/201-modern.scn"
    groups = common["source_tables"](root, source, SPRITES, TYPES)[201]
    clips = [clip for clip, _, _ in SPRITES[201].values()]
    candidate = read(scene.with_name("cat-enhanced-candidate.json"))
    assert candidate["test_sha256"] == sha(root / "scripts/test-cat-enhanced.gd")
    assert (candidate["routes"], candidate["classic_comparisons"], candidate["terrain_poses"],
            candidate["corpse_hues"]) == (48, 36, 930, 3)
    assert candidate["gaps"].keys() == set(clips)
    assert all(.0019 <= gap <= .004 for gap in candidate["gaps"].values())
    flight = candidate["flight"]
    assert .23 < flight["peak"] < .30 and .09 < flight["forward"] < .15
    assert max(abs(flight["start"]), abs(flight["end"])) < .004 and flight["return_error"] < .002
    assert candidate["rear"]["paw_lift"] > .10 and candidate["rear"]["hind_drift"] < .015

    folder = work / "native-cat-enhanced"
    path = folder / "cat-enhanced-native.json"
    native = read(path)
    receipt = read(folder / "cat-enhanced-native-runtime.json")
    assert sha(path) == receipt["report_sha256"].lower()
    assert sha(root / "Server/runtime/Server.dll") == receipt["server_sha256"].lower()
    assert sha(root / "Server/runtime/Assemblies/UOContent.dll") == receipt["content_sha256"].lower()
    assert native["test_sha256"] == sha(folder / "NativeCatEnhancedLive.gd")
    assert native["inputs_sha256"] == candidate["test_sha256"]
    assert native["renderer_sha256"] == sha(viewer / "Presentation/CatActionsVisual.gd")
    assert native["scene_sha256"] == candidate["scene_sha256"]
    assert native["checks"] == 170 and native["forms"].keys() == FORMS.keys()
    for form, record in native["forms"].items():
        assert record["class"] == FORMS[form] and record["corpse"] >= 0x40000000
        if form == "hell-cat":
            verify_breath(record)
        else:
            assert record["hue"] in range(2301, 2319)
        kinds, variants = (TYPES, (0, 1, 255)) if form == "cat" else ((5,), (1,))
        expected = {(flags, kind, variant) for flags in (0, 64) for kind in kinds for variant in variants}
        cases = record["actions"]
        assert len(cases) == len(expected)
        assert {(case["flags"], case["type"], case["variation"]) for case in cases} == expected
        for case in cases:
            kind, variation = str(case["type"]), case["variation"]
            mode = "0" if case["flags"] else "1"
            choices = groups[mode].get(kind, groups["0"][kind])
            assert case["classic"] == ""
            assert case["enhanced"] == (choices[variation % len(choices)] if variation <= 127 else "")
    row, copies = common["fitted_row"](viewer, 201, groups, clips, {"modern": scene},
                                       {"modern": candidate["scene_sha256"]})
    return {"201": row}, copies, sha(path)


def verify_breath(record):
    assert record["hue"] in HELL_HUES
    breath = record["breath"]
    assert breath["effect"] == 0x36d4 and breath["target"] != record["serial"]
    assert breath["windup"] == {
        "serial": record["serial"], "protocol": "classic", "action": 12, "frames": 5, "repeat_count": 1,
        "reverse": False, "repeat": False, "delay": 0, "body": 201,
    }
    assert breath["presentation"] == [{"accepted": True, "clip": "Alert", "dead": False}] * 2
