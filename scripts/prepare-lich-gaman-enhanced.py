# SPDX-License-Identifier: GPL-3.0-or-later
"""Seal the Lich and Gaman fits and their native observations."""

import runpy


SPRITES = {
    24: {
        23: ("LichCoilingRise", 50, "e90db2870200403f771e12d826f5daf579e560ba07264b352eeb45baf65edcee"),
        28: ("LichRaisedWard", 30, "d546ca5509c47c35042ada0d214ec57becc48b358e5ac5728bc6750cf1bdb66d"),
    },
    248: {
        1: ("GamanLowWatch", 40, "9e731e6febd8e2f4ac610fcbd7a9866af32342421cce9b9144b227660507647d"),
        4: ("GamanShoulderLunge", 55, "d4bc15afb7a17ee9c390a23f1647e5681763c02a1b6c5729a373a5759a36ce8f"),
        11: ("GamanNoseDip", 55, "844ea7cbc0ba0fd1a37afaaabaf5b4dfceb39f17cac18bd06f863fe134f94a46"),
        15: ("GamanHornRecoil", 35, "25a81d908480c7f6d11a4077f7fc737b83be032951caa5e531d8c7e8e587aefc"),
        23: ("GamanRearAndSettle", 65, "bc1ca8f0225b22c7cb13d6bd6a12f7bf79289a48a560171dd1586109a91dafe9"),
        27: ("GamanShortShove", 70, "0b1c55f9638f7fd9f155c446cfdef33b7a6e79413ee25ee318966efb8185e001"),
        28: ("GamanHeadAlert", 45, "d37b76589a805befc1bec83012846b9b65d7e4cacb52ea758754612cac0891b6"),
    },
}
MEMBERS = {24: "0x1ded1dd5d47cc65f", 248: "0xfaf756f3acd8174c"}
TYPES = {24: (8, 15), 248: (2, 5, 8, 11, 14, 15)}
FORMS = {"lich": ("Lich", 24, 0x8035), "gaman": ("Gaman", 248, 0x455)}


def prepare_lich_gaman(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    stage = staged or root
    work = root / "work/creatures"
    scenes = work / "native-form-audit/enhanced-source-gaps/lich-gaman"
    name_hash = runpy.run_path(str(root / "scripts/audit-classic-parity.py"))["name_hash"]
    assert MEMBERS == {body: hex(name_hash(f"build/animationsequence/{body:08d}.bin")) for body in SPRITES}
    groups = {}
    for body, clips in SPRITES.items():
        groups.update(common["source_tables"](root, source, {body: clips}, TYPES[body], member_hashes=MEMBERS))
    results = read(scenes / "terrain-receipt.json")
    assert results["script_sha256"] == digest(stage / "scripts/test-lich-gaman-enhanced.gd")
    terrain = results["bodies"]
    rendered = read(scenes / "motion-render-receipt.json")
    assert set(map(int, terrain)) == set(map(int, rendered)) == SPRITES.keys()
    rows, copies = {}, {}
    for body, source_groups in SPRITES.items():
        clips = [clip for clip, _, _ in source_groups.values()]
        result = terrain[str(body)]
        render = rendered[str(body)]
        assert result["decoded"] == 24 * len(TYPES[body])
        assert result["classic"] == 18 * len(TYPES[body]) and result["hues"] == 3
        assert result["poses"] == 465 * len(clips) and result["falls"] == 30 * len(clips)
        assert result["maximum_death_jump"] < .002 and result["interruptions"] == (3 if body == 24 else 0)
        assert set(clips) == result["terrain"].keys() == set(render["clips"])
        assert all(pose["gap"] >= .0019 and pose["render_gap"] >= 0 for pose in result["terrain"].values())
        assert render["poses"] == 8 * len(clips) and render["scene_sha256"] == result["hashes"]["modern"]
        if body == 24:
            assert 0 < render["initial_rise_box_pixels"] < render["minimum_foreground_box_pixels"]
            rise = result["terrain"]["LichCoilingRise"]
            assert rise["minimum"] < .15 and rise["maximum"] > 2.2 and rise["staff_floor"] > .002
        assets = {name: scenes / f"{body}-{name}.scn" for name in ("original", "rounded", "modern")}
        rows[str(body)], local = common["fitted_row"](
            root / "Viewer", body, groups[body], clips, assets, result["hashes"]
        )
        copies.update(local)
    return rows, copies, verify_native(root, stage, scenes, work, groups, terrain, common)


def verify_native(root, stage, scenes, work, groups, terrain, common):
    read, digest = common["read"], common["sha"]
    folder = work / "native-lich-gaman-enhanced"
    path = folder / "lich-gaman-native.json"
    native = read(path)
    runtime = read(folder / "lich-gaman-native-runtime.json")
    assert digest(path) == runtime["report_sha256"].lower()
    assert digest(root / "Server/runtime/Server.dll") == runtime["server_sha256"].lower()
    assert digest(root / "Server/runtime/Assemblies/UOContent.dll") == runtime["content_sha256"].lower()
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    assert digest(fixture) == runtime["fixture_sha256"].lower()
    assert digest(folder / "NativeLichGamanLive.gd") == native["test_sha256"]
    assert digest(scenes / "test-lich-gaman-enhanced.gd") == native["inputs_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["checks"] == 211 and native["records"].keys() == FORMS.keys()
    for form, record in native["records"].items():
        name, body, hue = FORMS[form]
        lich = body == 24
        filename = f"SourceEnhanced{name}Visual.gd"
        trial = scenes / filename
        assert trial.read_text(encoding="utf-8") == (stage / "Viewer/Presentation" / filename).read_text(encoding="utf-8")
        assert digest(trial) == native["renderers"][form]
        assert record["class"] == name and record["hue"] == 0 and record["stock_weapon"] == "Fists"
        assert record["can_move"] and not record["can_swim"] and record["tamable"] == (not lich)
        assert len(record["step_delta"]) == 2 and max(map(abs, record["step_delta"])) == 1
        assert record["staff_loot"] == lich and record["horns_loot"] in ((0,) if lich else (1, 2))
        assert record["corpse_body"] == body and record["corpse_hue"] == hue and record["corpse"] >= 0x40000000
        phase, = record["phases"]
        assert phase["body"] == body and phase["asset_sha256"] == terrain[str(body)]["hashes"]["modern"]
        verify_cases(body, phase["cases"], groups[body])
        packet = record["swing"]["packet"]
        assert (packet["protocol"], packet["body"], packet["serial"]) == ("classic", body, record["serial"])
        if lich:
            assert packet["action"] in (4, 5, 6)
            assert record["swing"]["clip"] == ("Attack", "Attack2", "Attack3")[packet["action"] - 4]
        else:
            assert packet["action"] == 5 and record["swing"]["clip"] == "Attack"
    return digest(path)


def verify_cases(body, cases, groups):
    expected = {(flags, kind, variant) for flags in (0, 64) for kind in TYPES[body] for variant in (0, 1, 255)}
    assert len(cases) == len(expected)
    assert {(case["flags"], case["type"], case["variation"]) for case in cases} == expected
    for case in cases:
        action, variation, flags = str(case["type"]), case["variation"], case["flags"]
        mode = "0" if flags else "1"
        choices = groups[mode].get(action, groups["0"][action])
        classic = "Pillage" if body == 24 and action == "8" else ""
        assert case["classic"] == classic
        assert case["enhanced"] == (choices[variation % len(choices)] if variation <= 127 else classic)
