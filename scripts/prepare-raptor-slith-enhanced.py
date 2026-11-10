# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the source inputs, posed scenes and native reptile evidence."""

import runpy

MEMBERS = {730: '0x9fed8396eb2a2d', 734: '0xafc4399ccb01be12'}
SPRITES = {
    730: {
        4: ('RaptorRearAndSnap', 45, '1b3987881949d3173c55cd5fb229fbd2d037686b07afd70ced8d4ba4bc2f35d5'),
        15: ('RaptorDuckAndRecover', 35, '42e666c96725d41e0b33beff69b08946d0822227160a2bedccd4597fa02f18f2'),
        23: ('RaptorUncoil', 50, '396863717f58ac6ca6272c2ca1d8eaa2d5497ad1567f301d7b42b51967756179'),
        25: ('RaptorQuietWatch', 50, 'ef14e77bed3deeb55eb5bc5dde13a9ae7c55d0bdaa72ff4e494f673170b2829a'),
        26: ('RaptorHighSurvey', 65, 'f8dd53ceebc05af30d91aa1e1bc8afac5770065e9e96fba8afdd4da53bb25e73'),
        27: ('RaptorForwardStalk', 45, '712c8f2d50015ee2f50bbfc68488f6e1d7c1c63ae8579c3bfd8c87ef65742d39'),
        28: ('RaptorClawAlert', 45, '47d92b8bf158d42ecbc5974deabd934c6007fdedf369a1552f4e0db3176c682b'),
    },
    734: {
        4: ('SlithHeadFeint', 50, 'a354e3c05984a60f906bbc5aa6116c11c1dec2f516dfefa3c612ef5311a16704'),
        15: ('SlithCurlRecoil', 35, 'f3e950373a4e82d7e67d0657aa9d68601014d4b9dc96ec85e5e957189844b49f'),
        23: ('SlithTailUncoil', 50, '5ec313f61763599183a85a5ed206c095003e5cbbeda35903977e87d78fd68925'),
        25: ('SlithQuietCoast', 50, '4755ff313ce3b47863bfe0051dc1f86e235e5893c884edb72dfadcfa39be37d7'),
        26: ('SlithNoseSweep', 55, '9e4f49c56daebac9c4f8e31979e0f95190d3d8b57cf7222724b2babfcca96396'),
        27: ('SlithCrestWarning', 45, '47d2764a6c554f13afda0c728816810cab69b5646e8e7faad959430bd9c1bdaf'),
        28: ('SlithGroundAlert', 35, '2e9898ea41a22e370fd8cb789225215cd352c0041022820efb094cf538851538'),
    },
}

TYPES = (2, 5, 8, 11, 14, 15)
FORMS = {
    "raptor": ("Raptor", 730, 0, 0x8035, True, True, 7, 11),
    "slith": ("Slith", 734, 0, 0x455, True, False, 6, 10),
    "stone": ("StoneSlith", 734, 0, 0x8035, True, True, 1, 12),
    "toxic": ("ToxicSlith", 734, 476, 0x455, False, False, 6, 11),
}
RENDERERS = {730: "SourceEnhancedRaptorVisual.gd", 734: "SourceEnhancedSlithVisual.gd"}
FOLDER = "work/creatures/native-form-audit/enhanced-source-gaps/golem-sand-vortex/raptor-slith-source"


