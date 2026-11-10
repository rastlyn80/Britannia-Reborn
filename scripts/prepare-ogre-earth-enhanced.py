# SPDX-License-Identifier: GPL-3.0-or-later
"""Validate the fitted Ogre and Earth Elemental against the source and local trials."""

import runpy
from pathlib import Path

SPRITES = {
    1: {
        4: ("OgreTurningSweep", 45, "2b5c7fe285ba177f12e546e63a571c9172121af76397d111bc478b4e93fe46ed"),
        23: ("OgreCrouchRise", 35, "9afc39940acd57aa1be486ab8d2ccc30898bd5d83a1f09d38c08b8a323191ddd"),
        26: ("OgreLookDown", 60, "0a37d364c064e6e520e1d38c16417051ec2cc0571e35f21e60c4a2ae2f2dfcdc"),
        27: ("OgreBrowGuard", 55, "0f99b0e272f1cc921114507b4dca6c0764ae12f8968bb119adc6cdbab90a222f"),
        28: ("OgreReadyLean", 35, "d1746602de77f0bd1aabd4a31b03effd39a99c2c76ed1f8d24ee61a3787e583a"),
    },
    14: {
        12: ("EarthTwoHandSlam", 45, "efd273be5ec7644930262214981c85e16653a6958af1f17c2efbcd8865bc74cd"),
        23: ("EarthStoneFormation", 60, "8db21a11d3f5dac0219a68e08f753de745bb405322d1aa0a2cae7fc86adc11cd"),
        26: ("EarthFistCheck", 55, "084e1384a12b1deef182dece42d01b381c6a97318e87fbc7d5e849753a3cf2ca"),
        27: ("EarthHeavyGuard", 45, "d76804238f2321bb57859a64f023ee755c5fd9b6472bfecb3d3f69d85cf30a7e"),
        28: ("EarthLowBrace", 30, "01e05c0fe55f76af01cd72cfdece32013b209d7e512a1a0beb1e9346fc981500"),
    },
}
TYPES = (5, 8, 11, 15)
FORMS = {
    "ogre": ("Ogre", 1, (0,), 0x8035),
    "earth": ("EarthElemental", 14, (0,), 0x455),
    "plague-earth": ("PlagueSpawn", 14, range(0x11, 0x20), 0x8035),
}
CLASSIC_NEW = {1: {5: ("Fidget", "ShoulderScratch"), 8: ("FaceWipe", "FaceWipe")},
               14: {5: ("Fidget", "HeavyShift"), 8: ("StoneGesture", "StoneGesture")}}
CLASSIC_SWING = {1: {4: "OverheadHammer", 5: "Attack", 6: "HighUppercut"},
                 14: {4: "StoneReach", 5: "Attack", 6: "OverheadSmash"}}


def prepare_ogre_earth(root, source, common, staged=None):
    sha, read = common["sha"], common["read"]
    viewer = root / "Viewer"
    work = root / "work/creatures"
    scenes = work / "native-form-audit/enhanced-source-gaps/ogre-earth"
    code_root = staged or root
    groups = common["source_tables"](root, source, SPRITES, TYPES)
    candidate = read(scenes / "terrain-candidate.json")
    render = read(scenes / "motion-render-receipt.json")
    assert candidate["test_sha256"] == sha(code_root / "scripts/test-ogre-earth-enhanced.gd")
    assert candidate["bodies"].keys() == render.keys() == {"1", "14"}
    world = {profile: read(scenes / f"world-{profile}.json") for profile in ("classic", "enhanced")}
    assert all(report.keys() == candidate["bodies"].keys() for report in world.values())
    rows, copies = {}, {}
    for body, table in groups.items():
        result = candidate["bodies"][str(body)]
        fitted = render[str(body)]
        clips = [clip for clip, _, _ in SPRITES[body].values()]
        grounded = [clip for clip in clips if clip != "EarthStoneFormation"]
        assert (result["selections"], result["classic"], result["poses"]) == (96, 72, 2325)
        assert set(fitted["clips"]) == result["clips"].keys() == set(clips)
        assert fitted["poses"] == 40 and fitted["minimum_foreground_box_pixels"] >= (4000 if body == 1 else 20)
        assert fitted["scene_sha256"] == result["hashes"]["modern"]
        assert all(fit["gap"] >= .0019 for fit in result["clips"].values())
        assert len(result["joins"]) == (15 if body == 14 else 0)
        assert len(result["falls"]) == (45 if body == 14 else 0)
        if body == 1:
            assert result["clips"]["OgreTurningSweep"]["wrist_range"] > 1.4
            assert result["clips"]["OgreCrouchRise"]["neck_range"] > .45
        else:
            assert result["clips"]["EarthTwoHandSlam"]["wrist_range"] > 1.5
            formation = result["clips"]["EarthStoneFormation"]
            assert (formation["first_pieces"], formation["maximum_pieces"]) == (1, 15)
            assert max(result["joins"]) < .0001
            assert {fall["pieces"] for fall in result["falls"]} == {1, 15}
            assert all(fall["jump"] < .002 and fall["minimum_gap"] > .0019 for fall in result["falls"])
        for profile, report in world.items():
            replay = report[str(body)]
            formed = body == 14 and profile == "enhanced"
            assert replay["clip"] == ("EarthStoneFall" if formed else "Death")
            assert replay["pieces"] == (15 if formed else 1) and replay["jump"] < .002
            assert replay["corpse"] >= 0x40000000 and replay["hue"] == (0x8035 if body == 14 else 0x455)
        stem = "14-formation" if body == 14 else "1"
        assets = {name: scenes / f"{stem}-{name}.scn" for name in ("original", "rounded", "modern")}
        row, body_copies = common["fitted_row"](viewer, body, table, grounded, assets, result["hashes"])
        rows[str(body)] = row
        copies.update(body_copies)
    native = work / "native-ogre-earth-enhanced/ogre-earth-native.json"
    verify_native(root, code_root, scenes, native, candidate, groups, common)
    return rows, copies, sha(native)


def verify_native(root, code_root, scenes, path, candidate, groups, common):
    sha, read = common["sha"], common["read"]
    native = read(path)
    receipt = read(path.with_name("ogre-earth-native-runtime.json"))
    assert sha(path) == receipt["report_sha256"].lower()
    assert sha(root / "Server/runtime/Server.dll") == receipt["server_sha256"].lower()
    assert sha(root / "Server/runtime/Assemblies/UOContent.dll") == receipt["content_sha256"].lower()
    fixture = path.parent / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    assert sha(fixture) == receipt["fixture_sha256"].lower()
    assert native["test_sha256"] == sha(path.with_name("NativeOgreEarthLive.gd"))
    assert native["inputs_sha256"] == candidate["test_sha256"]
    viewer = root / "Viewer/Presentation"
    assert native["dispatcher_sha256"] == sha(viewer / "EnhancedCreatureActions.gd")
    filename = "SourceEnhancedEarthVisual.gd"
    shadow = scenes / filename
    runtime = code_root / "Viewer/Presentation" / filename
    assert shadow.read_text(encoding="utf-8") == runtime.read_text(encoding="utf-8")
    assert native["renderers"] == {"ogre": sha(viewer / "SourceEnhancedFieldVisual.gd"), "earth": sha(shadow)}
    verify_cases = runpy.run_path(str(Path(__file__).with_name("enhanced-creature-proof.py")))["verify_native_cases"]
    verify_cases(native, 298, FORMS, TYPES, groups, candidate["bodies"], CLASSIC_NEW, CLASSIC_SWING)
