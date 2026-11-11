# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the Treefellow source, two corpse poses and native Dismount evidence."""

import runpy

BODY = 301
MEMBER = "0x5c4d9a10c6b2c4c7"
FOLDER = "work/creatures/native-form-audit/enhanced-source-gaps/treefellow-enhanced"
RENDERER = "SourceEnhancedTreefellowVisual.gd"
CLIPS = {0: "Walk", 1: "TreefellowCombatIdle", 2: "Death", 3: "Death2", 4: "TreefellowBranchHammer",
         5: "TreefellowRakingSwipe", 10: "TreefellowBarkRecoil", 11: "TreefellowLowGather",
         12: "TreefellowRootCast", 15: "TreefellowBracedGuard", 22: "TreefellowQuietWalk", 23: "TreefellowSlowRise",
         24: "Run", 25: "TreefellowQuietIdle", 26: "TreefellowWoodlandWatch", 27: "TreefellowCanopyLift",
         28: "TreefellowRootReady"}
ATTACKS = {-1: [4, 5, 4, 4, 4, 4], 0: [4, 5, 4], 1: [4], 2: [4], 9: [4]}
ACTIONS = {2: [15, 15], 3: [2, 3], 4: [10], 5: [26, 27], 8: [28], 11: [12, 12, 12], 14: [11], 15: [23]}

SPRITE_SHA256 = {
    0: "181f0846f427a44290877997943291308bec15079d5bc73b35fcb4ea218a0d2e",
    1: "52fc4f74f92de888edb970f69141396effc36b91d0c53cef611a98f03d552666",
    2: "dcf4fc2913efe8eaa043be716b4b6083691e3fe054f7bf1ce2decf6213481019",
    3: "d12a5f610e7a7cfd44ba6e0cedcf67a87aaee44200b5e6dfc5821d5d1a8043f0",
    4: "7b69238dabb1021cd8307e06be826c5af90e14a7b02165d9c2102ebe630aa06e",
    5: "23f666456a96712b90c7f86b0cef868b97484b72c36a739fe930a8353cef13dc",
    10: "8ae50e7bbb4a048fd7e262a12dd6de95ce39ebfefc19161373390aa597d338ca",
    11: "010f19302ce684a55153ba7960d25da455e92fad17dffd6ea56dd0c2a51fd471",
    12: "d4be34d3598f8470e1a011c716f4a4c184432b8b0fad9f12a6319d0b70e8a786",
    15: "e53737d8dc06f519b820f16fe8ab5ffc162626eb0f2d7c80300b9350af9080f8",
    22: "52e581bff2003b9efbfa526693278c59d948b1515dde03d8bf92d72fb8a0aac6",
    23: "0155d75dc31842b785cf8a6ebd2e716f5d9f681afc62cd77cb033052f0102f47",
    24: "0a505a2c23d066508ddfecba47ea14457ee86ef7f1e1cef5015022ca1d9aa77d",
    25: "05c63207f38c2796b5b55c87ac56fdbdb5d49fbb2eecf0b468cd9650140314c6",
    26: "76a23f916c61d390c3993803d7045ee97e36aba308d6793afdf6a45fb804c5f8",
    27: "6340d67e3625f31f7d39bc299a438b1a0504b45f4dc905aeb33794bf65b37ff8",
    28: "dfc3222a08a46f0c8f70f3297aae433f78b83da72df516eba4ea20377278fd43",
}


