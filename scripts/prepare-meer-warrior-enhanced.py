# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the Meer Warrior's official references and local fitted presentation."""

import runpy


BODY = 771
MEMBER = "0x8814417571f6f36f"
SPRITES = {
    4: ("MeerWarriorSweepingJab", 20, "986352272ac3d702c8cffe017e5e5594d339f837ba8882acadab71822bbbe60b"),
    5: ("MeerWarriorRisingStrike", 20, "4a01d3708a39be615e72314eba2902a6e44788919749662aee26122116bd6bb7"),
    6: ("MeerWarriorPivotingBackhand", 20, "a651655fd3a21571b4fb9d98ea0d3834a961619e343cac8e19110683f49ada89"),
    15: ("MeerWarriorBracedGuard", 15, "d64f1c76c7fe83c5b9a8d18260513dda213941be11dba816841ae944cc4a5037"),
    25: ("MeerWarriorQuietStand", 25, "49e444c23105821517b1085d804a469913e2f7fe7c755361c1dc93ba2ee562a8"),
    26: ("MeerWarriorHipCheck", 25, "7d4530705b13244ef8ebbcad0e10a01feb7d8df3ed33ab2e27443a0a05f3fad8"),
}
TYPES = (2, 5, 8, 11, 14, 15)
ATTACK_SUBACTIONS = (0, 1, 2, 9, 37, 0xFFFF, 0x101, 0x1FF)
ATTACK_DISPATCHER = "Viewer/Presentation/EnhancedCreatureAttackActions.gd"
RENDERER = "SourceEnhancedMeerWarriorVisual.gd"
FOLDER = "work/creatures/native-form-audit/enhanced-source-gaps/meer-warrior-enhanced"


def prepare_meer_warrior(root, source, common, staged=None):
    read, sha = common["read"], common["sha"]
    stage = staged or root
    folder = root / FOLDER
    routed = {group: entry for group, entry in SPRITES.items() if group not in (5, 6)}
    routes = common["source_tables"](root, source, {BODY: routed}, TYPES, member_hashes={BODY: MEMBER})[BODY]
    decode = runpy.run_path(str(root / "scripts/uo-enhanced-frames.py"))["read_amou"]
    for group in (5, 6):
        _, count, digest = SPRITES[group]
        payload = source / f"ec-frame-{BODY}-{group}.bin"
        assert sha(payload) == digest
        identity, frames = decode(payload.read_bytes())
        assert identity == BODY and len(frames) == count and all(frame.group == group for frame in frames)
    inspect = runpy.run_path(str(root / "scripts/uo-human-sequences.py"))["inspect"]
    named, = (row for row in inspect(source / "AnimationSequence.uop", {BODY}) if row["uop_name_hash"] == MEMBER)
    combat, peace = named["modes"]
    assert combat["mode"] == 0 and peace["mode"] == 1 and peace["fallback_mode"] == 0
    assert peace["movement"][0] == {"action": 0, "one_handed_group": 25, "two_handed_group": 25}
    assert not any(row["type"] == 0 for row in peace["new_protocol_actions"])
    subactions = {row["subaction"]: row["groups"] for row in combat["new_protocol_actions"] if row["type"] == 0}
    assert subactions == {-1: [4, 5, 6, 4, 4, 4], 0: [4, 5, 6], 1: [4], 2: [4], 9: [4]}
    attacks = {str(key & 255): [SPRITES[group][0] for group in values] for key, values in subactions.items()}
    clips = [row[0] for row in SPRITES.values()]
    runtime = read(folder / "runtime-receipt.json")
    assert tuple(runtime[key] for key in ("poses", "falls", "routes", "classic", "gaits")) == (2790, 180, 144, 108, 18)
    assert (runtime["attack_routes"], runtime["attack_fallbacks"]) == (336, 192)
    assert runtime["gap"] >= .0029 and runtime["fall_gap"] >= .0019 and runtime["handoff"] < .002
    render = read(folder / "motion-render-receipt.json")[str(BODY)]
    assert render["clips"] == clips and render["poses"] == 60 and render["minimum_foreground_box_pixels"] > 7000
    assert render["scene_sha256"] == runtime["hashes"]["modern"]
    dense = read(folder / "dense-clearance-receipt.json")
    assert dense["sample_rate"] == 240 and dense["treatments"].keys() == runtime["hashes"].keys()
    for treatment, measured in dense["treatments"].items():
        assert measured["scene_sha256"] == runtime["hashes"][treatment] and measured["clips"].keys() == set(clips)
        assert sum(clip["samples"] for clip in measured["clips"].values()) == 987
        assert all(clip["crossings"] == 0 and clip["maximum_supported_foot_gap"] < .004
                   for clip in measured["clips"].values())
    assets = {name: folder / f"{BODY}-{name}.scn" for name in runtime["hashes"]}
    row, copies = common["fitted_row"](root / "Viewer", BODY, routes, clips, assets, runtime["hashes"])
    row["attack_subactions"] = attacks
    return {str(BODY): row}, copies, verify_native(root, stage, routes, attacks, runtime["hashes"]["modern"], read, sha)


