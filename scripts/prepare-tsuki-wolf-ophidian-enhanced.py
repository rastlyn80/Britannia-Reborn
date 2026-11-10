# SPDX-License-Identifier: GPL-3.0-or-later
"""Validate fitted Tsuki Wolf and Ophidian actions against source and native evidence."""

import runpy


SPRITES = {
    250: {
        12: ("TsukiTripleRake", 50, "34a569808b1eb58f35f2414a7232811e2f0adae4f6168ce27e7912a4bdad5533"),
        23: ("TsukiUnfold", 45, "d3c30fa73f059dd1dc171847b11ec5d9172c0358d0240896fd0d358c32138fec"),
        26: ("TsukiThreeWayWatch", 45, "cfcf9727fecc9067a47bc0315651eadccf0a8cf208bb100cb0ea09e1cc14ad61"),
        27: ("TsukiHighGuard", 50, "bec60765b9134f03f884712bad23639aff1d5916ef567501ed4dfccd03b7de44"),
        28: ("TsukiPackAlert", 30, "a28a64badb75c83a7353bd3a17aa8e71a72c8127c993da2570523fa52882707c"),
    },
    86: {
        12: ("OphidianOverheadThrust", 50, "ec0bc4e734e4c116d90d853f81680434d3dbe10a0456adac9c248d78a4148950"),
        23: ("OphidianUncoilRise", 50, "a9410df70915be8a5689f1d62431b2723e63973109d6cdfe17c13f8d5fbdc7f5"),
        26: ("OphidianShaftWatch", 50, "baeeb400b01f53c42f55b8b52ac314c35de98ee5821af24dbcbeed75adccc3fc"),
        27: ("OphidianHighGuard", 50, "236f4c27fda4d0aa3ef703f2beb0e9888746ef07421f8e511a8efcc03625c05c"),
        28: ("OphidianBladeAlert", 45, "becd8b7809091a3cf22d65ecd2a1fc4b7ae3d5ad54ad304cb0cd8ee07127e474"),
    },
}
MEMBERS = {250: "0x685dc041aaa29e9e", 86: "0xc53286e2a2e80794"}
TYPES = (5, 8, 11, 15)
FORMS = {
    "wolf": ("TsukiWolf", 250, 0x8035, 4, 28, False),
    "warrior": ("OphidianWarrior", 86, 0x455, 1, 0, False),
    "knight": ("OphidianKnight", 86, 0x8035, 2, 0, True),
}
RENDERERS = {250: "TsukiWolf", 86: "Ophidian"}
FAMILY = "tsuki-wolf-ophidian"
TEST = f"test-{FAMILY}-enhanced.gd"


def prepare_tsuki_wolf_ophidian(root, source, common, staged=None):
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
    groups = common["source_tables"](root, source, SPRITES, TYPES, member_hashes=MEMBERS)
    rows, copies = {}, {}
    for body, source_groups in SPRITES.items():
        clips = [clip for clip, _, _ in source_groups.values()]
        result, render = terrain[str(body)], rendered[str(body)]
        treatments = ("original", "rounded", "modern")
        assert (result["decoded"], result["classic"], result["poses"], result["falls"], result["hues"]) == (
            96, 72, 2325, 150, 3
        )
        assert result["maximum_death_jump"] < .002
        assert set(clips) == set(render["clips"]) == result["terrain"].keys()
        assert all(pose["gap"] >= (.0039 if body == 250 else .0029) for pose in result["terrain"].values())
        assert render["poses"] == 40 and render["scene_sha256"] == result["hashes"]["modern"]
        assert render["minimum_foreground_box_pixels"] >= 1000
        assert geometry[str(body)].keys() == result["hashes"].keys() == set(treatments)
        for treatment, proof in geometry[str(body)].items():
            assert proof["scene_sha256"] == result["hashes"][treatment] and proof["clips"].keys() == set(clips)
            for pose in proof["clips"].values():
                assert pose["poses"] == 41 and pose["minimum_floor"] >= .003
                if body == 250:
                    assert len(pose["jaw_turns"]) == 3 and min(pose["jaw_turns"]) > .15
                else:
                    assert pose["blade_intersections"] == 0 and pose["blade_floor"] > .008
                    assert pose["grip_error"] < .00001
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
    assert digest(folder / "NativeTsukiWolfOphidianLive.gd") == native["test_sha256"]
    assert digest(scenes / TEST) == native["inputs_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["checks"] >= 250 and native["records"].keys() == FORMS.keys()
    for form, record in native["records"].items():
        name, body, hue, ribs, hides, poison = FORMS[form]
        renderer = f"SourceEnhanced{RENDERERS[body]}Visual.gd"
        hash_key = "wolf" if body == 250 else "ophidian"
        assert digest(scenes / renderer) == digest(stage / "Viewer/Presentation" / renderer) == native["renderers"][hash_key]
        assert record["class"] == name and record["stock_weapon"] == "Fists"
        assert record["hue"] == 0 or (body == 250 and 1801 <= record["hue"] <= 1908)
        assert record["can_move"] and not record["can_swim"] and not record["tamable"]
        assert record["lethal_venom_and_immunity"] == (form == "knight")
        assert len(record["step_delta"]) == 2 and max(map(abs, record["step_delta"])) == 1
        assert record["loot"] == {"ribs": ribs, "regular_hides": hides, "lesser_poison": poison}
        assert record["corpse_body"] == body and record["corpse_hue"] == hue and record["corpse"] >= 0x40000000
        blood = record["blood_bath"]
        if body == 250:
            assert blood["source"] == record["serial"] and blood["target"] != blood["source"]
            assert blood["damage"] == 10 and blood["expired"]
        else:
            assert not blood
        phase, = record["phases"]
        assert phase["body"] == body and phase["asset_sha256"] == terrain[str(body)]["hashes"]["modern"]
        verify_cases(phase["cases"], groups[body])
        swing = record["swing"]
        packet = swing["packet"]
        assert (packet["protocol"], packet["body"], packet["serial"]) == ("classic", body, record["serial"])
        assert packet["action"] in (4, 5, 6) and swing["clip"]
    return digest(path)


def verify_cases(cases, groups):
    expected = {(flags, kind, variant) for flags in (0, 64) for kind in TYPES for variant in (0, 1, 255)}
    assert len(cases) == len(expected)
    assert {(case["flags"], case["type"], case["variation"]) for case in cases} == expected
    for case in cases:
        action, variation, flags = str(case["type"]), case["variation"], case["flags"]
        mode = "0" if flags else "1"
        choices = groups[mode].get(action, groups["0"][action])
        assert case["enhanced"] == (choices[variation % len(choices)] if variation <= 127 else case["classic"])

