# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the retained Yomotsu Warrior and red Dragon fittings."""

MEMBERS = {245: "0x191f7504e9f95708", 59: "0x8b37cf10bcd7a297"}
SPRITES = {
    245: {
        12: ("YomotsuOverheadWard", 50, "62604bf06258ab0152478267bacc0220592f41e460c1c6561c9ffdcf00e85f4a"),
        15: ("YomotsuClawRecoil", 25, "9750116ebbcf443c84e144e579d48d5bda5ecd01825bb7ff9a1368dc4e03e2da"),
        23: ("YomotsuCrouchedRise", 45, "74ac2656f5df05e513f96303a065cb58f2e4447481864af3d29b31d79e5b03ed"),
        26: ("YomotsuKneelingWatch", 55, "f79264d0949e4b5b0bb1e274a3e33c23890463a5596ced849374d13519cebeef"),
        27: ("YomotsuWideClawGuard", 50, "2c08c2fe9e98b17a2c14f24635bd1b252afe893bd2f59d945bc7cfad996fc452"),
        28: ("YomotsuRaisedClawAlert", 35, "76b2cd04b2f12679fa6a095bd4ed94001b7e4e13eea843104f731ef38d324201"),
    },
    59: {
        23: ("DragonRedMantleOpen", 60, "5e9c2377ad8a9334fb37c0c3215679c27267220f63eeb960aeccc72b5768275c"),
        26: ("DragonRedRaisedWingWatch", 55, "42c2b31d6e1cc3d7d8cdae7531fe8509e74d3233577cc97664aab5894935cd48"),
        27: ("DragonRedBankedWingRecoil", 50, "a303f812dd487493317496226067361a0566bbf11103df5009511fe4763f95ec"),
        28: ("DragonRedWideWingAlert", 30, "3644586ab697ca6ea7b4bb1ef4b4efba917312893fceec30e857a9264ed66b33"),
    },
}
TYPES = {245: (2, 5, 8, 11, 15), 59: (5, 8, 15)}
TREATMENTS = ("original", "rounded", "modern")
TEST = "test-yomotsu-warrior-dragon-enhanced.gd"
FORMS = {"warrior": ("YomotsuWarrior", 245, 0x455, "none", "SourceEnhancedYomotsuWarriorVisual.gd"),
         "dragon": ("Dragon", 59, 0x8035, "Red", "SourceEnhancedDrakeVisual.gd")}


