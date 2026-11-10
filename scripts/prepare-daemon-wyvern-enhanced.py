# SPDX-License-Identifier: GPL-3.0-or-later
"""Validate Daemon and Wyvern motion packages against local source and runtime evidence."""

import runpy


SPRITES = {
    9: {
        23: ("DaemonFoldedRise", 55, "162a25fc717e153bd9410ec4b4f2e65e94bb8f72705569b791093e1d16bebc4b"),
        26: ("DaemonTailWatch", 45, "32cd03de594569357948227323ed44a10bc57100bda4fb8e8c6a293ebbdb73a1"),
        27: ("DaemonWingRebuff", 55, "14c57593a5e6f61f1b7b9c66effc527afb874e0d04abaf2b2bdd542f74a50043"),
        28: ("DaemonWingAlert", 55, "58e2557029a931d66c587602a9fee03fdcd7ce53cfc7a98e90cb3d4b05c651e4"),
    },
    62: {
        12: ("WyvernNeckThrust", 70, "6dfe2ac374e1c1f57b669568550a2fad32f8a2cd3c01c7d86a5817c6c8ef9a16"),
        23: ("WyvernWingRise", 50, "fb3794737576e22c580e40c043f3cb87f05bc207b724f0b48ee19bb472c31dcb"),
        26: ("WyvernTailWatch", 70, "27bfbcc4c02e50562753318b0bf05e807af4e21dea858f19c7b0aadeddb6e783"),
        27: ("WyvernWingsAndFangs", 70, "dfb3d11f62da39317b9b1f5e72a315eabdda3644580fd0be42732466d86486ba"),
        28: ("WyvernWingGuard", 40, "5a2b7c1b539526652a4b855fa3bd7f867bc84045644e6450b1951a107de74399"),
    },
}
MEMBERS = {9: "0x7fecdbbcf12f25ce", 62: "0x80fca6cf63d1664"}
TYPES = {9: (5, 8, 15), 62: (5, 8, 11, 15)}
FORMS = {"daemon": ("Daemon", 9, 0x8035), "wyvern": ("Wyvern", 62, 0x455)}