def prepare_raptor_slith(root, source, common, staged=None):
    read, sha = common["read"], common["sha"]
    stage = staged or root
    folder = root / FOLDER
    runtime = read(folder / "runtime-receipt.json")
    gpu = read(folder / "motion-render-receipt.json")
    dense = read(folder / "dense-clearance-receipt.json")
    assert dense["sample_rate"] == 240 and runtime.keys() == gpu.keys() == dense["bodies"].keys()
    tables = common["source_tables"](root, source, SPRITES, TYPES, member_hashes=MEMBERS)
    inspect = runpy.run_path(str(root / "scripts/uo-human-sequences.py"))["inspect"]
    named = {row["animation_ref"]: row for row in inspect(source / "AnimationSequence.uop", set(SPRITES))
             if row["uop_name_hash"] == MEMBERS[row["animation_ref"]]}
    assert named.keys() == SPRITES.keys()
    rows, copies = {}, {}
    for body, groups in SPRITES.items():
        for mode, idle, walk in ((0, 1, 0), (1, 25, 22)):
            moves = named[body]["modes"][mode]["movement"]
            assert [(row["action"], row["one_handed_group"], row["two_handed_group"]) for row in moves] == [
                (0, idle, idle), (1, walk, walk), (2, 24, 24)]
        key = str(body)
        metrics, render = runtime[key], gpu[key]
        assert tuple(metrics[field] for field in ("poses", "falls", "routes", "classic", "gaits")) == (3255, 210, 144, 108, 18)
        assert metrics["breath_poses"] == (465 if body == 734 else 0)
        assert metrics["gap"] >= .0029 and metrics["jump"] < .002
        clips = [row[0] for row in groups.values()]
        reviewed = clips + (["SlithFireBreath"] if body == 734 else [])
        assert render["poses"] == 10 * len(reviewed) and set(render["clips"]) == set(reviewed)
        assert render["minimum_foreground_box_pixels"] > 2800
        assert metrics["hashes"]["modern"] == render["scene_sha256"]
        geometry = dense["bodies"][key]
        assert geometry.keys() == metrics["hashes"].keys()
        samples = 0
        for treatment, measured in geometry.items():
            assert measured["scene_sha256"] == metrics["hashes"][treatment]
            assert measured["clips"].keys() == set(reviewed)
            for clip in measured["clips"].values():
                assert clip["crossings"] == 0 and clip["maximum_supported_foot_gap"] < .004
                samples += clip["samples"]
        assert samples == (4863 if body == 730 else 6048)
        assets = {name: folder / f"{body}-{name}.scn" for name in sorted(metrics["hashes"])}
        rows[key], files = common["fitted_row"](root / "Viewer", body, tables[body], clips, assets, metrics["hashes"])
        copies.update(files)
    return rows, copies, verify_native(root, stage, tables, runtime, read, sha)


def verify_native(root, stage, tables, terrain, read, sha):
    folder = root / "work/creatures/native-raptor-slith-enhanced"
    path = folder / "raptor-slith-native.json"
    native, runtime = read(path), read(folder / "raptor-slith-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert sha(file) == runtime[f"{key}_sha256"].lower()
    assert sha(folder / "NativeRaptorSlithLive.gd") == native["test_sha256"]
    assert sha(stage / "scripts/test-raptor-slith-enhanced.gd") == native["inputs_sha256"]
    assert sha(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["checks"] >= 730 and native["records"].keys() == FORMS.keys()
    assert native["renderers"] == {str(body): sha(stage / "Viewer/Presentation" / name)
                                   for body, name in RENDERERS.items()}
    for form, (name, body, initial, dye, tame, bleed, ribs, hides) in FORMS.items():
        witness = native["records"][form]
        assert (witness["class"], witness["hue"], witness["corpse_body"], witness["corpse_hue"]) == (name, initial, body, dye)
        assert (witness["stock_weapon"], witness["ai"], witness["tamable"], witness["bleed"]) == ("Fists", "MeleeAI", tame, bleed)
        assert witness["can_move"] and not any(witness[key] for key in ("can_swim", "can_fly"))
        assert witness["corpse"] >= 0x40000000 and max(map(abs, witness["step_delta"])) == 1
        combat, loot = witness["combat"], witness["carved"]
        assert combat["target"] > 0 and combat["packet"]["action"] in (4, 5, 6) and combat["packet"]["body"] == body
        assert loot["ribs"] >= ribs and loot["hides"] >= hides and loot["gold"] > 0
        if form in ("slith", "toxic"):
            ability = combat["ability"]
            assert ability["graphic"] == 0x36D4 and ability["damage"] > 0
            assert 2000 < ability["elapsed_ms"] < 4200 and ability["origin_error_m"] < .001
        elif form == "stone":
            ability, tail = combat["ability"], combat["tail"]
            assert ability["graphic"] == 0x37B9 and ability["resistance_drop"] > 0
            assert 9000 < ability["elapsed_ms"] < 12500
            assert tail["graphic"] == 0x376A and tail["stunned"] != tail["confused"]
        phase, = witness["phases"]
        assert phase["asset_sha256"] == terrain[str(body)]["hashes"]["modern"]
        expected = {(flag, kind, var) for flag in (0, 64) for kind in TYPES for var in (0, 1, 2, 255)}
        cases = phase["cases"]
        assert len(cases) == len(expected) and {(case["flags"], case["type"], case["variation"]) for case in cases} == expected
        for case in cases:
            mode, kind, variant = ("0" if case["flags"] else "1"), str(case["type"]), case["variation"]
            choices = tables[body][mode].get(kind, tables[body]["0"][kind])
            assert case["enhanced"] == (choices[variant % len(choices)] if variant <= 127 else case["classic"])
    return sha(path)