def prepare_yomotsu_warrior_dragon(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    stage = staged or root
    work = root / "work/creatures"
    scenes = work / "native-form-audit/enhanced-source-gaps/yomotsu-warrior-dragon"
    receipt = read(scenes / "terrain-receipt.json")
    assert digest(scenes / TEST) == receipt["test_sha256"] == digest(stage / "scripts" / TEST)
    terrain = receipt["bodies"]
    rendered = read(scenes / "motion-render-receipt.json")
    assert terrain.keys() == rendered.keys() == {str(body) for body in SPRITES}
    groups, rows, copies = {}, {}, {}
    for body, source_groups in SPRITES.items():
        groups.update(common["source_tables"](root, source, {body: source_groups}, TYPES[body],
                                              flight_fallback=body == 59, member_hashes=MEMBERS))
        clips = [clip for clip, _, _ in source_groups.values()]
        motion, render = terrain[str(body)], rendered[str(body)]
        assert (motion["poses"], motion["falls"]) == (465 * len(clips), 30 * len(clips))
        assert (motion["routes"], motion["classic"]) == (24 * len(TYPES[body]), 18 * len(TYPES[body]))
        assert motion["gap"] >= .0018 and motion["jump"] < .002 and motion["hashes"].keys() == set(TREATMENTS)
        assert (motion["air_poses"], motion["air_falls"], motion["air_choices"]) == ((1515, 120, 60) if body == 59 else (0, 0, 0))
        assert render["scene_sha256"] == motion["hashes"]["modern"]
        assert render["poses"] == 10 * len(clips) and set(render["clips"]) == set(clips)
        assert render["minimum_foreground_box_pixels"] >= 4000
        assets = {name: scenes / f"{body}-{name}.scn" for name in TREATMENTS}
        rows[str(body)], local = common["fitted_row"](root / "Viewer", body, groups[body], clips, assets, motion["hashes"])
        copies.update(local)
    assert terrain["59"]["air_gap"] >= .6498
    rows["59"]["flight_falls_back_to_combat"] = True
    verify_geometry(read(scenes / "geometry-receipt.json"), rows)
    return rows, copies, verify_native(root, stage, work, scenes, groups, terrain, common)


def verify_geometry(receipt, rows):
    assert receipt.keys() == set(TREATMENTS)
    expected = {"DragonRedMantleOpen": 568, "DragonRedRaisedWingWatch": 553,
                "DragonRedBankedWingRecoil": 486, "DragonRedWideWingAlert": 294}
    for treatment, proof in receipt.items():
        warrior, dragon = proof["warrior"], proof["dragon"]
        assert warrior["scene_sha256"] == rows["245"]["assets"][treatment]["sha256"]
        assert warrior["source_sha256"] == rows["245"]["base_sha256"][treatment]
        assert (warrior["blade_triangles"], warrior["body_triangles"]) == ((38, 412) if treatment == "original" else (608, 6592))
        assert dragon["scene_sha256"] == rows["59"]["assets"][treatment]["sha256"]
        assert dragon["clips"].keys() == expected.keys()
        for name, clip in dragon["clips"].items():
            assert clip["poses"] == expected[name] and clip["max_drift"] < .00005 and clip["tip_step"] < .07
        opening = dragon["clips"]["DragonRedMantleOpen"]
        assert opening["max_width"] >= 1.6 * opening["min_width"]


def verify_native(root, stage, work, scenes, groups, terrain, common):
    read, digest = common["read"], common["sha"]
    folder = work / "native-yomotsu-warrior-dragon-enhanced"
    path = folder / "yomotsu-warrior-dragon-native.json"
    native = read(path)
    runtime = read(folder / "yomotsu-warrior-dragon-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert digest(file) == runtime[f"{key}_sha256"].lower()
    assert digest(folder / "NativeYomotsuWarriorDragonLive.gd") == native["test_sha256"]
    assert digest(scenes / TEST) == native["inputs_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["records"].keys() == FORMS.keys() and native["checks"] >= 275
    for form, record in native["records"].items():
        name, body, hue, scales, renderer = FORMS[form]
        dragon = body == 59
        renderer_root = root if dragon else stage
        assert digest(renderer_root / "Viewer/Presentation" / renderer) == native["renderers"][str(body)]
        assert (record["class"], record["hue"], record["stock_weapon"], record["scales"]) == (name, 0, "Fists", scales)
        assert record["can_move"] and not record["can_swim"] and record["can_fly"] == record["tamable"] == dragon
        assert len(record["step_delta"]) == 2 and max(map(abs, record["step_delta"])) == 1
        assert record["corpse"] >= 0x40000000 and (record["corpse_body"], record["corpse_hue"]) == (body, hue)
        loot, breath = record["carved"], record["breath"]
        if dragon:
            assert loot["scales"] >= 7 and loot["hides"] >= 20
            assert breath["damage"] > 0 and breath["target"] > 0 and len(breath["launch_ms"]) == 2
        else:
            assert loot["gourd"] and loot["axe"] and not breath
        swing = record["swing"]
        packet = swing["packet"]
        assert (packet["protocol"], packet["body"], packet["serial"]) == ("classic", body, record["serial"])
        assert packet["action"] in (4, 5, 6) and swing["clip"]
        phase, = record["phases"]
        assert phase["body"] == body and phase["asset_sha256"] == terrain[str(body)]["hashes"]["modern"]
        cases = phase["cases"]
        flags = (0, 4, 64, 68) if dragon else (0, 64)
        expected = {(flag, kind, variation) for flag in flags for kind in TYPES[body] for variation in (0, 1, 255)}
        assert len(cases) == len(expected) and {(c["flags"], c["type"], c["variation"]) for c in cases} == expected
        for case in cases:
            mode = "0" if case["flags"] & 68 else "1"
            kind, variation = str(case["type"]), case["variation"]
            choices = groups[body][mode].get(kind, groups[body]["0"][kind])
            assert case["enhanced"] == (choices[variation % len(choices)] if variation <= 127 else case["classic"])
    return digest(path)
