# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the fitted Meer Mage, its source pose references, and its native cues."""

import runpy

BODY = 770
MEMBER = "0x6d6f75a039140a6d"
FOLDER = "work/creatures/native-form-audit/enhanced-source-gaps/meer-mage-enhanced"
RENDERER = "SourceEnhancedMeerMageVisual.gd"
CLIPS = {2: "Death", 3: "Death2", 4: "MeerMageCrossingStrike", 5: "MeerMageRaisedStrike",
         6: "MeerMageShortThrust", 10: "MeerMageRecoil", 15: "MeerMageCrossGuard",
         22: "MeerMageMeasuredWalk", 25: "MeerMageQuietStand", 26: "MeerMageHipCheck"}
ATTACKS = {-1: [4, 5, 6, 4, 4, 4], 0: [4, 5, 6], 1: [4], 2: [4], 9: [4]}
ACTIONS = {2: [15, 15], 3: [2, 3], 4: [10], 5: [26, 25], 8: [25], 11: [4, 4, 4], 14: [25], 15: [25]}

SPRITE_SHA256 = {
    2: "de5be8cb2f9a8dcf8dc35b8c827b8f40e84f97453990babf9fe36e9fff4fd1eb",
    3: "c65370a312009c1ea525bc159ed4861d7d6938cc1bfd9eda39bd26345cc0ed34",
    4: "4605461e4ffeb0b444d272fd4d703e0e4d10ad3e32797326ceacdc12e117b6bb",
    5: "8df3b223c6e80892913afea473a43283f745b4ba235bedc470403e37a4c000cc",
    6: "6c8458eb088e93de9eea0a89cfc82b3abce8640000595eb3268a6c0b71e86926",
    10: "0e6c51c019db0de87b3e3cb6da06f7666bb8e84079ba6f8569568f57a21774d5",
    15: "47451423ec64881d9749ab3108f2d9388ce213cf16772811339bc46d315a021c",
    22: "7099aa32f12bc139393b85a2fbabe29684d73ec62246c8c89d7e555fa5dac78f",
    25: "f5ccaf747d681e89afe1511cd0ecd9cc3abfaf2efbfe2fb1272380d7f7f422ed",
    26: "87548486d241328b47df5dacfd5d66a30db9dc7a4707295ff225cfd105f184bb",
}


def prepare_meer_mage(root, source, common, staged=None):
    read, sha = common["read"], common["sha"]
    stage = staged or root
    sequence = source / "AnimationSequence.uop"
    assert sha(sequence) == common["SEQUENCE_SHA256"]
    inspect = runpy.run_path(str(root / "scripts/uo-human-sequences.py"))["inspect"]
    decode = runpy.run_path(str(stage / "scripts/uo-enhanced-frames.py"))["read_amou"]
    record, = (row for row in inspect(sequence, {BODY}) if row["uop_name_hash"] == MEMBER)
    assert not record.get("unparsed_bytes")
    combat, peace = record["modes"]
    for mode, index, fallback in ((combat, 0, -1), (peace, 1, 0)):
        assert (mode["mode"], mode["fallback_mode"], mode["default_group"], mode["transitions"]) == (index, fallback, 25, [])
        assert mode["movement"] == [{"action": i, "one_handed_group": group, "two_handed_group": group}
                                    for i, group in enumerate((25, 22, 25))]
    found = {(row["type"], row["subaction"]): row["groups"] for row in combat["new_protocol_actions"]}
    assert found == {(0, subaction): groups for subaction, groups in ATTACKS.items()} | {
        (kind, -1): groups for kind, groups in ACTIONS.items()}
    assert peace["new_protocol_actions"] == [{"type": 5, "subaction": -1, "groups": [26]}]

    folder = root / FOLDER
    sprites = {row["group"]: row for row in read(folder / "source-evidence.json")}
    frames = {row["old_group"]: row["frame_count"] * 5 for row in record["replacements"] if row["frame_count"]}
    assert sprites.keys() == frames.keys() == CLIPS.keys() == SPRITE_SHA256.keys() and sum(frames.values()) == 235
    for group, count in frames.items():
        payload = folder / f"ec-frame-{BODY}-{group}.bin"
        assert sprites[group]["body"] == BODY and sha(payload) == sprites[group]["sha256"] == SPRITE_SHA256[group]
        identity, poses = decode(payload.read_bytes())
        assert identity == BODY and len(poses) == count and all(pose.group == group for pose in poses)

    runtime = read(folder / "meer-mage-focused.json")
    assert tuple(runtime[key] for key in ("routes", "terrain_poses", "falls", "fall_poses")) == (402, 3000, 60, 960)
    assert runtime["renderer_sha256"] == sha(stage / "Viewer/Presentation" / RENDERER)
    assert runtime["maximum_jump"] < .001 and min(runtime["minimum_floor"], runtime["minimum_fall_floor"]) >= .0018
    hashes = runtime["hashes"]
    names = [name for group, name in CLIPS.items() if group not in (2, 3)]
    render = read(folder / "motion-render-receipt.json")[str(BODY)]
    assert render["poses"] == 110 and render["minimum_foreground_box_pixels"] > 3950
    assert set(render["clips"]) == set(CLIPS.values()) | {"Cast"} and render["scene_sha256"] == hashes["modern"]
    clearance = read(folder / "dense-clearance-receipt.json")
    assert clearance["sample_rate"] == 240 and clearance["treatments"].keys() == hashes.keys()
    total = 0
    for treatment, measured in clearance["treatments"].items():
        assert measured["scene_sha256"] == hashes[treatment] and measured["clips"].keys() == set(names)
        for motion in measured["clips"].values():
            assert motion["crossings"] == 0
            total += motion["samples"]
    assert total == 4113

    modes = {"0": {str(kind): [CLIPS[group] for group in groups] for kind, groups in ACTIONS.items()},
             "1": {"5": [CLIPS[26]]}}
    assets = {treatment: folder / f"{BODY}-{treatment}.scn" for treatment in hashes}
    row, copies = common["fitted_row"](root / "Viewer", BODY, modes, names, assets, hashes)
    row["attack_subactions"] = {str(key & 255): [CLIPS[group] for group in groups] for key, groups in ATTACKS.items()}
    return {str(BODY): row}, copies, verify_native(root, hashes["modern"], read, sha)


def verify_native(root, scene, read, sha):
    folder = root / "work/creatures/native-meer-mage-enhanced"
    path = folder / "meer-mage-native.json"
    native, engine = read(path), read(folder / "meer-mage-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert sha(file) == engine[f"{key}_sha256"].lower()
    assert native["scene_sha256"] == scene and sha(folder / "NativeMeerMageLive.gd") == native["test_sha256"]
    assert native["body"] == BODY and native["checks"] >= 31 and native["hue"] == 0x8035 and native["gold"] > 0
    assert 20 <= native["damage"] <= 40 and native["torch_equipped_and_dispersed"] and native["forest_call"]
    allowed = {"EnragedRabbit", "EnragedHind", "EnragedHart", "EnragedBlackBear", "EnragedEagle"}
    assert native["animals"] and all(item["class"] in allowed for item in native["animals"])
    return sha(path)
