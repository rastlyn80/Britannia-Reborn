# SPDX-License-Identifier: GPL-3.0-or-later
"""Seal the Stone Gargoyle and Bake Kitsune Enhanced motions."""

import runpy


MEMBERS = {67: "0x72c3685c549e1406", 246: "0x5a6dbb3df76469e2"}
SPRITES = {
    67: {
        12: ("StoneGargoyleRisingRake", 35, "59513a4bface25dbc0881eb03248ee45246f2673fafe66afb63864d9a586d8a1"),
        23: ("StoneGargoyleUnbrace", 45, "bed3098edee562e4078170a80ee387fc335693ac1266686bfec3a1dc2a20a978"),
        26: ("StoneGargoyleClawCheck", 60, "7134be7217c5665581db46e54ca526a8e80080a4518d97a75da1d066f55734e8"),
        27: ("StoneGargoyleStaggeredFeint", 55, "48b4379fa4e51ca1af4e639662f94b8bf0842f8d4d82e46bbfc3d717fd5120e2"),
        28: ("StoneGargoyleHunchedAlert", 30, "1d403d71e73e67895d1445c59e956fe4cf9cef29d91b8f271b42d79164e0443d"),
    },
    246: {
        4: ("BakeKitsuneLowSnap", 35, "eb7895d12f79d6f0eb2885b24d45f390a1a6ecab87eff96528189b10e74a88ce"),
        15: ("BakeKitsuneSkiddingRecoil", 40, "05d3f5903e7dee4b8f2882e772587298add648397941ea3ce4ef05a61d598ad0"),
        25: ("BakeKitsuneQuietStand", 60, "04f1b4e0eb8120d93909e5a9cd1c97130d5cc40c7f3a61655a872dbe6c7118ef"),
        26: ("BakeKitsuneScentCheck", 75, "5277115d99e39e84f80d61c734d01a5c44b044bbdb6e18b9b31e96744723525f"),
        27: ("BakeKitsuneThreeTailFeint", 55, "52504f2143c1301bf505dbdc9917f6a4b3e3004040ba2ef763dab8c2059ce622"),
        28: ("BakeKitsuneStillAlert", 30, "900b9c1af562c566250fac87905e0d72d0d35d846e084848a08d0299b5e6d6e0"),
    },
}
TYPES = {67: (5, 8, 11, 15), 246: (0, 2, 5, 8, 11, 14, 15)}
TEST = "test-stone-gargoyle-kitsune-enhanced.gd"
FORMS = {
    "stonegargoyle": ("StoneGargoyle", 67, 0x8035, "MeleeAI", "SourceEnhancedStoneGargoyleVisual.gd"),
    "kitsune": ("BakeKitsune", 246, 0, "MageAI", "SourceEnhancedBakeKitsuneVisual.gd"),
}


def source_groups(root, source, common):
    groups = {}
    for body, slots in SPRITES.items():
        types = tuple(kind for kind in TYPES[body] if kind != 0)
        groups.update(common["source_tables"](root, source, {body: slots}, types, member_hashes=MEMBERS))
    inspect = runpy.run_path(str(root / "scripts/uo-human-sequences.py"))["inspect"]
    member, = [row for row in inspect(source / "AnimationSequence.uop", {246})
               if row["uop_name_hash"] == MEMBERS[246]]
    attack = {mode["mode"]: {row["subaction"]: row["groups"] for row in mode["new_protocol_actions"] if row["type"] == 0}
              for mode in member["modes"]}
    assert attack == {0: {-1: [4] * 6, 0: [4] * 3, 1: [4], 2: [4], 9: [4]}, 1: {}}
    groups[246]["0"]["0"] = [SPRITES[246][group][0] for group in attack[0][-1]]
    return groups


