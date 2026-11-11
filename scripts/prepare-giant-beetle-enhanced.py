# SPDX-License-Identifier: GPL-3.0-or-later
"""Check the indexed Giant Beetle frames and the fitted Third Dawn scenes."""

import runpy

BODY = 791
MEMBER = "0x8a7365d17b57b517"
FOLDER = "work/creatures/native-form-audit/enhanced-source-gaps/giant-beetle-enhanced"
RENDERER = "SourceEnhancedGiantBeetleVisual.gd"
CLIPS = {
    0: "BeetleWingedWalk", 1: "BeetleWingedIdle", 2: "Death2", 4: "BeetleWingedBite",
    5: "BeetleWingedHook", 10: "BeetleWingedHit", 22: "BeetleQuietWalk", 24: "Run", 25: "Idle",
    26: "BeetleWingedFlare", 27: "BeetleWingedDisplay", 28: "BeetleRaiseWings",
    29: "BeetleMountedWalk", 30: "BeetleMountedRun", 31: "BeetleMountedIdle",
}
ATTACKS = {-1: [4, 5, 4, 4, 4, 4], 0: [4, 5, 4], 1: [4], 2: [4], 9: [4]}
ACTIONS = {2: [25, 1], 3: [2, 0], 4: [10], 5: [26, 27], 8: [28], 11: [4, 4, 4], 14: [25], 15: [25]}

SPRITE_SHA256 = {
    0: "3766b1649d33192874b0de348b16a14b3fc84f40c10302ad54224083e658a82c",
    1: "7b6db325b187f9165351c1730273ddceccd8a10b92c312a744f2030b8ee6a293",
    2: "72a978220c790a4c9a34f3f467b37f0fb1be38bd265e01157284c93bedf1934c",
    4: "767d7cfda03fb0eb0972456f2918e27c1fa231af22f8d31335dacc688224088b",
    5: "c35bb9158da2ecd741de4fbb5671dfb8f1576dfbedf0c574e10d5a8b3904fa2e",
    10: "ed9d2889fd70bf201d8bbd3286d86f9ea6d20dede4742f870f0904794a73076a",
    22: "15d1a45da75d81427cb685420174d41e56cd37fd6c8104fa5f89ab000bf57e7d",
    24: "f71e9775293f1df1d0f3808f0f4c14af67027198f7b2dd8bd6a4d2dd341a5bde",
    25: "39de93d9c1780eefc136cc9238e3ad8bf90e58f83f0eb32ae15fd1f8df51f58c",
    26: "2e19eaefc80359f7b50d3c135f22aa6e970594cdae2ad2dc7d8a80f231e964e1",
    27: "46a34c4dae2856a3e58aa6f6f055fc46c8d852c5f04640600e33e09412ae6d60",
    28: "cdb2ddb11e7b3d59f6f5f3ee0d7caec4addd0d094b809cc58f7effed605910a6",
    29: "865ccc5899225a275e6ac1d9ff1542fe03bd404ab09f4bfdda5bca7056b77875",
    30: "750c027f8fb1730e399446fb581511e771f2e234718cee4096e1f039ce66d45b",
    31: "f95b30da8d1590fc2b00ccb035e6a9144adc49c20495fe82ab96630512776549",
}


