# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the indexed Enhanced Oni motions and original-rig scenes."""

import runpy

BODY = 241
MEMBER = "0xab3fd539c59b1666"
FOLDER = "work/creatures/native-form-audit/enhanced-source-gaps/oni-enhanced"
RENDERER = "SourceEnhancedOniVisual.gd"
CLIPS = {1: "OniCombatRest", 2: "Death", 3: "Death2", 4: "OniSweepingClaw", 5: "OniDoubleClaw",
         10: "OniRecoil", 11: "OniLowSearch", 12: "OniFlameCast", 15: "OniRaisedGuard",
         22: "OniPeaceWalk", 23: "OniCrouchedRise", 25: "OniQuietRest", 26: "OniNearWatch",
         27: "OniOverheadGesture", 28: "OniLowReady"}
ATTACKS = {-1: [4, 5, 4, 4, 4, 4], 0: [4, 5, 4], 1: [4], 2: [4], 9: [4]}
ACTIONS = {2: [15, 15], 3: [2, 3], 4: [10], 5: [26, 27], 8: [28], 11: [12, 12, 12],
           14: [11], 15: [23]}
# Group 27 is listed in the sequence but absent from the inspected patch archives.
# Keep the verified Classic high gesture for that one selector.
SPRITES = {0: (50, '7c5f54633dcc0582f50bacccbb0cab50981b86709ad15d13eca500bac79ce09b'),
 1: (45, 'dc05d398a9d6132b184232b4fedf5caa5aff241a9b6b10ca2aef4b6ea4c49cef'),
 2: (45, '5ce88fdae010ac7b4df4b7aaaec945629bd2f4a49aba7f0c165512aea6dc9477'),
 3: (45, '8df79af6817357c8d2b54b71894ac230acc083c6ccb7714740127a4d4285edd7'),
 4: (30, '220d274926720f05c16fc27551f1f36ebc5495ecb370c78e0b7c5b5a69cab0d5'),
 5: (30, '75e6c08c7f4611998809e0cea834bf48d2e27a5afe48bd24af9d497b58e11ebf'),
 10: (30, 'f2cd79d3cad6b58feaa086e8cd7ef2d8ce2031b07d4a9a23b354c3e8226a989d'),
 11: (55, '75a8d62a88d445faf4b98d9fdcf3f9309a2e2a93eb4f9a5a9f8f87838bac7a57'),
 12: (40, 'af4934476155149118cbe08bdf8531651cd46cd3f64a5470b090a14cf84075fd'),
 15: (35, 'af45bc5a7817fab4f0eea518f3a2d06c3438874d6483e62eee7fd687e93f9e8d'),
 22: (50, '90a77251b9a29c365889281cffea9654def29bfbc308d6bf39fd6ffd612d13d2'),
 23: (45, 'e13427aaaea25b2c25c355e989a7e72fdbc18583439d1b840963ac9aba058f5d'),
 24: (40, 'bf55b11d7fe7d75475ac06b65f208260e7657a5695fef6188fd0910a95f072a6'),
 25: (50, 'c728946ffa2560bd1348f3d9780c677f0c3482e3cc730382f7837cb3d532beb6'),
 26: (60, 'bb31f31960a81b06a5d57b8f3528ace17982bb9d080cd4d75bcb9a5a37644f34'),
 28: (25, '0893943bbd54242c3f02e6037712e0df90d5eed201966c97a738e69115d978a0')}


