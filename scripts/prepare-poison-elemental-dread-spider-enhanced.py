# SPDX-License-Identifier: GPL-3.0-or-later
"""Seal the Poison Elemental and Dread Spider fits and native witnesses."""

FAMILY = "poison-elemental-dread-spider"
TEST = f"test-{FAMILY}-enhanced.gd"
MEMBERS = {162: "0x21cd14bd3218572e", 11: "0x30af4ffe1c0bfb4b"}
SPRITES = {
    162: {
        23: ("PoisonElementalCrouchedRise", 55, "f654c2c6ab6a42427e5a76d2a84b0133807b5012f0e5d916873aaff0f2e94919"),
        28: ("PoisonElementalRaisedKneeGuard", 25, "ebbff449fdf6f7d6979ec58ef232383a75afc1c1d1d60dfd5bedb1490869bab6"),
    },
    11: {
        12: ("DreadSpiderFrontExtend", 55, "f3dcdb18204303ec99e66147cc5ae594df009c692553a110768ee7d4e5d9c710"),
        23: ("DreadSpiderSilkEmergence", 60, "ff4a7f7c5e212100458eaa94d79c557a8232b2082316283a0a66bb90e430e069"),
        26: ("DreadSpiderQuietTwitch", 45, "16a6f735d2912b446160c8f2ef270c11eb39d7d4a8e05fe154fa4f30984503ac"),
        27: ("DreadSpiderRockBack", 55, "58b0881436c44a02e6f71541f43ecc929becc865d5cb4d7f32640702f2784b71"),
        28: ("DreadSpiderAbdomenAlert", 40, "589985ca8d8f16a146fb82028573ae22860381252a961b46388976bc934bbd47"),
    },
}
TYPES = {162: (8, 15), 11: (5, 8, 11, 15)}
FORMS = {"poison": ("PoisonElemental", 162, 0x8035, {"nightshade": 4, "spider_silk": 0}),
         "spider": ("DreadSpider", 11, 0x455, {"nightshade": 0, "spider_silk": 8})}
TREATMENTS = ("original", "rounded", "modern")


def prepare_poison_elemental_dread_spider(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    stage = staged or root
    work = root / "work/creatures"
    scenes = work / "native-form-audit/enhanced-source-gaps" / FAMILY
    receipt = read(scenes / "terrain-receipt.json")
    assert digest(scenes / TEST) == receipt["test_sha256"] == digest(stage / "scripts" / TEST)
    terrain = receipt["bodies"]
    rendered = read(scenes / "motion-render-receipt.json")
    assert terrain.keys() == rendered.keys() == {str(body) for body in SPRITES}
    groups, rows, copies = {}, {}, {}
    for body, source_groups in SPRITES.items():
        groups.update(common["source_tables"](root, source, {body: source_groups}, TYPES[body], member_hashes=MEMBERS))
        result, render = terrain[str(body)], rendered[str(body)]
        clips = [clip for clip, _, _ in source_groups.values()]
        assert (result["poses"], result["falls"]) == (465 * len(clips), 30 * len(clips))
        assert (result["routes"], result["classic"]) == (24 * len(TYPES[body]), 18 * len(TYPES[body]))
        assert result["gap"] >= .0018 and result["jump"] < .002
        assert result["hashes"].keys() == set(TREATMENTS)
        assert render["scene_sha256"] == result["hashes"]["modern"]
        assert render["poses"] == 10 * len(clips) and set(render["clips"]) == set(clips)
        assert render["minimum_foreground_box_pixels"] >= 1000
        assets = {name: scenes / f"{body}-{name}.scn" for name in TREATMENTS}
        rows[str(body)], local = common["fitted_row"](root / "Viewer", body, groups[body], clips, assets, result["hashes"])
        copies.update(local)
    for name in ("DreadChitin.gdshader", "DreadSilkOpening.gdshader"):
        assert digest(stage / "Viewer/Presentation" / name) == digest(scenes / name)
    return rows, copies, verify_native(root, stage, work, scenes, groups, terrain, common)


def verify_native(root, stage, work, scenes, groups, terrain, common):
    read, digest = common["read"], common["sha"]
    folder = work / f"native-{FAMILY}-enhanced"
    path = folder / f"{FAMILY}-native.json"
    native = read(path)
    runtime = read(folder / f"{FAMILY}-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert digest(file) == runtime[f"{key}_sha256"].lower()
    assert digest(folder / "NativePoisonElementalDreadSpiderLive.gd") == native["test_sha256"]
    assert digest(scenes / TEST) == native["inputs_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["records"].keys() == FORMS.keys() == native["renderers"].keys() and native["checks"] >= 175
    for form, record in native["records"].items():
        name, body, hue, loot = FORMS[form]
        renderer = f"SourceEnhanced{name}Visual.gd"
        assert digest(stage / "Viewer/Presentation" / renderer) == digest(scenes / renderer) == native["renderers"][form]
        assert (record["class"], record["stock_weapon"], record["hue"]) == (name, "Fists", 0)
        assert record["can_move"] and not record["can_swim"] and not record["tamable"]
        assert len(record["step_delta"]) == 2 and max(map(abs, record["step_delta"])) == 1
        assert record["loot"].keys() == loot.keys() and all(record["loot"][key] >= amount for key, amount in loot.items())
        assert record["corpse"] >= 0x40000000 and (record["corpse_body"], record["corpse_hue"]) == (body, hue)
        swing = record["swing"]
        packet = swing["packet"]
        assert (packet["protocol"], packet["body"], packet["serial"]) == ("classic", body, record["serial"])
        assert packet["action"] in (4, 5, 6) and swing["clip"]
        poison = record["native_melee_poison"]
        assert poison["lethal"] and poison["damage"] > 0 and poison["target"] == swing["target"]
        phase, = record["phases"]
        assert phase["body"] == body and phase["asset_sha256"] == terrain[str(body)]["hashes"]["modern"]
        cases = phase["cases"]
        expected = {(flags, kind, variation) for flags in (0, 64) for kind in TYPES[body] for variation in (0, 1, 255)}
        assert len(cases) == len(expected) and {(c["flags"], c["type"], c["variation"]) for c in cases} == expected
        for case in cases:
            mode = "0" if case["flags"] else "1"
            kind, variant = str(case["type"]), case["variation"]
            choices = groups[body][mode].get(kind, groups[body]["0"][kind])
            assert case["enhanced"] == (choices[variant % len(choices)] if variant <= 127 else case["classic"])
    return digest(path)
