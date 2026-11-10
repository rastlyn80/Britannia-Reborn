# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the two fitted rigs and the three native creature constructors."""

MEMBERS = {154: "0xb768154af19d705f", 40: "0xfde276ab1cfa20a3"}
SPRITES = {
    154: {
        4: ("MummyOverheadRecoil", 45, "628b32f9f3418fdeadcc2cbb632eb24d86958ab067e9a0f0eb3e4fc3548fd22b"),
        23: ("MummyCrouchedRise", 50, "e0b5740ed41ec89419cc783a8f19c848eafa83abcbaef6945f34ba02aa1f504e"),
        28: ("MummyRaisedArmsAlert", 45, "a72ad8a2b8d27b14e54e2fc09057acbda6a0076efd86e409b3eea48a4fa809b3"),
    },
    40: {
        23: ("BalronWingCocoonRise", 60, "e6eb745d0aa1947a831e8dfa801817cd46376504c9d65672370d335aa117285d"),
        26: ("BalronWingWatch", 55, "1021fb1f2cd3eabe48606b9c5876c0c3f3977f9b7485fc395a1c8992e64b3aa8"),
        27: ("BalronWingbeatRecoil", 65, "d2a20b4ade8a522993e648b38e7bb9f1db1e0305f0f523f78b0fd148778a69d4"),
        28: ("BalronWideThreat", 65, "8333935fe37d5318bc504c1bb012e1216223c4587e54eec6dd0c4da4c3cdb6d9"),
    },
}
TYPES = {154: (8, 11, 15), 40: (5, 8, 15)}
TREATMENTS = ("original", "rounded", "modern")
FORMS = {
    "mummy": ("Mummy", 154, 0, 0x8035, {"garlic": 5, "bandages": 10, "sword": False}),
    "bandage": ("PestilentBandage", 154, 0x515, 0x455, {"garlic": 0, "bandages": 5, "sword": False}),
    "balron": ("Balron", 40, 0, 0x455, {"garlic": 0, "bandages": 0, "sword": True}),
}
TEST = "test-mummy-balron-enhanced.gd"


def prepare_mummy_balron(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    stage = staged or root
    work = root / "work/creatures"
    scenes = work / "native-form-audit/enhanced-source-gaps/mummy-daemon-elder"
    receipt = read(scenes / "terrain-receipt.json")
    assert digest(scenes / TEST) == receipt["test_sha256"] == digest(stage / "scripts" / TEST)
    terrain = receipt["bodies"]
    rendered = read(scenes / "motion-render-receipt.json")
    assert terrain.keys() == rendered.keys() == {str(body) for body in SPRITES}
    groups, rows, copies = {}, {}, {}
    for body, source_groups in SPRITES.items():
        groups.update(common["source_tables"](root, source, {body: source_groups}, TYPES[body],
                                             flight_fallback=body == 40, member_hashes=MEMBERS))
        clips = [clip for clip, _, _ in source_groups.values()]
        motion, render = terrain[str(body)], rendered[str(body)]
        assert (motion["poses"], motion["falls"]) == (465 * len(clips), 30 * len(clips))
        assert (motion["routes"], motion["classic"]) == (72, 54)
        assert (motion["air_poses"], motion["air_falls"], motion["air_choices"]) == ((1560, 120, 60) if body == 40 else (0, 0, 0))
        assert motion["gap"] >= .0028 and motion["jump"] < .002
        assert motion["hashes"].keys() == set(TREATMENTS)
        assert render["scene_sha256"] == motion["hashes"]["modern"]
        assert render["poses"] == 10 * len(clips) and set(render["clips"]) == set(clips)
        assert render["minimum_foreground_box_pixels"] >= 2000
        assets = {name: scenes / f"{body}-{name}.scn" for name in TREATMENTS}
        rows[str(body)], local = common["fitted_row"](root / "Viewer", body, groups[body], clips, assets, motion["hashes"])
        copies.update(local)
    rows["40"]["flight_falls_back_to_combat"] = True
    assert terrain["40"]["air_gap"] >= .6498
    verify_wings(read(scenes / "wing-receipt.json"), terrain["40"]["hashes"])
    return rows, copies, verify_native(root, stage, work, scenes, groups, terrain, common)


def verify_wings(receipt, hashes):
    assert receipt.keys() == hashes.keys()
    expected = {"BalronWingCocoonRise": 635, "BalronWingWatch": 558, "BalronWingbeatRecoil": 582, "BalronWideThreat": 544}
    for treatment, proof in receipt.items():
        assert proof["scene_sha256"] == hashes[treatment] and proof["motions"].keys() == expected.keys()
        assert proof["open_width"] >= 2.5 * proof["folded_width"]
        for name, clip in proof["motions"].items():
            assert clip["samples"] == expected[name] and clip["link_error"] < .00005 and clip["max_tip_step"] < .06


def verify_native(root, stage, work, scenes, groups, terrain, common):
    read, digest = common["read"], common["sha"]
    folder = work / "native-mummy-balron-enhanced"
    path = folder / "mummy-balron-native.json"
    native = read(path)
    runtime = read(folder / "mummy-balron-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert digest(file) == runtime[f"{key}_sha256"].lower()
    assert digest(folder / "NativeMummyBalronLive.gd") == native["test_sha256"]
    assert digest(scenes / TEST) == native["inputs_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["records"].keys() == FORMS.keys() and native["checks"] >= 250
    assert native["renderers"].keys() == {"mummy", "balron"}
    for form, record in native["records"].items():
        name, body, hue, corpse_hue, loot = FORMS[form]
        renderer = "SourceEnhancedMummyVisual.gd" if body == 154 else "SourceEnhancedBalronVisual.gd"
        assert digest(stage / "Viewer/Presentation" / renderer) == digest(scenes / renderer) == native["renderers"]["mummy" if body == 154 else "balron"]
        assert (record["class"], record["stock_weapon"], record["hue"]) == (name, "Fists", hue)
        assert record["can_move"] and not any(record[key] for key in ("can_swim", "can_fly", "tamable"))
        assert record["can_heal"] == (form == "bandage") and record["can_rummage"] == (form == "balron")
        assert len(record["step_delta"]) == 2 and max(map(abs, record["step_delta"])) == 1
        assert record["loot"] == loot and record["corpse"] >= 0x40000000
        assert (record["corpse_body"], record["corpse_hue"]) == (body, corpse_hue)
        swing = record["swing"]
        packet = swing["packet"]
        assert (packet["protocol"], packet["body"], packet["serial"]) == ("classic", body, record["serial"])
        assert packet["action"] in (4, 5, 6) and swing["clip"]
        poison = record["native_melee_poison"]
        if form == "bandage":
            assert poison["lethal"] and poison["damage"] > 0 and poison["target"] == swing["target"]
        else:
            assert not poison
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