def verify_native(root, stage, routes, attacks, asset, read, sha):
    folder = root / "work/creatures/native-meer-warrior-enhanced"
    path = folder / "meer-warrior-native.json"
    native, engine = read(path), read(folder / "meer-warrior-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert sha(file) == engine[f"{key}_sha256"].lower()
    assert sha(folder / "NativeMeerWarriorLive.gd") == native["test_sha256"]
    assert sha(root / FOLDER / "test-meer-warrior-enhanced.gd") == native["inputs_sha256"]
    assert sha(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert sha(stage / ATTACK_DISPATCHER) == native["attack_dispatcher_sha256"]
    assert native["renderers"] == {str(BODY): sha(stage / "Viewer/Presentation" / RENDERER)}
    assert native["checks"] >= 380 and native["records"].keys() == {"meer-warrior"}
    record = native["records"]["meer-warrior"]
    assert (record["class"], record["corpse_body"], record["hue"], record["corpse_hue"]) == ("MeerWarrior", BODY, 0, 0x8035)
    assert record["ai"] == "MeleeAI" and record["stock_weapon"] == "Fists" and record["can_move"]
    assert not record["can_swim"] and max(map(abs, record["step_delta"])) == 1
    assert record["corpse"] >= 0x40000000 and record["initial_innocent"] and record["can_rummage"]
    combat = record["combat"]
    assert combat["damage"] > 0 and combat["packet"]["protocol"] == "classic" and combat["packet"]["body"] == BODY
    near, far = (record["retaliation"][str(distance)] for distance in (6, 8))
    assert near["damage"] == 0 and near["effects"] == [] and near["hit_on_meer"] == 4
    assert far["damage"] > 0 and far["initial_damage"] == 0 and far["hit_on_meer"] == 4
    effect, = far["effects"]
    assert (effect["kind"], effect["graphic"], effect["source"], effect["target"]) == (
        "moving", 0xF51, record["serial"], far["target"]
    )
    assert record["carved"]["gold"] > 0
    phase, = record["phases"]
    assert phase["asset_sha256"] == asset
    expected = {(flags, kind, 0, variant) for flags in (0, 64) for kind in TYPES for variant in (0, 1, 2, 255)}
    expected |= {(flags, 0, subaction, variant) for flags in (0, 64) for subaction in ATTACK_SUBACTIONS
                 for variant in (0, 1, 2, 255)}
    cases = phase["cases"]
    assert len(cases) == len(expected)
    assert {(row["flags"], row["type"], row["subaction"], row["variation"]) for row in cases} == expected
    for case in cases:
        mode, kind, variant = ("0" if case["flags"] else "1"), str(case["type"]), case["variation"]
        if kind == "0":
            choices = attacks.get(str(case["subaction"] & 0xFF), attacks["255"])
        else:
            choices = routes[mode].get(kind, routes["0"][kind])
        assert case["enhanced"] == (choices[variant % len(choices)] if variant <= 127 else case["classic"])
    return sha(path)