def prepare_giant_beetle(root, source, common, staged=None):
    read, sha = common["read"], common["sha"]
    stage = staged or root
    sequence = source / "AnimationSequence.uop"
    assert sha(sequence) == common["SEQUENCE_SHA256"]
    inspect = runpy.run_path(str(root / "scripts/uo-human-sequences.py"))["inspect"]
    decode = runpy.run_path(str(stage / "scripts/uo-enhanced-frames.py"))["read_amou"]
    record, = (row for row in inspect(sequence, {BODY}) if row["uop_name_hash"] == MEMBER)
    assert not record.get("unparsed_bytes")
    combat, peace, mounted = record["modes"]
    assert combat["transitions"] == mounted["transitions"] == []
    assert peace["transitions"] == [{"target_mode": 0, "group": 28}]
    for mode, index, fallback, groups in ((combat, 0, -1, (1, 0, 24)), (peace, 1, 0, (25, 22, 24)),
                                          (mounted, 2, 1, (31, 29, 30))):
        assert (mode["mode"], mode["fallback_mode"], mode["default_group"]) == (index, fallback, groups[0])
        assert mode["movement"] == [{"action": action, "one_handed_group": group, "two_handed_group": group}
                                    for action, group in enumerate(groups)]
    found = {(row["type"], row["subaction"]): row["groups"] for row in combat["new_protocol_actions"]}
    assert found == {(0, subaction): groups for subaction, groups in ATTACKS.items()} | {
        (kind, -1): groups for kind, groups in ACTIONS.items()}
    for mode, group in ((peace, 26), (mounted, 31)):
        assert mode["new_protocol_actions"] == [{"type": 5, "subaction": -1, "groups": [group]}]

    folder = root / FOLDER
    sprites = {row["group"]: row for row in read(folder / "source-evidence.json")}
    frame_counts = {row["old_group"]: row["frame_count"] * 5 for row in record["replacements"] if row["frame_count"]}
    assert sprites.keys() == frame_counts.keys() == CLIPS.keys() == SPRITE_SHA256.keys() and sum(frame_counts.values()) == 710
    for group, count in frame_counts.items():
        payload = folder / f"ec-frame-{BODY}-{group}.bin"
        assert sprites[group]["body"] == BODY and sha(payload) == sprites[group]["sha256"] == SPRITE_SHA256[group]
        identity, frames = decode(payload.read_bytes())
        assert identity == BODY and len(frames) == count and all(frame.group == group for frame in frames)

    runtime = read(folder / "beetle-enhanced-receipt.json")
    assert tuple(runtime[key] for key in ("routes", "terrain_poses", "falls", "frozen")) == (387, 2565, 60, 60)
    assert runtime["maximum_jump"] < .001 and min(runtime["minimum_floor"], runtime["minimum_fall_floor"]) >= .0018
    assert runtime["renderer_sha256"] == sha(stage / "Viewer/Presentation" / RENDERER)
    hashes = runtime["hashes"]
    render = read(folder / "motion-render-receipt.json")[str(BODY)]
    assert render["poses"] == 170 and render["minimum_foreground_box_pixels"] > 5000
    assert render["scene_sha256"] == hashes["modern"] and len(set(render["clips"])) == 17

    modes = {"0": {str(kind): [CLIPS[group] for group in groups] for kind, groups in ACTIONS.items()},
             "1": {"5": [CLIPS[26]]}}
    # The alternate type-3 entry points to the combat walk. Keep the native fall.
    modes["0"]["3"][1] = "Death"
    assets = {treatment: folder / f"{BODY}-{treatment}.scn" for treatment in hashes}
    row, copies = common["fitted_row"](root / "Viewer", BODY, modes, [], assets, hashes)
    row["attack_subactions"] = {str(key & 255): [CLIPS[group] for group in groups] for key, groups in ATTACKS.items()}
    return {str(BODY): row}, copies, verify_native(root, runtime, read, sha)


def verify_native(root, runtime, read, sha):
    folder = root / "work/creatures/native-giant-beetle-enhanced"
    path = folder / "giant-beetle-native.json"
    native, engine = read(path), read(folder / "giant-beetle-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert sha(file) == engine[f"{key}_sha256"].lower()
    assert sha(folder / "NativeBeetleLive.gd") == native["test_sha256"]
    assert native["renderer_sha256"] == runtime["renderer_sha256"] and native["asset_sha256"] == runtime["hashes"]["modern"]
    assert native["checks"] == 161 and native["failures"] == 0
    assert {entry["female"] for entry in native["records"]} == {False, True}
    assert all((entry["native_class"], entry["body"], entry["mount_item"], entry["ride_permitted"])
               == ("Beetle", BODY, 0x3EBC, True) for entry in native["records"])
    for sex in ("0", "1"):
        assert native["riding"][sex] == [CLIPS[group] for group in (31, 29, 30)]
        assert native["controlled_enhanced"][sex] == [CLIPS[group] for group in (26, 28, 5, 27)]
    return sha(path)