def prepare_oni(root, source, common, staged=None):
    read, sha = common["read"], common["sha"]
    stage = staged or root
    sequence = source / "AnimationSequence.uop"
    assert sha(sequence) == common["SEQUENCE_SHA256"]
    inspect = runpy.run_path(str(root / "scripts/uo-human-sequences.py"))["inspect"]
    decode = runpy.run_path(str(stage / "scripts/uo-enhanced-frames.py"))["read_amou"]
    record, = (row for row in inspect(sequence, {BODY}) if row["uop_name_hash"] == MEMBER)
    assert not record.get("unparsed_bytes")
    combat, peace = record["modes"]
    assert (combat["mode"], combat["fallback_mode"], peace["mode"], peace["fallback_mode"]) == (0, -1, 1, 0)
    assert combat["transitions"] == [] and peace["transitions"] == [{"target_mode": 0, "group": 28}]
    for mode, groups in ((combat, (1, 0, 24)), (peace, (25, 22, 24))):
        assert mode["movement"] == [{"action": index, "one_handed_group": group, "two_handed_group": group}
                                    for index, group in enumerate(groups)]
    found = {(row["type"], row["subaction"]): row["groups"] for row in combat["new_protocol_actions"]}
    assert found == {(0, subaction): groups for subaction, groups in ATTACKS.items()} | {
        (kind, -1): groups for kind, groups in ACTIONS.items()}
    assert peace["new_protocol_actions"] == [{"type": 5, "subaction": -1, "groups": [26]}]

    folder = root / FOLDER
    for group, (count, digest) in SPRITES.items():
        payload = source / f"ec-frame-{BODY}-{group}.bin"
        if not payload.is_file():
            payload = folder / payload.name
        assert sha(payload) == digest
        identity, frames = decode(payload.read_bytes())
        assert identity == BODY and len(frames) == count and all(frame.group == group for frame in frames)

    runtime = read(folder / "terrain-receipt.json")
    assert tuple(runtime[key] for key in ("routes", "entries", "casts", "ground_poses", "falls", "fall_poses")) == (
        492, 3, 15, 5580, 60, 960)
    assert runtime["maximum_jump"] < .0025 and min(runtime["minimum_floor"], runtime["ground_gap"]) >= .0016
    assert runtime["renderer_sha256"] == sha(stage / "Viewer/Presentation" / RENDERER)
    hashes = runtime["hashes"]
    clips = [CLIPS[group] for group in (1, 4, 5, 10, 11, 12, 15, 23, 25, 26, 28, 22)]
    render = read(folder / "motion-render-receipt.json")[str(BODY)]
    assert render["poses"] == 140 and render["clips"] == ["Death", "Death2", *clips]
    assert render["minimum_foreground_box_pixels"] > 1750 and render["scene_sha256"] == hashes["modern"]
    clearance = read(folder / "dense-clearance-receipt.json")
    assert clearance["sample_rate"] == 240 and clearance["treatments"].keys() == hashes.keys()
    total_samples = 0
    for treatment, measured in clearance["treatments"].items():
        assert measured["scene_sha256"] == hashes[treatment] and measured["clips"].keys() == set(clips)
        for motion in measured["clips"].values():
            assert motion["crossings"] == 0
            total_samples += motion["samples"]
    assert total_samples == 8157

    modes = {"0": {str(kind): [CLIPS[group] for group in groups] for kind, groups in ACTIONS.items()},
             "1": {"5": [CLIPS[26]]}}
    assets = {treatment: folder / f"{BODY}-{treatment}.scn" for treatment in hashes}
    row, copies = common["fitted_row"](root / "Viewer", BODY, modes, clips, assets, hashes)
    row["attack_subactions"] = {str(key & 255): [CLIPS[group] for group in groups] for key, groups in ATTACKS.items()}
    return {str(BODY): row}, copies, verify_native(root, runtime, read, sha)


def verify_native(root, runtime, read, sha):
    folder = root / "work/creatures/native-oni-enhanced"
    path = folder / "oni-native.json"
    native, engine = read(path), read(folder / "oni-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert sha(file) == engine[f"{key}_sha256"].lower()
    assert sha(folder / "NativeOniLive.gd") == native["test_sha256"]
    assert native["renderer_sha256"] == runtime["renderer_sha256"]
    assert native["scene_sha256"] == runtime["hashes"]["modern"]
    assert native["checks"] >= 28 and native["gold"] > 0 and native["corpse"] >= 0x40000000
    assert (native["body"], native["spawn_hue"], native["corpse_hue"]) == (BODY, 0, 0x8035)
    assert native["controlled_coils"] == {"0": 2, "1": 2}
    spell = native["spell"]
    assert spell["last_observed_cast"].endswith("Spell") and spell["damage"] > 0 and spell["tiles"] > 1 and spell["effects"]
    return sha(path)
