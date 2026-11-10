# SPDX-License-Identifier: GPL-3.0-or-later
"""Validate Drake and Walrus source-backed fits and the native breath evidence."""

import runpy


SPRITES = {
    60: {
        23: ("DrakeFoldedTakeoff", 60, "a21b868a0d5f1fc300648087f158d0222c3ce0614984dbf8f213dd6dcba81a2d"),
        26: ("DrakeTailScan", 55, "c943ddcf020891c244b3552a8e79af721b2cfb6789e582bbee07f9776dc4ece0"),
        27: ("DrakeBroadWingbeat", 50, "c37bbcc8dbb611f2ef982a3ed38503f473e54a1c8f7a04e3e967ba00755102ff"),
        28: ("DrakeSingleWingLift", 30, "abdebdc83b1fdb35b0c4218c3660cd95aef0284429d00cedc5eea48d0627c655"),
    },
    221: {
        4: ("WalrusTuskLift", 40, "fa88faeb4782e500f839279c3561f7d1f84f8ae128c673f952c8891bf0926f2d"),
        15: ("WalrusThroatHitch", 25, "c9e650d9ba7006f8d509e8ade5ad79be32c437e16ec15a74022673c3cef51abd"),
        25: ("WalrusStillWatch", 60, "0fb047c39bcc989c68c25cce26a59337bff21723aa9c1cc14a9e8bb245745122"),
        26: ("WalrusNoseScan", 45, "4bd307acd59132c64f05e284e12225c31566c153eef1c72f21d4ca64458303f8"),
        28: ("WalrusHumpAlert", 40, "67be30d87261e46325a71d82de2e312516302305522c6ac0c21abc1f8e6a3c29"),
    },
}
MEMBERS = {60: "0xe9c03929cf08bfe1", 221: "0x7434a6f06b74b635"}
TYPES = {60: (5, 8, 15), 221: (2, 5, 8, 11, 14, 15)}
FORMS = {"drake": ("Drake", 60, 0x8035, "Yellow"), "red-drake": ("Drake", 61, 0x455, "Red"),
         "walrus": ("Walrus", 221, 0x8035, "none")}
RENDERERS = {60: "SourceEnhancedDrakeVisual.gd", 221: "SourceEnhancedWalrusVisual.gd"}
TESTS = {60: "test-drake-enhanced.gd", 221: "test-walrus-enhanced.gd"}


