# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify Black Solen Warrior source frames, fitted scenes and native variants."""

import runpy

BODY = 806
MEMBER = "0x8efa33eae6af619f"
SPRITES = {
    11: ('BlackSolenWarriorLowSweep', 35, '9a68a07845b74db9993284cec1b567dd45d72100a18d2087895df338a7562031'),
    12: ('BlackSolenWarriorRaisedClaws', 50, '625e406cf52b0caa7ca43394cfabcbb132bfc7ef39b902d4c1a43acdf9c8966b'),
    15: ('BlackSolenWarriorTuck', 35, '9fa827666ea37cafaba06629f471d801096803e80bdec0972c5456ac1548f2c2'),
    23: ('BlackSolenWarriorUnfold', 50, 'fe47055bb7019c5375b7bc93bc6fae15e45b1d244722334898eb627ca50f98ec'),
    25: ('BlackSolenWarriorQuietIdle', 60, 'd6a74695b3a820e37f6d6d6cf95108523851462f8fa80ce913d0a60fc96bcc98'),
    26: ('BlackSolenWarriorAntennaCheck', 55, '6f75211b84d8085d5b5757df66e5feb8c214b7238efbe93cfe3022d433f1eade'),
    27: ('BlackSolenWarriorHighFeint', 50, 'd150471e2b8606af6cd63037875dcf51aeb3a01ba5950206979cffd0e569aed3'),
    28: ('BlackSolenWarriorLowerGuard', 50, '09f0995318e8e3d8d5f1c92b13ffff0b770ad4bc22b94d041d6e8f5f8791adb8'),
}
TYPES = (2, 5, 8, 11, 14, 15)
RENDERER = "SourceEnhancedBlackSolenWarriorVisual.gd"
FOLDER = "work/creatures/native-form-audit/enhanced-source-gaps/solen-warriors"
FORMS = {
    "black": ("BlackSolenWarrior", 806, 0x453, 0x8035, 4),
    "black-infiltrator": ("BlackSolenInfiltratorWarrior", 806, 0x453, 0x455, 0),
    "red": ("RedSolenWarrior", 782, 0, 0x8035, 4),
    "red-infiltrator": ("RedSolenInfiltratorWarrior", 782, 0, 0x455, 0),
}


def prepare_black_solen_warrior(root, source, common, staged=None):
    read, sha = common["read"], common["sha"]
    stage = staged or root
    folder = root / FOLDER
    packet_groups = {BODY: {group: row for group, row in SPRITES.items() if group != 25}}
    routes = common["source_tables"](root, source, packet_groups, TYPES, member_hashes={BODY: MEMBER})[BODY]
    idle_clip, idle_frames, idle_sha = SPRITES[25]
    idle = source / f"ec-frame-{BODY}-25.bin"
    assert sha(idle) == idle_sha
    decoder = runpy.run_path(str(root / "scripts/uo-enhanced-frames.py"))["read_amou"]
    identity, frames = decoder(idle.read_bytes())
    assert identity == BODY and len(frames) == idle_frames and all(frame.group == 25 for frame in frames)
    inspect = runpy.run_path(str(root / "scripts/uo-human-sequences.py"))["inspect"]
    named, = (row for row in inspect(source / "AnimationSequence.uop", {BODY}) if row["uop_name_hash"] == MEMBER)
    assert named["modes"][1]["movement"][0] == {"action": 0, "one_handed_group": 25, "two_handed_group": 25}
    assert idle_clip == "BlackSolenWarriorQuietIdle"
    clips = [row[0] for row in SPRITES.values()]
    runtime = read(folder / "runtime-receipt.json")
    assert tuple(runtime[key] for key in ("poses", "falls", "routes", "classic", "gaits")) == (3720, 240, 144, 108, 18)
    assert runtime["gap"] >= .0029 and runtime["fall_gap"] >= .0019 and runtime["handoff"] < .002
    render = read(folder / "motion-render-receipt.json")[str(BODY)]
    assert render["clips"] == clips and render["poses"] == 80 and render["minimum_foreground_box_pixels"] > 14000
    assert render["scene_sha256"] == runtime["hashes"]["modern"]
    dense = read(folder / "dense-clearance-receipt.json")
    assert dense["sample_rate"] == 240 and dense["treatments"].keys() == runtime["hashes"].keys()
    for treatment, measured in dense["treatments"].items():
        assert measured["scene_sha256"] == runtime["hashes"][treatment] and measured["clips"].keys() == set(clips)
        assert sum(clip["samples"] for clip in measured["clips"].values()) == 1847
        assert all(clip["crossings"] == 0 and clip["maximum_supported_foot_gap"] < .004
                   for clip in measured["clips"].values())
    assets = {name: folder / f"{BODY}-{name}.scn" for name in runtime["hashes"]}
    row, copies = common["fitted_row"](root / "Viewer", BODY, routes, clips, assets, runtime["hashes"])
    return {str(BODY): row}, copies, verify_native(root, stage, routes, runtime["hashes"]["modern"], read, sha)


def verify_native(root, stage, routes, asset, read, sha):
    folder = root / "work/creatures/native-solen-warriors-enhanced"
    path = folder / "solen-warriors-native.json"
    native, engine = read(path), read(folder / "solen-warriors-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert sha(file) == engine[f"{key}_sha256"].lower()
    assert sha(folder / "NativeSolenWarriorsLive.gd") == native["test_sha256"]
    assert sha(root / FOLDER / "test-black-solen-warrior-enhanced.gd") == native["inputs_sha256"]
    assert sha(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["renderers"] == {
        "806": sha(stage / "Viewer/Presentation" / RENDERER),
        "782": sha(root / "Viewer/Presentation/SolenWarriorActionsVisual.gd"),
    }
    assert native["checks"] >= 400 and native["records"].keys() == FORMS.keys()
    expected = {(flags, kind, variant) for flags in (0, 64) for kind in TYPES for variant in (0, 1, 2, 255)}
    for form, (name, body, initial, dye, pools) in FORMS.items():
        record = native["records"][form]
        assert (record["class"], record["corpse_body"], record["hue"], record["corpse_hue"]) == (name, body, initial, dye)
        assert record["ai"] == "MeleeAI" and record["stock_weapon"] == "Fists" and record["can_move"]
        assert not record["can_fly"] and not record["can_swim"] and not record["tamable"]
        assert record["corpse"] >= 0x40000000 and max(map(abs, record["step_delta"])) == 1
        assert record["combat"]["damage"] > 0 and record["combat"]["packet"]["action"] in (4, 5, 6)
        loot = record["carved"]
        assert loot["fungus"] in (3, 13) and loot["gold"] > 0 and loot["pools"] == pools
        if body == BODY:
            phase, = record["phases"]
            assert phase["asset_sha256"] == asset
            cases = phase["cases"]
            assert len(cases) == len(expected)
            assert {(row["flags"], row["type"], row["variation"]) for row in cases} == expected
            for case in cases:
                mode, kind, variant = ("0" if case["flags"] else "1"), str(case["type"]), case["variation"]
                choices = routes[mode].get(kind, routes["0"][kind])
                assert case["enhanced"] == (choices[variant % len(choices)] if variant <= 127 else case["classic"])
        else:
            assert record["phases"] == []
    return sha(path)
