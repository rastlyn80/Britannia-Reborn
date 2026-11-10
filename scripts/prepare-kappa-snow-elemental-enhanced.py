# SPDX-License-Identifier: GPL-3.0-or-later
"""Check the Kappa and Snow Elemental fits and their native witnesses."""

import runpy


SPRITES = {
    240: {
        12: ("KappaShellLunge", 45, "b0560570ea2b021d816f5ef27ae43923e057215bc9d618c246ad202bacd3e10f"),
        23: ("KappaShellRise", 50, "55f1e14d1c66830d490d00e0b0a9a51d458f5a6846c70b14fbd5f44050439f07"),
        26: ("KappaSnoutWatch", 50, "f69fc66d2e60d2d954572522bde99c7cc458819401959caffc0414762de34838"),
        27: ("KappaSpreadGuard", 40, "a6c43226206aef6adc6c2cbb7bd82e9d308ec17c686471676a2793a789d5818b"),
        28: ("KappaStartledHop", 40, "4301eab7f458495c73f00179b79b1d594e8b5aabd14549605d1fd8228b4beba2"),
    },
    163: {
        23: ("SnowElementalPackRise", 50, "ef42afb2474aa3566d52be3f5f17e8e24c194a5962749af6b4bcc6e309833d02"),
        28: ("SnowElementalShoulderAlert", 30, "7b4780e0d0866053ecfead503f6700ef349633210f5b0d492949da7364f8d4f7"),
    },
}
MEMBERS = {240: "0x85bd8b989dd782aa", 163: "0x3616376e99340390"}
TYPES = {240: (5, 8, 11, 15), 163: (8, 15)}
FORMS = {
    "kappa": ("Kappa", 240, 0x8035, {"fish": 3, "black_pearl": 0, "iron_ore": 0}),
    "snow": ("SnowElemental", 163, 0x455, {"fish": 0, "black_pearl": 3, "iron_ore": 3}),
}
FAMILY = "kappa-snow-elemental"
TEST = f"test-{FAMILY}-enhanced.gd"


def prepare_kappa_snow_elemental(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    stage = staged or root
    work = root / "work/creatures"
    scenes = work / "native-form-audit/enhanced-source-gaps" / FAMILY
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
        clips = [clip for clip, _, _ in source_groups.values()]
        result, render = terrain[str(body)], rendered[str(body)]
        treatments = ("original", "rounded", "modern")
        count, types = len(clips), len(TYPES[body])
        assert result["decoded"] == 24 * types and result["classic"] == 18 * types and result["hues"] == 3
        assert result["poses"] == 465 * count and result["falls"] == 30 * count
        assert result["maximum_death_jump"] < .002 and result["interrupted_growth"] == (6 if body == 163 else 0)
        assert set(clips) == set(render["clips"]) == result["terrain"].keys()
        assert all(pose["gap"] >= .0029 for pose in result["terrain"].values())
        assert render["poses"] == 10 * count and render["scene_sha256"] == result["hashes"]["modern"]
        assert render["minimum_foreground_box_pixels"] >= 1000
        assert geometry[str(body)].keys() == result["hashes"].keys() == set(treatments)
        for treatment, proof in geometry[str(body)].items():
            assert proof["scene_sha256"] == result["hashes"][treatment] and proof["clips"].keys() == set(clips)
            assert all(pose["poses"] == 41 and pose["minimum_supported"] > .003 for pose in proof["clips"].values())
            rise = proof["clips"][SPRITES[body][23][0]]
            if body == 163:
                assert .22 < rise["starting_top"] < .29 and rise["maximum_top"] > 2.10
            else:
                hop = proof["clips"]["KappaStartledHop"]
                assert .41 < hop["maximum_floor"] < .46
        assets = {name: scenes / f"{body}-{name}.scn" for name in treatments}
        rows[str(body)], local = common["fitted_row"](
            root / "Viewer", body, groups[body], clips, assets, result["hashes"]
        )
        copies.update(local)
    return rows, copies, verify_native(root, stage, scenes, work, groups, terrain, common)


def verify_native(root, stage, scenes, work, groups, terrain, common):
    read, digest = common["read"], common["sha"]
    folder = work / f"native-{FAMILY}-enhanced"
    path = folder / f"{FAMILY}-native.json"
    native = read(path)
    runtime = read(folder / f"{FAMILY}-native-runtime.json")
    assert digest(path) == runtime["report_sha256"].lower()
    assert digest(root / "Server/runtime/Server.dll") == runtime["server_sha256"].lower()
    assert digest(root / "Server/runtime/Assemblies/UOContent.dll") == runtime["content_sha256"].lower()
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    assert digest(fixture) == runtime["fixture_sha256"].lower()
    assert digest(folder / "NativeKappaSnowElementalLive.gd") == native["test_sha256"]
    assert digest(scenes / TEST) == native["inputs_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["checks"] >= 185 and native["records"].keys() == FORMS.keys()
    for form, record in native["records"].items():
        name, body, hue, loot = FORMS[form]
        renderer = f"SourceEnhanced{name}Visual.gd"
        assert digest(scenes / renderer) == digest(stage / "Viewer/Presentation" / renderer) == native["renderers"][form]
        assert record["class"] == name and record["stock_weapon"] == "Fists" and record["hue"] == 0
        assert record["can_move"] and not record["can_swim"] and not record["tamable"]
        assert record["bleed_immune"] == (form == "snow")
        assert len(record["step_delta"]) == 2 and max(map(abs, record["step_delta"])) == 1
        assert record["loot"] == loot
        assert record["corpse_body"] == body and record["corpse_hue"] == hue and record["corpse"] >= 0x40000000
        phase, = record["phases"]
        assert phase["body"] == body and phase["asset_sha256"] == terrain[str(body)]["hashes"]["modern"]
        verify_cases(body, phase["cases"], groups[body])
        swing = record["swing"]
        packet = swing["packet"]
        assert (packet["protocol"], packet["body"], packet["serial"]) == ("classic", body, record["serial"])
        assert packet["action"] in (4, 5, 6) and swing["clip"]
        drain = record["drain_life"]
        if form == "kappa":
            assert drain["source"] == record["serial"] and drain["target"] != drain["source"]
            assert drain["damage"] > 0 and drain["healing"] > 0 and 84 <= drain["mana"] <= 90 and drain["expired"]
        else:
            assert not drain
    return digest(path)


def verify_cases(body, cases, groups):
    expected = {(flags, kind, variant) for flags in (0, 64) for kind in TYPES[body] for variant in (0, 1, 255)}
    assert len(cases) == len(expected)
    assert {(case["flags"], case["type"], case["variation"]) for case in cases} == expected
    for case in cases:
        action, variation, flags = str(case["type"]), case["variation"], case["flags"]
        mode = "0" if flags else "1"
        choices = groups[mode].get(action, groups["0"][action])
        assert case["enhanced"] == (choices[variation % len(choices)] if variation <= 127 else case["classic"])
