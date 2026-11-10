# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the fitted Giant Toad and Juka Warrior against the pinned client and server."""

MEMBERS = {80: "0xb267d74c5ff19790", 764: "0x490535c4c3b8e8e1"}
SPRITES = {
    80: {
        25: ("GiantToadQuietBreath", 50, "b63817e6f3eed61acf2e3e59e7d22dda76dece143516b882be2a422ab09ec41a"),
        26: ("GiantToadTongueSnap", 45, "a8218e797c3bb11a7eb1cf3873142028f042ae16777f6455e721106d9fbd21da"),
    },
    764: {
        23: ("JukaWarriorCrouchedRise", 45, "e43041c55aab9da34757e08c8482ec7bb99a9cf25ae834174bfd930a438dd4ec"),
        28: ("JukaWarriorGuardKick", 30, "e46175ce03ecf599e9db284b868aa83ef9faf3a98302d041c1fcc6cc3273337f"),
    },
}
TYPES = {80: (2, 5, 8, 11, 14, 15), 764: (8, 15)}
TREATMENTS = ("original", "rounded", "modern")
FORMS = {
    "toad": ("GiantToad", 80, 0x8035, True, "SourceEnhancedGiantToadVisual.gd"),
    "juka": ("JukaWarrior", 764, 0x455, False, "SourceEnhancedJukaWarriorVisual.gd"),
}
TEST = "test-giant-toad-juka-warrior-enhanced.gd"


def prepare_giant_toad_juka_warrior(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    stage = staged or root
    work = root / "work/creatures"
    scenes = work / "native-form-audit/enhanced-source-gaps/giant-toad-juka-warrior"
    receipt = read(scenes / "terrain-receipt.json")
    assert digest(scenes / TEST) == receipt["test_sha256"] == digest(stage / "scripts" / TEST)
    terrain = receipt["bodies"]
    rendered = read(scenes / "motion-render-receipt.json")
    assert terrain.keys() == rendered.keys() == {str(body) for body in SPRITES}
    groups, rows, copies = {}, {}, {}
    for body, source_groups in SPRITES.items():
        groups.update(common["source_tables"](root, source, {body: source_groups}, TYPES[body], member_hashes=MEMBERS))
        clips = [clip for clip, _, _ in source_groups.values()]
        motion, render = terrain[str(body)], rendered[str(body)]
        assert (motion["poses"], motion["falls"]) == (930, 60)
        assert (motion["routes"], motion["classic"]) == (24 * len(TYPES[body]), 18 * len(TYPES[body]))
        assert motion["gap"] >= .0019 and motion["jump"] < .002
        assert motion["shape"].keys() == set(clips) and motion["hashes"].keys() == set(TREATMENTS)
        assert render["scene_sha256"] == motion["hashes"]["modern"]
        assert render["poses"] == 20 and set(render["clips"]) == set(clips)
        assert render["minimum_foreground_box_pixels"] >= 5000
        assets = {name: scenes / f"{body}-{name}.scn" for name in TREATMENTS}
        rows[str(body)], local = common["fitted_row"](root / "Viewer", body, groups[body], clips, assets, motion["hashes"])
        copies.update(local)
    toad, juka = terrain["80"]["shape"], terrain["764"]["shape"]
    assert toad["GiantToadTongueSnap"] >= .85 and .008 <= toad["GiantToadQuietBreath"] <= .02
    assert juka["JukaWarriorCrouchedRise"] >= .65 and juka["JukaWarriorGuardKick"] >= .60
    return rows, copies, verify_native(root, stage, work, scenes, groups, terrain, common)


def verify_native(root, stage, work, scenes, groups, terrain, common):
    read, digest = common["read"], common["sha"]
    folder = work / "native-giant-toad-juka-warrior-enhanced"
    path = folder / "giant-toad-juka-warrior-native.json"
    native = read(path)
    runtime = read(folder / "giant-toad-juka-warrior-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert digest(file) == runtime[f"{key}_sha256"].lower()
    assert digest(folder / "NativeGiantToadJukaWarriorLive.gd") == native["test_sha256"]
    assert digest(scenes / TEST) == native["inputs_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["records"].keys() == native["renderers"].keys() == FORMS.keys() and native["checks"] >= 200
    for form, record in native["records"].items():
        name, body, corpse_hue, toad, renderer = FORMS[form]
        assert digest(stage / "Viewer/Presentation" / renderer) == digest(scenes / renderer) == native["renderers"][form]
        assert (record["class"], record["stock_weapon"], record["hue"]) == (name, "Fists", 0)
        assert record["can_move"] and not any(record[key] for key in ("can_swim", "can_fly"))
        assert record["tamable"] == toad and record["can_rummage"] == (not toad)
        assert len(record["step_delta"]) == 2 and max(map(abs, record["step_delta"])) == 1
        loot = record["loot"]
        assert (loot["spined_hides"] >= 12 and loot["ribs"] == 0) if toad else (loot["ribs"] == 1 and loot["spined_hides"] == 0)
        assert record["corpse"] >= 0x40000000 and (record["corpse_body"], record["corpse_hue"]) == (body, corpse_hue)
        swing = record["swing"]
        packet = swing["packet"]
        assert (packet["protocol"], packet["body"], packet["serial"]) == ("classic", body, record["serial"])
        assert packet["action"] in (4, 5, 6) and swing["clip"]
        stun = record["native_melee_stun"]
        assert not stun if toad else (stun["frozen"] and stun["damage"] > 0 and stun["target"] == swing["target"])
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
