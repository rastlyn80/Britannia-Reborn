# SPDX-License-Identifier: GPL-3.0-or-later
"""Check the Evil Mage and Plague Beast fits and their native witnesses."""

import runpy


SPRITES = {
    124: {
        23: ("EvilMageManifest", 50, "b35926e0155c9c713bcdeeb708bd32eed9ba47ead0047b1846ee97e528d8417d"),
        28: ("EvilMageCrossedWard", 35, "0d5200b2d8cf0c2b2b4873c1cfc906c8acce1bdcb8917875a02532c6b0511b9f"),
    },
    775: {
        4: ("PlagueBeastMawLunge", 45, "5703b00b5b274fd1298284528190a09819c1940025f8ba3c7a1a004a2c35f18d"),
        23: ("PlagueBeastHatch", 50, "d6b1b6a602c04d6f3f0a9cdb9155cf86bb27cffeecd41664b0bbe509dcb6d5ad"),
        25: ("PlagueBeastFeedingFeelers", 50, "5d521babb8304da9cab135dd4fdfa1609afaf29f27465560b7b880497cbe54b5"),
        26: ("PlagueBeastForearmWatch", 45, "f5f38c0ab156f2eb6ec979b37546ba18ffe37e076033b5a95c1b78c9c0e52a01"),
        27: ("PlagueBeastTongueDisplay", 45, "7ee92f5dd2f0873e165d2e9f018f0b5459de4f2d747d9af00bcbb91024e7e2ef"),
        28: ("PlagueBeastTailAlert", 35, "7accaff59ea676e8e96126197ba69c04b8d42d7d545410497016d2de065a1261"),
    },
}
MEMBERS = {124: "0x275a76745571c12b", 775: "0xe2104fab9e1cdd4"}
TYPES = {124: (8, 15), 775: (5, 8, 11, 14, 15)}
FORMS = {
    "mage": ("EvilMage", 124, 0x455, 1),
    "beast": ("PlagueBeast", 775, 0x8035, 0),
    "lord": ("PlagueBeastLord", 775, 0x455, 0),
}
RENDERERS = {124: ("mage", "EvilMage"), 775: ("beast", "PlagueBeast")}
FAMILY = "evil-mage-plague-beast"
TEST = f"test-{FAMILY}-enhanced.gd"


def prepare_evil_mage_plague_beast(root, source, common, staged=None):
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
        assert result["maximum_death_jump"] < .002 and result["interrupted_growth"] == 6
        assert set(clips) == set(render["clips"]) == result["terrain"].keys()
        assert all(pose["gap"] >= .0029 for pose in result["terrain"].values())
        assert render["poses"] == 10 * count and render["scene_sha256"] == result["hashes"]["modern"]
        assert render["minimum_foreground_box_pixels"] >= (10 if body == 124 else 65)
        assert geometry[str(body)].keys() == result["hashes"].keys() == set(treatments)
        for treatment, proof in geometry[str(body)].items():
            assert proof["scene_sha256"] == result["hashes"][treatment] and proof["clips"].keys() == set(clips)
            assert all(pose["poses"] == 41 and pose["minimum_supported"] > .003 for pose in proof["clips"].values())
            rise = proof["clips"][SPRITES[body][23][0]]
            assert 0.0 < rise["starting_top"] < rise["maximum_top"] * .13
            if body == 775:
                assert proof["clips"]["PlagueBeastMawLunge"]["head_horizontal_range"] > .65
        assets = {name: scenes / f"{body}-{name}.scn" for name in treatments}
        rows[str(body)], local = common["fitted_row"](
            root / "Viewer", body, groups[body], clips, assets, result["hashes"]
        )
        copies.update(local)
    assert digest(scenes / "CreatureGrowthRecovery.gd") == digest(stage / "Viewer/Presentation/CreatureGrowthRecovery.gd")
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
    assert digest(folder / "NativeEvilMagePlagueBeastLive.gd") == native["test_sha256"]
    assert digest(scenes / TEST) == native["inputs_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["checks"] >= 250 and native["records"].keys() == FORMS.keys()
    for form, record in native["records"].items():
        name, body, hue, ribs = FORMS[form]
        key, family = RENDERERS[body]
        renderer = f"SourceEnhanced{family}Visual.gd"
        assert digest(scenes / renderer) == digest(stage / "Viewer/Presentation" / renderer) == native["renderers"][key]
        assert record["class"] == name and record["stock_weapon"] == "Fists" and record["hue"] == 0
        assert record["can_move"] and not record["can_swim"] and not record["tamable"]
        assert record["mage"] == (form == "mage") and record["plague_beast"] == (form == "beast")
        assert len(record["step_delta"]) == 2 and max(map(abs, record["step_delta"])) == 1
        assert record["loot"] == {"ribs": ribs, "regular_hides": 0}
        assert record["corpse_body"] == body and record["corpse_hue"] == hue and record["corpse"] >= 0x40000000
        phase, = record["phases"]
        assert phase["body"] == body and phase["asset_sha256"] == terrain[str(body)]["hashes"]["modern"]
        verify_cases(body, phase["cases"], groups[body])
        swing, feeding = record["swing"], record["feeding"]
        if form == "mage":
            assert swing["spell_damage"] > 0 and swing["native_cast_actions"] == 0 and not feeding
        else:
            packet = swing["packet"]
            assert (packet["protocol"], packet["body"], packet["serial"]) == ("classic", body, record["serial"])
            assert packet["action"] in (4, 5, 6) and swing["clip"]
        if form == "beast":
            assert feeding["target"] == swing["target"] and feeding["poison_melee_damage"] > 0
            assert feeding["corpse"] >= 0x40000000 and feeding["maximum_health_after"] > feeding["maximum_health_before"]
        else:
            assert not feeding
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

