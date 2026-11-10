# SPDX-License-Identifier: GPL-3.0-or-later
"""Validate the Ice Serpent and Bogling fits against exact source and native evidence."""

import runpy


SPRITES = {
    89: {
        4: ("IceSerpentCoilStrike", 35, "98dac0d8b5ddbd65c593cbfea90ea143605bd425581aa7bae43d8202e23c1544"),
        23: ("IceSerpentEmerge", 55, "dc3e28941d1c671dd83fef46ba5f477ca9f6fe6de2a0c843ad51b068bdf0eda7"),
        28: ("IceSerpentHeadAlert", 35, "1806753f424fcf43897468aa99c2fc47f284f71439e937500d4b019586d5d352"),
    },
    779: {
        23: ("BoglingSprout", 50, "eb16701a6aa11f37921b067f2c5decd7c5201268063a83f357774b6dc16c877e"),
        28: ("BoglingBranchAlert", 35, "2793d8cf97008b7b238533909d07c36dc4ba73909e35d09e9f56e0a682cd2c7d"),
    },
}
MEMBERS = {89: "0xff4b1f8deca1c929", 779: "0x7c421947d8307c75"}
TYPES = {89: (8, 11, 15), 779: (8, 15)}
FORMS = {"ice": ("IceSerpent", 89, 0x8035), "bogling": ("Bogling", 779, 0x455)}
TEST = "test-ice-serpent-bogling-enhanced.gd"


def prepare_ice_serpent_bogling(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    stage = staged or root
    work = root / "work/creatures"
    scenes = work / "native-form-audit/enhanced-source-gaps/ice-serpent-bogling"
    name_hash = runpy.run_path(str(root / "scripts/audit-classic-parity.py"))["name_hash"]
    assert MEMBERS == {body: hex(name_hash(f"build/animationsequence/{body:08d}.bin")) for body in SPRITES}
    receipt = read(scenes / "terrain-receipt.json")
    assert receipt["script_sha256"] == digest(stage / "scripts" / TEST)
    terrain = receipt["bodies"]
    rendered = read(scenes / "motion-render-receipt.json")
    geometry = read(scenes / "first-pose-receipt.json")
    assert set(map(int, terrain)) == set(map(int, rendered)) == set(map(int, geometry)) == SPRITES.keys()
    groups, rows, copies = {}, {}, {}
    for body, source_groups in SPRITES.items():
        groups.update(common["source_tables"](root, source, {body: source_groups}, TYPES[body], member_hashes=MEMBERS))
        ice = body == 89
        clips = [clip for clip, _, _ in source_groups.values()]
        result, render = terrain[str(body)], rendered[str(body)]
        treatments = ("original", "rounded", "modern") if ice else ("modern",)
        count = len(treatments)
        assert result["decoded"] == 8 * len(TYPES[body]) * count
        assert result["classic"] == 6 * len(TYPES[body]) * count and result["hues"] == 3
        assert result["poses"] == 155 * len(clips) * count and result["falls"] == 10 * len(clips) * count
        assert result["maximum_death_jump"] < .002 and result["interrupted_growth"] == (0 if ice else 2)
        assert set(clips) == set(render["clips"]) == result["terrain"].keys()
        assert all(pose["gap"] >= (.0039 if ice else .0029) for pose in result["terrain"].values())
        assert render["poses"] == 8 * len(clips) and render["scene_sha256"] == result["hashes"]["modern"]
        assert render["minimum_foreground_box_pixels"] >= (1000 if ice else 100)
        assert geometry[str(body)].keys() == result["hashes"].keys()
        for treatment, proof in geometry[str(body)].items():
            assert proof["scene_sha256"] == result["hashes"][treatment] and set(proof["clips"]) == set(clips)
            assert all(pose["poses"] == 41 and pose["minimum_supported"] >= .003 for pose in proof["clips"].values())
            rise = proof["clips"]["IceSerpentEmerge" if ice else "BoglingSprout"]
            if ice:
                assert -.40 < rise["minimum_floor"] < -.37 and .02 < rise["starting_top"] < .12 and rise["maximum_top"] > .55
            else:
                assert .10 < rise["starting_top"] < .20 and rise["maximum_top"] > 1.10
        assets = {name: scenes / f"{body}-{name}.scn" for name in treatments}
        rows[str(body)], local = common["fitted_row"](
            root / "Viewer", body, groups[body], clips, assets, result["hashes"]
        )
        copies.update(local)
    return rows, copies, verify_native(root, stage, scenes, work, groups, terrain, common)


def verify_native(root, stage, scenes, work, groups, terrain, common):
    read, digest = common["read"], common["sha"]
    folder = work / "native-ice-serpent-bogling-enhanced"
    path = folder / "ice-serpent-bogling-native.json"
    native = read(path)
    runtime = read(folder / "ice-serpent-bogling-native-runtime.json")
    assert digest(path) == runtime["report_sha256"].lower()
    assert digest(root / "Server/runtime/Server.dll") == runtime["server_sha256"].lower()
    assert digest(root / "Server/runtime/Assemblies/UOContent.dll") == runtime["content_sha256"].lower()
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    assert digest(fixture) == runtime["fixture_sha256"].lower()
    assert digest(folder / "NativeIceSerpentBoglingLive.gd") == native["test_sha256"]
    assert digest(scenes / TEST) == native["inputs_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["checks"] == 157 and native["records"].keys() == FORMS.keys()
    for form, record in native["records"].items():
        name, body, hue = FORMS[form]
        ice = body == 89
        renderer = f"SourceEnhanced{name}Visual.gd"
        assert digest(scenes / renderer) == digest(stage / "Viewer/Presentation" / renderer) == native["renderers"][form]
        assert record["class"] == name and record["hue"] == 0 and record["stock_weapon"] == "Fists"
        assert record["can_move"] and not record["can_swim"] and not record["tamable"]
        assert record["death_adder_charmable"] == ice
        assert len(record["step_delta"]) == 2 and max(map(abs, record["step_delta"])) == 1
        loot = {"ribs": 4, "regular_hides": 0, "spined_hides": 17, "logs": 0, "seed": False} if ice else {
            "ribs": 1, "regular_hides": 7, "spined_hides": 0, "logs": 4, "seed": True}
        assert record["loot"] == loot
        assert record["corpse_body"] == body and record["corpse_hue"] == hue and record["corpse"] >= 0x40000000
        phase, = record["phases"]
        assert phase["body"] == body and phase["asset_sha256"] == terrain[str(body)]["hashes"]["modern"]
        verify_cases(body, phase["cases"], groups[body])
        swing = record["swing"]
        packet = swing["packet"]
        assert (packet["protocol"], packet["body"], packet["serial"]) == ("classic", body, record["serial"])
        assert packet["action"] in (4, 5, 6)
        assert swing["clip"] == ("Attack" if ice else ("Attack", "Attack2", "Attack3")[packet["action"] - 4])
    return digest(path)


def verify_cases(body, cases, groups):
    expected = {(flags, kind, variant) for flags in (0, 64) for kind in TYPES[body] for variant in (0, 1, 255)}
    assert len(cases) == len(expected)
    assert {(case["flags"], case["type"], case["variation"]) for case in cases} == expected
    for case in cases:
        action, variation, flags = str(case["type"]), case["variation"], case["flags"]
        mode = "0" if flags else "1"
        choices = groups[mode].get(action, groups["0"][action])
        classic = "Pillage" if body == 779 and action == "8" else ""
        assert case["classic"] == classic
        assert case["enhanced"] == (choices[variation % len(choices)] if variation <= 127 else classic)