def prepare_daemon_wyvern(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    stage = staged or root
    work = root / "work/creatures"
    scenes = work / "native-form-audit/enhanced-source-gaps/daemon-wyvern"
    name_hash = runpy.run_path(str(root / "scripts/audit-classic-parity.py"))["name_hash"]
    assert MEMBERS == {body: hex(name_hash(f"build/animationsequence/{body:08d}.bin")) for body in SPRITES}
    groups = {}
    for body, clips in SPRITES.items():
        groups.update(common["source_tables"](
            root, source, {body: clips}, TYPES[body], flight_fallback=True, member_hashes=MEMBERS
        ))
    results = read(scenes / "terrain-receipt.json")
    assert results["script_sha256"] == digest(stage / "scripts/test-daemon-wyvern-enhanced.gd")
    terrain = results["bodies"]
    rendered = read(scenes / "motion-render-receipt.json")
    geometry = read(scenes / "first-pose-receipt.json")
    assert set(map(int, terrain)) == set(map(int, rendered)) == set(map(int, geometry)) == SPRITES.keys()
    rows, copies = {}, {}
    for body, source_groups in SPRITES.items():
        clips = [clip for clip, _, _ in source_groups.values()]
        result, render = terrain[str(body)], rendered[str(body)]
        assert result["decoded"] == 48 * len(TYPES[body])
        assert result["classic"] == 18 * len(TYPES[body]) and result["hues"] == 3
        assert result["poses"] == 930 * len(clips) and result["falls"] == 60 * len(clips)
        assert result["air_falls"] == 30 * len(clips) and result["maximum_death_jump"] < .002
        assert result["minimum_ground_gap"] >= .0029
        assert result["minimum_held_air_gap"] >= (2.0 if body == 9 else .80)
        assert set(clips) == set(render["clips"]) and render["minimum_foreground_box_pixels"] >= 1000
        assert render["poses"] == 8 * len(clips) and render["scene_sha256"] == result["hashes"]["modern"]
        for treatment, proof in geometry[str(body)].items():
            assert proof["scene_sha256"] == result["hashes"][treatment] and set(proof["clips"]) == set(clips)
            assert all(pose["poses"] == 41 and pose["minimum_gap"] >= .0079 for pose in proof["clips"].values())
        assets = {name: scenes / f"{body}-{name}.scn" for name in ("original", "rounded", "modern")}
        row, local = common["fitted_row"](root / "Viewer", body, groups[body], clips, assets, result["hashes"])
        row["flight_falls_back_to_combat"] = True
        rows[str(body)] = row
        copies.update(local)
    return rows, copies, verify_native(root, stage, scenes, work, groups, terrain, common)


def verify_native(root, stage, scenes, work, groups, terrain, common):
    read, digest = common["read"], common["sha"]
    folder = work / "native-daemon-wyvern-enhanced"
    path = folder / "daemon-wyvern-native.json"
    native = read(path)
    runtime = read(folder / "daemon-wyvern-native-runtime.json")
    assert digest(path) == runtime["report_sha256"].lower()
    assert digest(root / "Server/runtime/Server.dll") == runtime["server_sha256"].lower()
    assert digest(root / "Server/runtime/Assemblies/UOContent.dll") == runtime["content_sha256"].lower()
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    assert digest(fixture) == runtime["fixture_sha256"].lower()
    assert digest(folder / "NativeDaemonWyvernLive.gd") == native["test_sha256"]
    assert digest(scenes / "test-daemon-wyvern-enhanced.gd") == native["inputs_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    renderer = "SourceEnhancedWingedVisual.gd"
    assert digest(scenes / renderer) == digest(stage / "Viewer/Presentation" / renderer)
    assert native["checks"] >= 319 and native["records"].keys() == FORMS.keys()
    for form, record in native["records"].items():
        name, body, hue = FORMS[form]
        wyvern = body == 62
        assert digest(scenes / renderer) == native["renderers"][form]
        assert record["class"] == name and record["hue"] == 0 and record["stock_weapon"] == "Fists"
        assert record["can_move"] and record["can_fly"] and not record["can_swim"] and not record["tamable"]
        assert len(record["step_delta"]) == 2 and max(map(abs, record["step_delta"])) == 1
        assert record["poison_immune"] == (3 if wyvern else 1) and record["hit_poison"] == (3 if wyvern else -1)
        assert record["corpse_body"] == body and record["corpse_hue"] == hue and record["corpse"] >= 0x40000000
        phase, = record["phases"]
        assert phase["body"] == body and phase["asset_sha256"] == terrain[str(body)]["hashes"]["modern"]
        verify_cases(body, phase["cases"], groups[body])
        swing = record["swing"]
        packet = swing["packet"]
        assert (packet["protocol"], packet["body"], packet["serial"]) == ("classic", body, record["serial"])
        assert packet["action"] in (4, 5, 6)
        assert swing["clip"] == ("Attack" if wyvern else ("Attack", "Attack2", "LowRake")[packet["action"] - 4])
        assert swing["target_poison"] == (3 if wyvern else -1)
    return digest(path)


def verify_cases(body, cases, groups):
    expected = {(flags, kind, variant) for flags in (0, 4, 64, 68) for kind in TYPES[body] for variant in (0, 1, 255)}
    assert len(cases) == len(expected)
    assert {(case["flags"], case["type"], case["variation"]) for case in cases} == expected
    for case in cases:
        action, variation, flags = str(case["type"]), case["variation"], case["flags"]
        mode = "0" if flags & 68 else "1"
        choices = groups[mode].get(action, groups["0"][action])
        classic = ""
        if action == "5":
            tail = "TailPause" if body == 9 else "WingRear"
            classic = tail if variation % 2 else "Fidget"
        elif action == "8":
            classic = "DaemonWingCheck" if body == 9 else "Fidget"
        assert case["classic"] == classic
        assert case["enhanced"] == (choices[variation % len(choices)] if variation <= 127 else classic)
