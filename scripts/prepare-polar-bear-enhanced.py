# SPDX-License-Identifier: GPL-3.0-or-later
"""Validate the Polar Bear fit against exact Enhanced source and native evidence."""

import runpy


SPRITES = {213: {
    4: ("PolarStandingRake", 40, "42dde7bcae2ee8afb5f825bd71aa8ce07e4f29838bf2751fa7dc7456b3865a14"),
    15: ("PolarUprightThreat", 30, "7b286956fede7303dafede976c10975624e5a902bf765ae03f1e9ed763d4d8bb"),
    23: ("PolarMuzzleUpAndRise", 55, "8f57cdc10f51282665861854fbbbc9b200d05f32d074029bb807d00d3ccdaae4"),
    25: ("PolarStillWatch", 50, "9eaa64ffa23a97eee6a8671f55ba58fba25ee1f0ab879d1887400f723ef5bb0a"),
    26: ("PolarWindScent", 45, "4693e4a63781fc33a848e3a7b26f1f50f830c86d9b3d4aa8a2c0d75483f828fa"),
    27: ("PolarPawHighGuard", 40, "28ecb65d5d123b238c41276876f9cd06445f634ab8ec843ccc36a0ffefcec8b2"),
    28: ("PolarCrouchToRear", 45, "3863516559f0179fc0091662e7b1da55c1884ed74b405fefcde3ed6100cb9c74"),
}}
MEMBERS = {213: "0xb899eb2b30bc2baa"}
TYPES = (2, 5, 8, 11, 14, 15)


def prepare_polar_bear(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    stage = staged or root
    work = root / "work/creatures"
    scenes = work / "native-form-audit/enhanced-source-gaps/polar-bear"
    name_hash = runpy.run_path(str(root / "scripts/audit-classic-parity.py"))["name_hash"]
    assert MEMBERS == {213: hex(name_hash("build/animationsequence/00000213.bin"))}
    groups = common["source_tables"](root, source, SPRITES, TYPES, member_hashes=MEMBERS)[213]
    results = read(scenes / "terrain-receipt.json")
    assert results["script_sha256"] == digest(stage / "scripts/test-polar-bear-enhanced.gd")
    result = results["bodies"]["213"]
    render = read(scenes / "motion-render-receipt.json")["213"]
    geometry = read(scenes / "first-pose-receipt.json")
    clips = [clip for clip, _, _ in SPRITES[213].values()]
    assert result["decoded"] == 144 and result["classic"] == 108 and result["hues"] == 3
    assert result["poses"] == 3255 and result["falls"] == 210 and result["maximum_death_jump"] < .002
    assert set(clips) == set(render["clips"]) == result["terrain"].keys()
    assert all(pose["gap"] >= .0029 for pose in result["terrain"].values())
    assert render["poses"] == 56 and render["minimum_foreground_box_pixels"] >= 1000
    assert render["scene_sha256"] == result["hashes"]["modern"]
    for treatment, proof in geometry.items():
        assert proof["scene_sha256"] == result["hashes"][treatment] and set(proof["clips"]) == set(clips)
        assert all(pose["poses"] == 61 and pose["gap"] >= .002 for pose in proof["clips"].values())
        assert proof["clips"]["PolarPawHighGuard"]["paw_above_head"] > .05
        assert all(pose["hind_drift"] < .00005 for pose in proof["clips"].values())
    assets = {name: scenes / f"213-{name}.scn" for name in ("original", "rounded", "modern")}
    row, copies = common["fitted_row"](root / "Viewer", 213, groups, clips, assets, result["hashes"])
    return {"213": row}, copies, verify_native(root, stage, scenes, work, groups, result, common)


def verify_native(root, stage, scenes, work, groups, result, common):
    read, digest = common["read"], common["sha"]
    folder = work / "native-polar-bear-enhanced"
    path = folder / "polar-bear-native.json"
    native = read(path)
    runtime = read(folder / "polar-bear-native-runtime.json")
    assert digest(path) == runtime["report_sha256"].lower()
    assert digest(root / "Server/runtime/Server.dll") == runtime["server_sha256"].lower()
    assert digest(root / "Server/runtime/Assemblies/UOContent.dll") == runtime["content_sha256"].lower()
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    assert digest(fixture) == runtime["fixture_sha256"].lower()
    assert digest(folder / "NativePolarBearLive.gd") == native["test_sha256"]
    assert digest(scenes / "test-polar-bear-enhanced.gd") == native["inputs_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    renderer = "SourceEnhancedPolarBearVisual.gd"
    assert digest(scenes / renderer) == digest(stage / "Viewer/Presentation" / renderer) == native["renderers"]["polar"]
    assert native["checks"] == 144 and native["records"].keys() == {"polar"}
    record = native["records"]["polar"]
    assert record["class"] == "PolarBear" and record["hue"] == 0 and record["stock_weapon"] == "Fists"
    assert record["can_move"] and record["tamable"] and not record["can_swim"]
    assert len(record["step_delta"]) == 2 and max(map(abs, record["step_delta"])) == 1
    assert record["carved"] == {"raw_ribs": 2, "hides": 18}
    assert record["corpse_body"] == 213 and record["corpse_hue"] == 0x8035 and record["corpse"] >= 0x40000000
    phase, = record["phases"]
    assert phase["body"] == 213 and phase["asset_sha256"] == result["hashes"]["modern"]
    expected = {(flags, kind, variant) for flags in (0, 64) for kind in TYPES for variant in (0, 1, 255)}
    cases = phase["cases"]
    assert len(cases) == len(expected)
    assert {(case["flags"], case["type"], case["variation"]) for case in cases} == expected
    for case in cases:
        action, variation, flags = str(case["type"]), case["variation"], case["flags"]
        mode = "0" if flags else "1"
        choices = groups[mode].get(action, groups["0"][action])
        assert not case["classic"] and case["enhanced"] == (choices[variation % len(choices)] if variation <= 127 else "")
    swing = record["swing"]
    packet = swing["packet"]
    assert (packet["protocol"], packet["body"], packet["serial"]) == ("classic", 213, record["serial"])
    assert packet["action"] == 5 and swing["clip"] == "PolarRearStrike"
    return digest(path)
