# SPDX-License-Identifier: GPL-3.0-or-later
"""Seal the Alligator and Dire Wolf fits and their native observations."""

import runpy


SPRITES = {
    202: {
        1: ("AlligatorLowGape", 50, "b353671329c8182d279002780bf757c6c287e1f68db3743749aafeff17371b48"),
        4: ("AlligatorSideSnap", 35, "b7cdd070ba63ef43f149103581f3318a95d1efb1e91f5ecf084b731696ed8ed5"),
        23: ("AlligatorHiss", 40, "a4027b148e46899a5466e0ae76b56fad7f17e02c8eb61a4317ca471ae7de0d30"),
        25: ("AlligatorQuietStand", 55, "44edbe950187a77a7d17b55377671c584c975b1646da436020fea0d286ce3e5a"),
        26: ("AlligatorRisingTurn", 55, "0b5c7ed0f8452f2230550cf816ee043924206b74893b2e0c720dfc2c076d37aa"),
        27: ("AlligatorTailCurl", 45, "f7cadddadd1ac3f688e19c240af32844f4eca69ef5205391077743744485c92c"),
        28: ("AlligatorLowAlert", 35, "cafa5c2cc9173370745ffce298c02eea2b7e291937dff3ea44ced19de29bd92b"),
    },
    23: {
        4: ("DireWolfForepawSnap", 35, "200685392988d84849d3a522aae56066340ca9847eeef14eaf7bd8aa5a62f2ae"),
        15: ("DireWolfLowRecoil", 40, "a643ce244085d3a85ed2a2300b94793653c445b14d041ee9142301e85067f85f"),
        25: ("DireWolfQuietStand", 50, "0fde3fb2fc50a66d51281ccc31282d3a8a909532a9e826af66c7956848def6d2"),
        26: ("DireWolfScentCheck", 50, "0a213cff1c8bf957769792ab23104d3b7ecd96b2903166943ae3c2dd4bac536b"),
        27: ("DireWolfShortHowl", 50, "28ad95cf024bae62a001e5b6c00df5732dd2a16e923b4869d5d254707282a8a9"),
        28: ("DireWolfAlert", 30, "6d307960caf8294c1cc4bbae6fc97b8e71e1ec331547ce78a5a9dd9ea0ed6d90"),
    },
}
MEMBERS = {202: "0xcc274794e08651aa", 23: "0x48727c661190c61f"}
TYPES = (2, 5, 8, 11, 14, 15)
FORMS = {
    "alligator": ("Alligator", 202, 0x8035, "Alligator"),
    "direwolf": ("DireWolf", 23, 0x455, "DireWolf"),
}


def prepare_alligator_direwolf(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    stage = staged or root
    viewer = root / "Viewer"
    work = root / "work/creatures"
    scenes = work / "native-form-audit/enhanced-source-gaps/alligator-direwolf"
    name_hash = runpy.run_path(str(root / "scripts/audit-classic-parity.py"))["name_hash"]
    assert MEMBERS == {body: hex(name_hash(f"build/animationsequence/{body:08d}.bin")) for body in SPRITES}
    groups = common["source_tables"](root, source, SPRITES, TYPES, member_hashes=MEMBERS)
    results = read(scenes / "terrain-receipt.json")
    assert results["script_sha256"] == digest(stage / "scripts/test-alligator-direwolf-enhanced.gd")
    terrain = results["bodies"]
    rendered = read(scenes / "motion-render-receipt.json")
    assert set(map(int, terrain)) == set(map(int, rendered)) == SPRITES.keys()
    rows, copies = {}, {}
    for body, source_groups in SPRITES.items():
        clips = [clip for clip, _, _ in source_groups.values()]
        result = terrain[str(body)]
        render = rendered[str(body)]
        assert (result["decoded"], result["classic"], result["hues"]) == (144, 108, 3)
        assert result["poses"] == 465 * len(clips) and result["falls"] == 30 * len(clips)
        assert result["maximum_death_jump"] < .002
        assert set(clips) == result["terrain"].keys() == set(render["clips"])
        assert all(pose["gap"] >= .0019 for pose in result["terrain"].values())
        assert render["poses"] == 8 * len(clips) and render["scene_sha256"] == result["hashes"]["modern"]
        assets = {name: scenes / f"{body}-{name}.scn" for name in ("original", "rounded", "modern")}
        rows[str(body)], local = common["fitted_row"](viewer, body, groups[body], clips, assets, result["hashes"])
        copies.update(local)
    proof = verify_native(root, stage, scenes, work, groups, terrain, common)
    return rows, copies, proof


def verify_native(root, stage, scenes, work, groups, terrain, common):
    read, digest = common["read"], common["sha"]
    folder = work / "native-alligator-direwolf-enhanced"
    path = folder / "alligator-direwolf-native.json"
    native = read(path)
    runtime = read(folder / "alligator-direwolf-native-runtime.json")
    assert digest(path) == runtime["report_sha256"].lower()
    assert digest(root / "Server/runtime/Server.dll") == runtime["server_sha256"].lower()
    assert digest(root / "Server/runtime/Assemblies/UOContent.dll") == runtime["content_sha256"].lower()
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    assert digest(fixture) == runtime["fixture_sha256"].lower()
    assert digest(folder / "NativeAlligatorDireWolfLive.gd") == native["test_sha256"]
    assert digest(scenes / "test-alligator-direwolf-enhanced.gd") == native["inputs_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["checks"] == 279 and native["records"].keys() == FORMS.keys()
    for form, record in native["records"].items():
        name, body, hue, renderer = FORMS[form]
        filename = f"SourceEnhanced{renderer}Visual.gd"
        trial = scenes / filename
        assert trial.read_text(encoding="utf-8") == (stage / "Viewer/Presentation" / filename).read_text(encoding="utf-8")
        assert digest(trial) == native["renderers"][form]
        assert record["class"] == name and record["hue"] == 0 and record["stock_weapon"] == "Fists"
        assert record["can_move"] and record["tamable"] and not record["can_swim"]
        assert len(record["step_delta"]) == 2 and max(map(abs, record["step_delta"])) == 1
        assert record["corpse_body"] == body and record["corpse_hue"] == hue and record["corpse"] >= 0x40000000
        phase, = record["phases"]
        assert phase["body"] == body and phase["asset_sha256"] == terrain[str(body)]["hashes"]["modern"]
        verify_cases(phase["cases"], groups[body])
        packet = record["swing"]["packet"]
        assert (packet["protocol"], packet["body"], packet["serial"], packet["action"]) == (
            "classic", body, record["serial"], 5,
        )
        assert record["swing"]["clip"] == "Attack"
    return digest(path)


def verify_cases(cases, groups):
    expected = {(flags, kind, variant) for flags in (0, 64) for kind in TYPES for variant in (0, 1, 255)}
    assert len(cases) == len(expected)
    assert {(case["flags"], case["type"], case["variation"]) for case in cases} == expected
    for case in cases:
        action, variation, flags = str(case["type"]), case["variation"], case["flags"]
        mode = "0" if flags else "1"
        choices = groups[mode].get(action, groups["0"][action])
        assert case["classic"] == ""
        assert case["enhanced"] == (choices[variation % len(choices)] if variation <= 127 else "")
