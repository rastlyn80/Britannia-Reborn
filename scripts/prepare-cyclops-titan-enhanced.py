# SPDX-License-Identifier: GPL-3.0-or-later
"""Seal the fitted Cyclops and Titan clips against the two named records."""

MEMBERS = {75: "0xc01a70b3a9ed94ca", 76: "0x9b4cc6b1e6e33f71"}
SPRITES = {
    75: {
        4: ("CyclopsOverheadMallet", 55, "872aa5893d1f86b609b903bd2c0315dbaad46ea810225f87dab7141d77295e3f"),
        23: ("CyclopsRiseWithMallet", 60, "df1b5971f7711a6241673707639890f0120ce21bcc3c4dd54039726df66af152"),
        26: ("CyclopsPalmGlance", 65, "7a5e9c5042d2ab9a96416d623e21c640b76f75fa86891769479d4d4cb677b738"),
        27: ("CyclopsRaisedMallet", 50, "6f94226d4e679c6b2209d41261bf94820e68a5fc7ec5dfbf166731a63cd9875d"),
        28: ("CyclopsForwardGuard", 55, "51d7ea3536ea8e68f8e33361286244abe3ff9146b075438856762f44faf2d7a8"),
    },
    76: {
        4: ("TitanOverheadHammerfist", 45, "2ff79dc0950634110df1008698c77fdda7c1333e4f799752ec79a2919a28bfd5"),
        23: ("TitanWideRise", 55, "a009f039e8dfb5183442c8fba72835d5bdcad7531b47ccfe5837eac5fdb19c70"),
        26: ("TitanShoulderShift", 55, "e029555f8632346ba79318e10876984d6c82663b3c790c78b07e152b32b0be4c"),
        27: ("TitanRaisedFists", 50, "f2b5e977705769defb7207108a8156b8abe79571ad1196c2e2e75b2f5a3ec779"),
        28: ("TitanShoulderAlert", 55, "9043d508e957efe95b2eea6169755c14ea17ee8e4c91b3380fc5b0f61209318a"),
    },
}
TYPES = (5, 8, 11, 15)
TREATMENTS = {"original", "rounded", "modern"}
TEST = "test-cyclops-titan-enhanced.gd"
FORMS = {
    "cyclops": ("Cyclops", 75, 0x8035, "MeleeAI", "SourceEnhancedCyclopsVisual.gd"),
    "titan": ("Titan", 76, 0x455, "MageAI", "SourceEnhancedTitanVisual.gd"),
}


def prepare_cyclops_titan(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    stage = staged or root
    work = root / "work/creatures"
    scenes = work / "native-form-audit/enhanced-source-gaps/cyclops-titan"
    receipt = read(scenes / "terrain-receipt.json")
    assert digest(stage / "scripts" / TEST) == digest(scenes / TEST) == receipt["test_sha256"]
    terrain, rendered = receipt["bodies"], read(scenes / "motion-render-receipt.json")
    groups = common["source_tables"](root, source, SPRITES, TYPES, member_hashes=MEMBERS)
    assert terrain.keys() == rendered.keys() == {str(body) for body in groups}
    rows, copies = {}, {}
    for body, source_groups in SPRITES.items():
        clips = [clip for clip, _, _ in source_groups.values()]
        motion, render = terrain[str(body)], rendered[str(body)]
        assert (motion["poses"], motion["falls"], motion["routes"], motion["classic"]) == (2325, 150, 96, 72)
        assert min(motion["gap"], motion["fall_gap"]) >= .0018 and motion["jump"] < .002
        assert motion["hashes"].keys() == TREATMENTS and render["scene_sha256"] == motion["hashes"]["modern"]
        assert render["poses"] == 50 and set(render["clips"]) == set(clips)
        assert render["minimum_foreground_box_pixels"] >= 6000
        assets = {name: scenes / f"{body}-{name}.scn" for name in sorted(TREATMENTS)}
        rows[str(body)], local = common["fitted_row"](root / "Viewer", body, groups[body], clips, assets, motion["hashes"])
        copies.update(local)
    proof = read(scenes / "mallet-clearance.json")
    assert not proof["failed"] and proof["inspection_rate"] == 600 and proof["treatments"].keys() == TREATMENTS
    for name, treatment in proof["treatments"].items():
        assert treatment["sha256"] == terrain["75"]["hashes"][name]
        assert treatment["clips"].keys() == {clip for clip, _, _ in SPRITES[75].values()}
        assert sum(clip["samples"] for clip in treatment["clips"].values()) == 3167
        for clip in treatment["clips"].values():
            assert clip["crossings"] == 0 and clip["floor"] >= .004 and clip["grip"] <= .00001 and clip["tip_step"] <= .04
    return rows, copies, verify_native(root, stage, work, scenes, groups, terrain, common)


def verify_native(root, stage, work, scenes, groups, terrain, common):
    read, digest = common["read"], common["sha"]
    folder = work / "native-cyclops-titan-enhanced"
    path = folder / "cyclops-titan-native.json"
    native, runtime = read(path), read(folder / "cyclops-titan-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert digest(file) == runtime[f"{key}_sha256"].lower()
    assert digest(folder / "NativeCyclopsTitanLive.gd") == native["test_sha256"]
    assert digest(scenes / TEST) == native["inputs_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["records"].keys() == FORMS.keys() and native["checks"] >= 215
    expected = {(flag, kind, variation) for flag in (0, 64) for kind in TYPES for variation in (0, 1, 255)}
    for form, record in native["records"].items():
        name, body, hue, ai, renderer = FORMS[form]
        assert digest(stage / "Viewer/Presentation" / renderer) == native["renderers"][str(body)]
        assert (record["class"], record["hue"], record["stock_weapon"], record["ai"]) == (name, 0, "Fists", ai)
        assert record["can_move"] and not any(record[field] for field in ("can_swim", "can_fly", "tamable"))
        assert len(record["step_delta"]) == 2 and max(map(abs, record["step_delta"])) == 1
        assert record["corpse"] >= 0x40000000 and (record["corpse_body"], record["corpse_hue"]) == (body, hue)
        assert record["carved"]["ribs"] >= 4 and record["carved"]["gold"] > 0
        combat = record["combat"]
        if body == 75:
            packet = combat["packet"]
            assert (packet["protocol"], packet["body"], packet["serial"]) == ("classic", body, record["serial"])
            assert packet["action"] in (4, 5, 6) and combat["clip"]
        else:
            assert combat["damage"] > 0 and combat["target"] > 0
        phase, = record["phases"]
        assert phase["body"] == body and phase["asset_sha256"] == terrain[str(body)]["hashes"]["modern"]
        cases = phase["cases"]
        assert len(cases) == len(expected) and {(c["flags"], c["type"], c["variation"]) for c in cases} == expected
        for case in cases:
            mode = "0" if case["flags"] & 64 else "1"
            kind, variation = str(case["type"]), case["variation"]
            choices = groups[body][mode].get(kind, groups[body]["0"][kind])
            assert case["enhanced"] == (choices[variation % len(choices)] if variation <= 127 else case["classic"])
    return digest(path)