def prepare_treefellow(root, source, common, staged=None):
    read, sha = common["read"], common["sha"]
    stage = staged or root
    sequence = source / "AnimationSequence.uop"
    assert sha(sequence) == common["SEQUENCE_SHA256"]
    inspect = runpy.run_path(str(root / "scripts/uo-human-sequences.py"))["inspect"]
    decode = runpy.run_path(str(stage / "scripts/uo-enhanced-frames.py"))["read_amou"]
    record, = (row for row in inspect(sequence, {BODY}) if row["uop_name_hash"] == MEMBER)
    assert not record.get("unparsed_bytes")
    combat, peace = record["modes"]
    for mode, index, fallback, groups in ((combat, 0, -1, (1, 0, 24)), (peace, 1, 0, (25, 22, 24))):
        assert (mode["mode"], mode["fallback_mode"], mode["default_group"]) == (index, fallback, groups[0])
        assert mode["movement"] == [{"action": action, "one_handed_group": group, "two_handed_group": group}
                                    for action, group in enumerate(groups)]
    assert combat["transitions"] == [] and peace["transitions"] == [{"target_mode": 0, "group": 28}]
    found = {(row["type"], row["subaction"]): row["groups"] for row in combat["new_protocol_actions"]}
    assert found == {(0, subaction): groups for subaction, groups in ATTACKS.items()} | {
        (kind, -1): groups for kind, groups in ACTIONS.items()}
    assert peace["new_protocol_actions"] == [{"type": 5, "subaction": -1, "groups": [26]}]

    folder = root / FOLDER
    sprites = {row["group"]: row for row in read(folder / "source-evidence.json")}
    frames = {row["old_group"]: row["frame_count"] * 5 for row in record["replacements"] if row["frame_count"]}
    assert sprites.keys() == frames.keys() == CLIPS.keys() == SPRITE_SHA256.keys() and sum(frames.values()) == 835
    for group, count in frames.items():
        payload = folder / f"ec-frame-{BODY}-{group}.bin"
        assert sprites[group]["body"] == BODY and sha(payload) == sprites[group]["sha256"] == SPRITE_SHA256[group]
        identity, poses = decode(payload.read_bytes())
        assert identity == BODY and len(poses) == count and all(pose.group == group for pose in poses)

    runtime = read(folder / "treefellow-focused.json")
    assert tuple(runtime[key] for key in ("routes", "terrain_poses", "falls", "fall_poses")) == (405, 4875, 60, 960)
    assert runtime["renderer_sha256"] == sha(stage / "Viewer/Presentation" / RENDERER)
    assert runtime["maximum_jump"] < .001 and min(runtime["minimum_floor"], runtime["minimum_fall_floor"]) >= .0018
    assert runtime["minimum_corpse_height_ratio"] >= 1.5
    hashes = runtime["hashes"]
    names = [name for group, name in CLIPS.items() if group not in (0, 2, 24)]
    render = read(folder / "motion-render-receipt.json")[str(BODY)]
    assert render["poses"] == 170 and render["minimum_foreground_box_pixels"] > 4900
    assert set(render["clips"]) == set(CLIPS.values()) and render["scene_sha256"] == hashes["modern"]
    clearance = read(folder / "dense-clearance-receipt.json")
    assert clearance["sample_rate"] == 240 and clearance["treatments"].keys() == hashes.keys()
    total = 0
    for treatment, measured in clearance["treatments"].items():
        assert measured["scene_sha256"] == hashes[treatment] and measured["clips"].keys() == set(names)
        for motion in measured["clips"].values():
            assert motion["crossings"] == 0 and motion["maximum_supported_foot_gap"] <= .004
            total += motion["samples"]
    assert total == 11508

    modes = {"0": {str(kind): [CLIPS[group] for group in groups] for kind, groups in ACTIONS.items()},
             "1": {"5": [CLIPS[26]]}}
    assets = {treatment: folder / f"{BODY}-{treatment}.scn" for treatment in hashes}
    row, copies = common["fitted_row"](root / "Viewer", BODY, modes, [], assets, hashes)
    row["attack_subactions"] = {str(key & 255): [CLIPS[group] for group in groups] for key, groups in ATTACKS.items()}
    return {str(BODY): row}, copies, verify_native(root, hashes["modern"], read, sha)


def verify_native(root, scene, read, sha):
    folder = root / "work/creatures/native-treefellow-enhanced"
    path = folder / "treefellow-native.json"
    native, engine = read(path), read(folder / "treefellow-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert sha(file) == engine[f"{key}_sha256"].lower()
    assert native["scene_sha256"] == scene and sha(folder / "NativeTreefellowLive.gd") == native["test_sha256"]
    assert native["body"] == BODY and native["checks"] >= 30 and native["hue"] == 0x8035 and native["gold"] > 0
    assert 23 <= native["logs"] <= 34 and native["damage"] >= 15 and native["mana"] == 20
    assert native["daze"] == "Dazed" and native["normal_remount"] and 1 <= native["swings"] <= 16
    assert len(native["stock_attacks"]) == 2 and set(native["stock_attacks"]) <= {"Attack", "Attack2"}
    return sha(path)