def prepare_drake_walrus(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    stage = staged or root
    work = root / "work/creatures"
    scenes = work / "native-form-audit/enhanced-source-gaps/drake-walrus"
    name_hash = runpy.run_path(str(root / "scripts/audit-classic-parity.py"))["name_hash"]
    assert MEMBERS == {body: hex(name_hash(f"build/animationsequence/{body:08d}.bin")) for body in SPRITES}
    groups, terrain = {}, {}
    rendered = read(scenes / "motion-render-receipt.json")
    geometry = read(scenes / "first-pose-receipt.json")
    rows, copies = {}, {}
    for body, source_groups in SPRITES.items():
        drake = body == 60
        groups.update(common["source_tables"](
            root, source, {body: source_groups}, TYPES[body], flight_fallback=drake, member_hashes=MEMBERS
        ))
        receipt = read(scenes / ("drake-terrain-receipt.json" if drake else "walrus-terrain-receipt.json"))
        assert receipt["script_sha256"] == digest(stage / "scripts" / TESTS[body])
        result, render = receipt["bodies"][str(body)], rendered[str(body)]
        terrain[body] = result
        clips = [clip for clip, _, _ in source_groups.values()]
        assert result["decoded"] == 144 and result["classic"] == (54 if drake else 108)
        assert result["hues"] == 3 and result["maximum_death_jump"] < .002
        assert result["poses"] == (930 if drake else 465) * len(clips)
        assert result["falls"] == (60 if drake else 30) * len(clips)
        if drake:
            assert result["air_falls"] == 120 and result["minimum_held_air_gap"] >= .80
            assert result["minimum_ground_gap"] >= .0029
        else:
            assert set(result["terrain"]) == set(clips)
            assert all(pose["gap"] >= .0029 for pose in result["terrain"].values())
        assert set(clips) == set(render["clips"]) and render["minimum_foreground_box_pixels"] >= 1000
        assert render["poses"] == 8 * len(clips) and render["scene_sha256"] == result["hashes"]["modern"]
        assert geometry[str(body)].keys() == result["hashes"].keys()
        for treatment, proof in geometry[str(body)].items():
            assert proof["scene_sha256"] == result["hashes"][treatment] and set(proof["clips"]) == set(clips)
            assert all(pose["samples"] == 41 and pose["minimum_gap"] >= .002 and pose["hind_drift"] < .00005
                       for pose in proof["clips"].values())
        assets = {name: scenes / f"{body}-{name}.scn" for name in ("original", "rounded", "modern")}
        row, local = common["fitted_row"](root / "Viewer", body, groups[body], clips, assets, result["hashes"])
        if drake:
            row["flight_falls_back_to_combat"] = True
        rows[str(body)] = row
        copies.update(local)
    return rows, copies, verify_native(root, stage, scenes, work, groups, terrain, common)


def verify_native(root, stage, scenes, work, groups, terrain, common):
    read, digest = common["read"], common["sha"]
    folder = work / "native-drake-walrus-enhanced"
    path = folder / "drake-walrus-native.json"
    native = read(path)
    runtime = read(folder / "drake-walrus-native-runtime.json")
    assert digest(path) == runtime["report_sha256"].lower()
    assert digest(root / "Server/runtime/Server.dll") == runtime["server_sha256"].lower()
    assert digest(root / "Server/runtime/Assemblies/UOContent.dll") == runtime["content_sha256"].lower()
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    assert digest(fixture) == runtime["fixture_sha256"].lower()
    assert digest(folder / "NativeDrakeWalrusLive.gd") == native["test_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["checks"] == 351 and native["records"].keys() == FORMS.keys()
    for body, renderer in RENDERERS.items():
        assert digest(scenes / renderer) == digest(stage / "Viewer/Presentation" / renderer) == native["renderers"][str(body)]
        assert digest(scenes / TESTS[body]) == native["inputs_sha256"][str(body)]
    for form, record in native["records"].items():
        name, body, hue, scales = FORMS[form]
        walrus = body == 221
        assert record["class"] == name and record["hue"] == 0 and record["stock_weapon"] == "Fists"
        assert record["can_move"] and record["can_fly"] == (not walrus) and not record["can_swim"] and record["tamable"]
        assert len(record["step_delta"]) == 2 and max(map(abs, record["step_delta"])) == 1
        assert record["scales"] == scales
        assert record["carved"] == ({"ribs": 1, "hides": 14} if walrus else {"ribs": 0, "hides": 0})
        if walrus:
            assert not record["breath"]
        else:
            breath = record["breath"]
            assert len(breath["launch_ms"]) == 2 and all(1050 <= delay <= 1800 for delay in breath["launch_ms"])
            assert breath["damage"] > 0 and breath["target"] != record["serial"]
        assert record["corpse_body"] == body and record["corpse_hue"] == hue and record["corpse"] >= 0x40000000
        if body in TYPES:
            phase, = record["phases"]
            assert phase["body"] == body and phase["asset_sha256"] == terrain[body]["hashes"]["modern"]
            verify_cases(body, phase["cases"], groups[body])
        else:
            assert not record["phases"]
        swing = record["swing"]
        packet = swing["packet"]
        assert (packet["protocol"], packet["body"], packet["serial"]) == ("classic", body, record["serial"])
        assert packet["action"] in (4, 5, 6)
        expected = ("FlipperAlert", "Attack", "TuskThrust") if walrus else ("Attack", "Attack2", "WingRake")
        assert swing["clip"] == expected[packet["action"] - 4]
    return digest(path)


def verify_cases(body, cases, groups):
    flags = (0, 4, 64, 68) if body == 60 else (0, 64)
    expected = {(mode, kind, variant) for mode in flags for kind in TYPES[body] for variant in (0, 1, 255)}
    assert len(cases) == len(expected)
    assert {(case["flags"], case["type"], case["variation"]) for case in cases} == expected
    for case in cases:
        action, variation, flags = str(case["type"]), case["variation"], case["flags"]
        mode = "0" if flags & 68 else "1"
        choices = groups[mode].get(action, groups["0"][action])
        classic = ""
        if body == 60:
            if action == "5":
                classic = "WingLift" if variation % 2 else "Fidget"
            elif action == "8":
                classic = "DragonDip"
        assert case["classic"] == classic
        assert case["enhanced"] == (choices[variation % len(choices)] if variation <= 127 else classic)
