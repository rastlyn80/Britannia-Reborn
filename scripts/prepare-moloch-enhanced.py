# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the indexed Enhanced Moloch motions and original-rig scenes."""

import runpy

BODY = 785
MEMBER = "0x7dd809e7721b6576"
FOLDER = "work/creatures/native-form-audit/enhanced-source-gaps/moloch-enhanced"
RENDERER = "SourceEnhancedMolochVisual.gd"
CLIPS = {1: "MolochCombatRest", 2: "Death", 3: "Death2", 4: "MolochLeftHammer", 5: "MolochRightHammer",
         10: "MolochRecoil", 11: "MolochLowSearch", 12: "MolochRaisedStrike", 15: "MolochFourArmGuard",
         22: "MolochPeaceWalk", 23: "MolochCrouchedRise", 25: "MolochQuietRest", 26: "MolochNearWatch",
         27: "MolochWideThreat", 28: "MolochBracedCharge"}
ATTACKS = {-1: [4, 5, 4, 4, 4, 4], 0: [4, 5, 4], 1: [4], 2: [4], 9: [4]}
ACTIONS = {2: [15, 15], 3: [2, 3], 4: [10], 5: [26, 27], 8: [28], 11: [12, 12, 12],
           14: [11], 15: [23]}

SPRITES = {0: (50, '071d4b14c69f81b87eb707f8072d5775c7e4f071f0fa65c7e63460c71ca1afbc'),
 1: (60, '776807c6060f9aaf991dbf7126671e6d4cd8926fabd4bcda0d907606e928ca91'),
 2: (40, 'a0d4a6d8fb6ef2d903015ce0608f194263275643989554c9a4305798e01694c1'),
 3: (40, '81f08f9dcb63f312981ad30530a090421efc9677f47b191ac77cb4bc29673b9c'),
 4: (45, '0fc94e5b5f871340a0de2abd1142108676eadd473a2fa825fdf08df5adc81a6c'),
 5: (45, 'ad493e9b85c6bacf9ef6211a8232d09d66970f88c0efdd233b49126b61c5f5d7'),
 10: (30, '024979dbb0cde41b94e0ba4c65af912251d9d0d5b3edd9353a4f9dda196d4a5c'),
 11: (50, 'ac06812ccaf7bc4437a1888d398c97bef9c05d5b10423d9a13e496194dd956e9'),
 12: (45, 'f1ed7348a3f9fe5666d2ef7bd5ed20a2f1436ebf372f808cfaa9a4dbd6075a3b'),
 15: (30, '5d04ccb59a9daad7e7546b6640f47b3c2a99bf4f69d0976b988518162f4d3660'),
 22: (60, 'a4184bc743736bf21a5e5decef7416c2f999bd5ad82b05014c149d9c33e375b7'),
 23: (60, 'b434df9cd864745a73f13b778b86e5d5c48efef43d01d060d62324c3fa13ed83'),
 24: (45, '244857a79075dd2d64cc16dc54154e8b22ef1e125c01fa04591b19f5524f3f0d'),
 25: (55, '6c5c5f5be5f60add2915ed47642e3d2e409acd8028b02c3cea65e562bff3b353'),
 26: (50, 'c527dbb6c390df3e64358ede37d021f1cad981b3aa14dd3f17ccaf549781dafe'),
 27: (50, 'd0d374f03cd678be582038bbca6aa4342208f77fb330114e68b7b90caa147bca'),
 28: (30, '8b45431dca8ba56c1846f3e3ad4033e689cf57f0f72dd0539dc5f8281dbad0b6')}


def prepare_moloch(root, source, common, staged=None):
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

    runtime = read(folder / "runtime-receipt.json")
    assert tuple(runtime[key] for key in ("routes", "falls", "fall_poses")) == (492, 30, 480)
    assert runtime["maximum_jump"] < .0025 and runtime["minimum_floor"] >= .0015
    assert runtime["renderer_sha256"] == sha(stage / "Viewer/Presentation" / RENDERER)
    hashes = runtime["hashes"]
    render = read(folder / "motion-render-receipt.json")[str(BODY)]
    clips = [CLIPS[group] for group in (1, 3, 4, 5, 10, 11, 12, 15, 23, 25, 26, 27, 28, 22)]
    assert render["poses"] == 150 and render["clips"] == ["Death", *clips]
    assert render["minimum_foreground_box_pixels"] > 3300 and render["scene_sha256"] == hashes["modern"]
    clearance = read(folder / "dense-clearance-receipt.json")
    assert clearance["sample_rate"] == 240 and clearance["treatments"].keys() == hashes.keys()
    total_samples = 0
    for treatment, measured in clearance["treatments"].items():
        assert measured["scene_sha256"] == hashes[treatment] and measured["clips"].keys() == set(clips)
        for motion in measured["clips"].values():
            assert motion["crossings"] == 0 and motion["same_side_forearm_center_distance"] > .33
            total_samples += motion["samples"]
    assert total_samples == 10062

    modes = {"0": {str(kind): [CLIPS[group] for group in groups] for kind, groups in ACTIONS.items()},
             "1": {"5": [CLIPS[26]]}}
    assets = {treatment: folder / f"{BODY}-{treatment}.scn" for treatment in hashes}
    row, copies = common["fitted_row"](root / "Viewer", BODY, modes, clips, assets, hashes)
    row["attack_subactions"] = {str(key & 255): [CLIPS[group] for group in groups] for key, groups in ATTACKS.items()}
    return {str(BODY): row}, copies, verify_native(root, read, sha)


def verify_native(root, read, sha):
    folder = root / "work/creatures/native-moloch-enhanced"
    path = folder / "moloch-native.json"
    native, engine = read(path), read(folder / "moloch-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert sha(file) == engine[f"{key}_sha256"].lower()
    assert sha(folder / "MolochLive.gd") == native["test_sha256"]
    assert native["checks"] >= 36 and native["corpse"] >= 0x40000000 and native["corpse_gold"] > 0
    assert (native["body"], native["corpse_hue"], native["poison"]) == (BODY, 0x8035, ["Immune", "Poisoned"])
    for name, damage in (("balanced", 10), ("imbalanced", 30)):
        case = native["cases"][name]
        assert case["extra"] == damage and case["mana"] == 25 and case["damage"] > damage
        events = case["events"]
        assert any(event.get("cliloc") == 1060166 for event in events)
        assert any(event["event"] == "sound" and event["id"] == 0x213 for event in events)
        assert any(event.get("graphic") == 0x377A and event["source"] == native["victim"] for event in events)
        assert any(event.get("graphic") == 0x36FE and event["source"] == 0 for event in events)
    control = native["cases"]["control"]
    assert control["mana"] == 0 and control["hits"] >= 3 and control["damage"] > 0
    return sha(path)