def prepare_stone_gargoyle_kitsune(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    stage = staged or root
    folder = root / "work/creatures/native-form-audit/enhanced-source-gaps/stone-gargoyle-bake-kitsune"
    receipt = read(folder / "terrain-receipt.json")
    assert digest(stage / "scripts" / TEST) == digest(folder / TEST) == receipt["test_sha256"]
    terrain, rendered = receipt["bodies"], read(folder / "motion-render-receipt.json")
    measured = read(folder / "dense-geometry-receipt.json")
    assert measured["sample_rate"] == 240 and measured["passed"]
    assert terrain.keys() == rendered.keys() == measured["bodies"].keys() == {str(body) for body in SPRITES}
    groups = source_groups(root, source, common)
    rows, copies = {}, {}
    for body, slots in SPRITES.items():
        clips = [clip for clip, _, _ in slots.values()]
        motion, render = terrain[str(body)], rendered[str(body)]
        expected = (2325, 150, 15) if body == 67 else (2790, 180, 0)
        assert (motion["poses"], motion["falls"], motion["retained_air_falls"]) == expected
        assert (motion["routes"], motion["classic"]) == (24 * len(TYPES[body]), 18 * len(TYPES[body]))
        assert min(motion["gap"], motion["fall_gap"]) >= .0018 and motion["jump"] < .002
        assert render["scene_sha256"] == motion["hashes"]["modern"]
        assert render["poses"] == 10 * len(clips) and set(render["clips"]) == set(clips)
        assert render["minimum_foreground_box_pixels"] >= 5000
        measurements = measured["bodies"][str(body)]
        assert measurements.keys() == motion["hashes"].keys() == {"original", "rounded", "modern"}
        for treatment, measurement in measurements.items():
            assert measurement["scene_sha256"] == motion["hashes"][treatment]
            assert measurement["clips"].keys() == set(clips)
            for clip in measurement["clips"].values():
                assert clip["floor_minimum"] >= .0025 and clip["maximum_tip_step"] <= .10
                assert clip["link_error"] <= .0005 and clip["link_drift"] <= .000015
                assert clip["maximum_paw_clearance"] <= .045
                if body == 67:
                    assert clip["maximum_wing_depth_relative_to_back"] <= .08
            assert sum(clip["samples"] for clip in measurement["clips"].values()) == (1172 if body == 67 else 1483)
        assets = {name: folder / f"{body}-{name}.scn" for name in sorted(motion["hashes"])}
        rows[str(body)], local = common["fitted_row"](root / "Viewer", body, groups[body], clips, assets, motion["hashes"])
        copies.update(local)
    return rows, copies, verify_native(root, stage, folder, groups, terrain, common)


def verify_native(root, stage, folder, groups, terrain, common):
    read, digest = common["read"], common["sha"]
    native_dir = root / "work/creatures/native-stone-gargoyle-kitsune-enhanced"
    path = native_dir / "stone-gargoyle-kitsune-native.json"
    native, runtime = read(path), read(native_dir / "stone-gargoyle-kitsune-native-runtime.json")
    fixture = native_dir / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert digest(file) == runtime[f"{key}_sha256"].lower()
    assert digest(native_dir / "NativeStoneGargoyleKitsuneLive.gd") == native["test_sha256"]
    assert digest(folder / TEST) == native["inputs_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["records"].keys() == FORMS.keys() and native["checks"] >= 275
    for form, record in native["records"].items():
        name, body, hue, ai, renderer = FORMS[form]
        kitsune = body == 246
        assert digest(stage / "Viewer/Presentation" / renderer) == native["renderers"][str(body)]
        assert (record["class"], record["hue"], record["stock_weapon"], record["ai"]) == (name, 0, "Fists", ai)
        assert record["can_move"] and record["tamable"] == kitsune and not record["can_swim"] and not record["can_fly"]
        assert len(record["step_delta"]) == 2 and max(map(abs, record["step_delta"])) == 1
        assert record["corpse"] >= 0x40000000 and (record["corpse_body"], record["corpse_hue"]) == (body, hue)
        loot, combat = record["carved"], record["combat"]
        if kitsune:
            disguise = record["disguise"]
            assert disguise["serial"] == record["serial"] and disguise["revealed_body"] == 246
            assert disguise["human_body"] in (0x190, 0x191) and disguise["robe"] > 0 and disguise["shoes"] > 0
            assert (loot["ribs"], loot["hides"]) == (5, 11)
            assert combat["controlled_trigger"] and combat["expired"]
            assert (combat["immediate_damage"], combat["first_tick_damage"], combat["total_damage"], combat["ticks"]) == (0, 2, 10, 5)
        else:
            assert loot["ingots"] == 12 and not record["disguise"]
            packet = combat["packet"]
            assert (packet["protocol"], packet["body"], packet["serial"]) == ("classic", body, record["serial"])
            assert packet["action"] in (4, 5, 6) and combat["clip"]
        phase, = record["phases"]
        assert phase["body"] == body and phase["asset_sha256"] == terrain[str(body)]["hashes"]["modern"]
        cases = phase["cases"]
        expected = {(flag, kind, variant) for flag in (0, 64) for kind in TYPES[body] for variant in (0, 1, 255)}
        assert len(cases) == len(expected) and {(c["flags"], c["type"], c["variation"]) for c in cases} == expected
        for case in cases:
            mode = "0" if case["flags"] & 64 else "1"
            kind, variant = str(case["type"]), case["variation"]
            choices = groups[body][mode].get(kind, groups[body]["0"][kind])
            assert case["enhanced"] == (choices[variant % len(choices)] if variant <= 127 else case["classic"])
    return digest(path)
