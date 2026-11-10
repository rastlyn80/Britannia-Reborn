# SPDX-License-Identifier: GPL-3.0-or-later
"""Seal the Blood Elemental and Mountain Goat Enhanced motions."""

import runpy


MEMBERS = {159: "0xcd9bfc04583d986a", 88: "0x50bd0db044a46392"}
SPRITES = {
    159: {
        23: ("BloodElementalPoolRise", 50, "f4820c766c105217d5a4db4ab5df54e7f7e44cfad884df902cac9414bf5141bf"),
        28: ("BloodElementalSurgeAlert", 40, "601d1b80b94813f729d7bfba9fa1c7a6125c5e0b059564f37f5685e7e04bd8d7"),
    },
    88: {
        25: ("MountainGoatQuietStand", 55, "d9ae917efbe1bef281556fcb7aefe7036778732c4b754cf260400b6b5c3d84db"),
        26: ("MountainGoatLoweredHornCheck", 60, "681ad34eece02128569673270b102067acceb7298303fb1beeaf73984450e6fd"),
    },
}
TYPES = {159: (8, 15), 88: (0, 2, 5, 8, 11, 14, 15)}
TEST = "test-blood-goat-enhanced.gd"
FORMS = {
    "blood": ("BloodElemental", 159, 0x8035, "MageAI", "SourceEnhancedBloodElementalVisual.gd"),
    "goat": ("MountainGoat", 88, 0x455, "AnimalAI", "SourceEnhancedMountainGoatVisual.gd"),
}


def source_groups(root, source, common):
    tables = {}
    for body, slots in SPRITES.items():
        types = tuple(kind for kind in TYPES[body] if kind != 0)
        tables.update(common["source_tables"](root, source, {body: slots}, types, member_hashes=MEMBERS))
    inspect = runpy.run_path(str(root / "scripts/uo-human-sequences.py"))["inspect"]
    named, = [row for row in inspect(source / "AnimationSequence.uop", {88})
              if row["uop_name_hash"] == MEMBERS[88]]
    attack = {mode["mode"]: [row for row in mode["new_protocol_actions"] if row["type"] == 0]
              for mode in named["modes"]}
    assert not attack[1] and {row["subaction"] for row in attack[0]} == {-1, 0, 1, 2, 9}
    assert len(attack[0]) == 5 and all(set(row["groups"]) == {25} for row in attack[0])
    default, = [row for row in attack[0] if row["subaction"] == -1]
    assert len(default["groups"]) == 6
    tables[88]["0"]["0"] = [SPRITES[88][group][0] for group in default["groups"]]
    return tables


def prepare_blood_goat(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    stage = staged or root
    work = root / "work/creatures"
    folder = work / "native-form-audit/enhanced-source-gaps/blood-elemental-mountain-goat"
    receipt = read(folder / "terrain-receipt.json")
    assert digest(stage / "scripts" / TEST) == digest(folder / TEST) == receipt["test_sha256"]
    terrain, rendered = receipt["bodies"], read(folder / "motion-render-receipt.json")
    assert terrain.keys() == rendered.keys() == {str(body) for body in SPRITES}
    groups = source_groups(root, source, common)
    rows, copies = {}, {}
    for body, slots in SPRITES.items():
        clips = [clip for clip, _, _ in slots.values()]
        motion, render = terrain[str(body)], rendered[str(body)]
        assert (motion["poses"], motion["falls"], motion["routes"], motion["classic"]) == (
            930, 60, 24 * len(TYPES[body]), 18 * len(TYPES[body]))
        assert min(motion["gap"], motion["fall_gap"]) >= .0018 and motion["jump"] < .002
        assert render["scene_sha256"] == motion["hashes"]["modern"]
        assert render["poses"] == 20 and set(render["clips"]) == set(clips)
        assert motion["hashes"].keys() == {"original", "rounded", "modern"}
        assert render["minimum_foreground_box_pixels"] >= (100 if body == 159 else 10000)
        if body == 159:
            rise = motion["visible_motion"]["BloodElementalPoolRise"]
            assert rise["first"] <= .28 and rise["high"] >= 2.2 and motion["growth_resets"] == 30
        else:
            dip = motion["visible_motion"]["MountainGoatLoweredHornCheck"]
            assert dip["first"] - dip["low"] >= .28 and motion["growth_resets"] == 0
        assets = {name: folder / f"{body}-{name}.scn" for name in sorted(motion["hashes"])}
        rows[str(body)], local = common["fitted_row"](root / "Viewer", body, groups[body], clips, assets, motion["hashes"])
        copies.update(local)
    return rows, copies, verify_native(root, stage, work, folder, groups, terrain, common)


def verify_native(root, stage, work, folder, groups, terrain, common):
    read, digest = common["read"], common["sha"]
    native_dir = work / "native-blood-goat-enhanced"
    path = native_dir / "blood-goat-native.json"
    native, runtime = read(path), read(native_dir / "blood-goat-native-runtime.json")
    fixture = native_dir / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert digest(file) == runtime[f"{key}_sha256"].lower()
    assert digest(native_dir / "NativeBloodGoatLive.gd") == native["test_sha256"]
    assert digest(folder / TEST) == native["inputs_sha256"]
    presentation = stage / "Viewer/Presentation"
    assert digest(presentation / "blood-elemental-shell.gd") == native["shell_recipe_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["records"].keys() == FORMS.keys() and native["checks"] >= 200
    for form, record in native["records"].items():
        name, body, hue, ai, renderer = FORMS[form]
        assert digest(presentation / renderer) == native["renderers"][str(body)]
        assert (record["class"], record["hue"], record["stock_weapon"], record["ai"]) == (name, 0, "Fists", ai)
        assert record["can_move"] and not record["can_swim"] and not record["can_fly"]
        assert record["tamable"] == (form == "goat")
        assert len(record["step_delta"]) == 2 and max(map(abs, record["step_delta"])) == 1
        assert record["corpse"] >= 0x40000000 and (record["corpse_body"], record["corpse_hue"]) == (body, hue)
        loot, combat = record["carved"], record["combat"]
        if form == "blood":
            assert loot["gold"] > 0 and combat["damage"] > 0 and 1 <= combat["cast_attempts"] <= 4
        else:
            assert (loot["ribs"], loot["hides"]) == (2, 14)
            packet = combat["packet"]
            assert (packet["protocol"], packet["body"], packet["serial"]) == ("classic", body, record["serial"])
            assert packet["action"] in (5, 6) and combat["clip"]
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
