# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify official Enhanced Orc Brute frames, source-rig scenes and stock spell reaction."""

import runpy

BODY = 189
MEMBER = "0xc04e4e5da697b64e"
FOLDER = "work/creatures/native-form-audit/enhanced-source-gaps/orc-brute-enhanced"
RENDERER = "SourceEnhancedOrcBruteVisual.gd"
CLIPS = {1: "BruteCombatRest", 2: "Death", 3: "Death2", 4: "BruteDoubleHammer", 5: "BruteTurningSweep",
         10: "BruteRecoil", 11: "BruteLowRummage", 15: "BruteForearmGuard", 22: "BrutePeaceWalk",
         23: "BruteCrouchedRise", 25: "BruteQuietRest", 26: "BruteNearWatch", 27: "BruteOverheadThreat",
         28: "BruteLowReady"}
ATTACKS = {-1: [4, 5, 4, 4, 4, 4], 0: [4, 5, 4], 1: [4], 2: [4], 9: [4]}
ACTIONS = {2: [15, 15], 3: [2, 3], 4: [10], 5: [26, 27], 8: [28], 11: [4, 4, 4],
           14: [11], 15: [23]}
SPRITES = {0: (50, '88854b8e99fda194af9a671644dcac1cae1afcfb3853f15ea645e4fa9ac23217'),
 1: (50, 'ed4bbcd5adb028a6cf107021bacfacf32dfec5c5d9c3a3194075f67f8efab66d'),
 2: (50, 'cb197062543a03af71aaa3b4a9ac43117f8fb1d294a7754941705015f1765469'),
 3: (55, '126fb10541bb5c8d03e6ab1d7e16c178671a4d5dd9919cbc04b26e6676451da2'),
 4: (45, 'fc56fe7088c18d2069b9442b11aaea21bf85c0cc76c3aea614167aca84245aca'),
 5: (40, '59366819abd17a12b715ce4f8da5930e4c5ae53efc36503933caeb3ac9e42096'),
 10: (35, '9ad43aa25e7d019f065bdee6913ace0ce22b1c31ed4ec65dddc8621be030924e'),
 11: (55, '94619fadb5155a7ded91e43a9545da75cfb05187011cdbd8c17c25d6d6d35eef'),
 15: (35, 'eadab4280b4a800e6c7937ab354af0c3bd2360be0463701017650d21fdc721f1'),
 22: (50, 'b1bfae35455315b018abe6fde037fb1a1f3b8149a5b44e3eb1934aaf5ab04d23'),
 23: (45, '55470e005be1390b8888f1112880612cc6bc3bbad4351a0238d73e00fe9c07e4'),
 24: (35, '181d048ee89890db91002156872dddbca0d095d4649b886503f2a34b19a2d97e'),
 25: (50, '2c463d630c77db95cd6106f8605ea1556922332485dc146124033f867f8fe37b'),
 26: (45, 'fda0af287d67768efa29aa54e0192e0991072b9cc3409f7b76c158df99a76dc3'),
 27: (55, 'ecf136f90d76906ce2813b285ca22a3d79ab38d28ff4e1cab0cf49f0c4e53634'),
 28: (30, '22719ccc71167b69402998f79ce593aa1d4f23dc5bf336eb88db6244d54a50e0')}


def prepare_orc_brute(root, source, common, staged=None):
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
    assert tuple(runtime[key] for key in ("routes", "entries", "ground_poses", "falls", "fall_poses")) == (
        492, 3, 5580, 60, 960)
    assert runtime["maximum_jump"] < .0025 and min(runtime["minimum_floor"], runtime["ground_gap"]) >= .0016
    assert runtime["renderer_sha256"] == sha(stage / "Viewer/Presentation" / RENDERER)
    hashes = runtime["hashes"]
    clips = [CLIPS[group] for group in (1, 3, 4, 5, 10, 11, 15, 23, 25, 26, 27, 28, 22)]
    render = read(folder / "silhouette/motion-render-receipt.json")[str(BODY)]
    assert render["poses"] == 140 and render["clips"] == ["Death", *clips]
    assert render["minimum_foreground_box_pixels"] > 3300 and render["scene_sha256"] == hashes["modern"]
    hues = read(folder / "silhouette/hue-render-receipt.json")
    assert hues["scene_sha256"] == hashes["modern"]
    assert hues["shader_sha256"] == sha(root / "Viewer/Presentation/OstardSurface.gdshader")
    colours = hues["hues"]
    assert colours.keys() == {"0000", "0035", "8035"}
    assert all(row["freeze_difference"] < .02 for row in colours.values())
    assert colours["0000"]["difference_from_neutral"] == 0.0
    assert .0005 < colours["8035"]["difference_from_neutral"] < colours["0035"]["difference_from_neutral"]
    clearance = read(folder / "dense-clearance-receipt.json")
    assert clearance["sample_rate"] == 240 and clearance["treatments"].keys() == hashes.keys()
    total_samples = 0
    for treatment, measured in clearance["treatments"].items():
        assert measured["scene_sha256"] == hashes[treatment] and measured["clips"].keys() == set(clips)
        for motion in measured["clips"].values():
            assert motion["crossings"] == 0
            total_samples += motion["samples"]
    assert total_samples == 9276

    modes = {"0": {str(kind): [CLIPS[group] for group in groups] for kind, groups in ACTIONS.items()},
             "1": {"5": [CLIPS[26]]}}
    assets = {treatment: folder / "silhouette" / f"{BODY}-{treatment}.scn" for treatment in hashes}
    row, copies = common["fitted_row"](root / "Viewer", BODY, modes, clips, assets, hashes)
    row["attack_subactions"] = {str(key & 255): [CLIPS[group] for group in groups] for key, groups in ATTACKS.items()}
    return {str(BODY): row}, copies, verify_native(root, read, sha)


def verify_native(root, read, sha):
    folder = root / "work/creatures/native-orc-brute-enhanced"
    path = folder / "orc-brute-native.json"
    native, engine = read(path), read(folder / "orc-brute-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert sha(file) == engine[f"{key}_sha256"].lower()
    assert sha(folder / "OrcBruteLive.gd") == native["test_sha256"]
    assert native["checks"] >= 32 and native["spell_damage"] > 0 and native["gold"] > 0
    assert (native["body"], native["spell_id"], native["spell_graphic"], native["corpse_hue"]) == (BODY, 5, 0x36E4, 0x8035)
    assert native["corpse"] >= 0x40000000 and native["lord_corpse"] >= 0x40000000 and native["corpse"] != native["lord_corpse"]
    assert native["lord_body"] == 138 and native["lord_class"] == "SpawnedOrcishLord" and native["lord_corpse_deleted"] is True
    assert native["lord_target"] > 0 and native["serial"] != native["lord"] and (native["ore"], native["ingots"]) == (25, 10)
    return sha(path)
