# SPDX-License-Identifier: GPL-3.0-or-later
"""Check the Giant Rat and Vampire Bat fits and their native witnesses."""

import runpy


SPRITES = {
    215: {
        4: ("GiantRatForwardBite", 25, "165c131492f2d62c7b1ff9e60afd924a68d4766398b3c829fdd9ab61aec57e3e"),
        15: ("GiantRatNoseRecoil", 25, "27794923e63df1f43eccd435e312378654df725e8e6fef0e109d34e327678889"),
        23: ("GiantRatTailUnfurl", 30, "6e3ae9dab50453e9b3413f680415eec72219727ff1b2fce7ce65afb306a9f2c3"),
        25: ("GiantRatForage", 30, "55723441d6caf6eb1e6e6ce708879339b6ed84ff2cb4f621159fc28a2ab2d606"),
        26: ("GiantRatScentCheck", 55, "d4111d0c686dbf428c78040360e178dad98a399d9ed27d5e91cb3fcafeaca046"),
        27: ("GiantRatTailSweep", 25, "0ed7970094ae259cd99ae0d0d5c334de5ceadafe261ff6c4b607299a1fe14a11"),
        28: ("GiantRatNoseAlert", 30, "f833ae1d52b2a0144c2e3401014f18e15861182069864e0cba958c89e84a933d"),
    },
    317: {
        4: ("VampireBatSwoop", 40, "fc8f539ea0f4ca73a33a08308739b29cb85331f57da160fa163c1257f0f928bb"),
        23: ("VampireBatUnfold", 60, "a64f4bbd8231157688260d40478cbfa7ac72f71af13191a5a7664f7b2a44a3ed"),
        25: ("VampireBatWingDip", 35, "6049c9ae2c9726ca8ef7d6863a35260cab16640a3258a924bc123097ad5dc1f9"),
        26: ("VampireBatHoverWatch", 75, "cbdfbcfd48709678f8421796a30459473bb31e303d6b32882127d62aa01fc860"),
    },
}
MEMBERS = {215: "0x5ce4a899103b267", 317: "0xfeb89f39cc686bca"}
TYPES = {215: (2, 5, 8, 11, 14, 15), 317: (5, 8, 11, 14, 15)}
FORMS = {
    "rat": ("GiantRat", 215, 0x8035, {"ribs": 1, "hides": 7}),
    "bat": ("VampireBat", 317, 0x455, {"ribs": 0, "hides": 0}),
}
FAMILY = "giant-rat-vampire-bat"
TEST = f"test-{FAMILY}-enhanced.gd"


def prepare_giant_rat_vampire_bat(root, source, common, staged=None):
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
        groups.update(common["source_tables"](root, source, {body: source_groups}, TYPES[body], flight_fallback=(body == 317),
                                             member_hashes=MEMBERS))
        clips = [clip for clip, _, _ in source_groups.values()]
        result, render = terrain[str(body)], rendered[str(body)]
        treatments = ("original", "rounded", "modern")
        count, types = len(clips), len(TYPES[body])
        assert result["decoded"] == 24 * types and result["classic"] == 18 * types and result["hues"] == 3
        assert result["poses"] == 465 * count and result["falls"] == 30 * count
        assert result["maximum_death_jump"] < .002 and result["flight_fallback"] == (6 if body == 317 else 0)
        assert set(clips) == set(render["clips"]) == result["terrain"].keys()
        assert all(pose["gap"] >= (.074 if body == 317 else .0029) for pose in result["terrain"].values())
        assert render["poses"] == 10 * count and render["scene_sha256"] == result["hashes"]["modern"]
        assert render["minimum_foreground_box_pixels"] >= 1000
        assert geometry[str(body)].keys() == result["hashes"].keys() == set(treatments)
        for treatment, proof in geometry[str(body)].items():
            assert proof["scene_sha256"] == result["hashes"][treatment] and proof["clips"].keys() == set(clips)
            for pose in proof["clips"].values():
                assert pose["poses"] == 61 and pose["minimum_floor"] > (.10 if body == 317 else .002)
                if body == 317:
                    assert pose["width_range"][1] - pose["width_range"][0] > .20
            if body == 215:
                assert proof["clips"]["GiantRatTailUnfurl"]["landmark_travel"] > .34
        assets = {name: scenes / f"{body}-{name}.scn" for name in treatments}
        rows[str(body)], local = common["fitted_row"](
            root / "Viewer", body, groups[body], clips, assets, result["hashes"]
        )
        if body == 317:
            rows[str(body)]["flight_falls_back_to_combat"] = True
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
    assert digest(folder / "NativeGiantRatVampireBatLive.gd") == native["test_sha256"]
    assert digest(scenes / TEST) == native["inputs_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["checks"] >= 250 and native["records"].keys() == FORMS.keys()
    for form, record in native["records"].items():
        name, body, hue, loot = FORMS[form]
        renderer = f"SourceEnhanced{name}Visual.gd"
        assert digest(scenes / renderer) == digest(stage / "Viewer/Presentation" / renderer) == native["renderers"][form]
        assert record["class"] == name and record["stock_weapon"] == "Fists" and record["hue"] == 0
        assert record["can_move"] and not record["can_swim"] and record["tamable"] == (form == "rat")
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
