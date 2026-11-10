# SPDX-License-Identifier: GPL-3.0-or-later
"""Seal the Ophidian Matriarch and Succubus Enhanced fits against local evidence."""

MEMBERS = {87: "0x561c66aff546ec1b", 149: "0x97f4c7cd39b05b56"}
SPRITES = {
    87: {
        12: ("MatriarchSceptreArc", 55, "8fe9949b59568a78b20ce75f54f6016891f44e917826b307802d342bcc975689"),
        23: ("MatriarchCoiledRise", 50, "b263f55fa20edd9e9741f5837f3815eebc47d7c6529241560ab4f99d1c1b0ac9"),
        26: ("MatriarchTailWatch", 55, "0074cba4e6ea07d476a67f99ca86d073419ce2000a14f23e60b7f6f384d4bd40"),
        27: ("MatriarchRaisedWard", 40, "08bd18bd01f1f3667479a6e9426c351e353e0ccc0f73d4145c4c70f0e13d3c86"),
        28: ("MatriarchSceptreAlert", 55, "315a134c0b14b84d99ddfcc1899754b586a0b027e1a8c3327da70d591f04385f"),
    },
    149: {
        23: ("SuccubusWingCocoonRise", 55, "11d8813d7012156f465a3a7103486851b46fb7e194b887772a8d51c3a7c9cb58"),
        26: ("SuccubusWingWatch", 45, "68533ffc91d7df7b70a2bd0f4d9d91bdef96bc57b1a2fb71c5832014369d06b5"),
        27: ("SuccubusAsymmetricSpread", 50, "44efe49acd8e78e1263cad478f95e34af4b5a8a6da0f28775a16700029ef4acc"),
        28: ("SuccubusWingThreat", 45, "10aa0d1aa5d5e5ef5c196cc431921eb56e8d8869db59a63b53dfde2b7cf96f7b"),
    },
}
TYPES = {87: (5, 8, 11, 15), 149: (5, 8, 15)}
TEST = "test-matriarch-succubus-enhanced.gd"
FORMS = {
    "matriarch": ("OphidianMatriarch", 87, 0x8035, "SourceEnhancedMatriarchVisual.gd"),
    "succubus": ("Succubus", 149, 0x455, "SourceEnhancedSuccubusVisual.gd"),
}


def prepare_matriarch_succubus(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    stage = staged or root
    work = root / "work/creatures"
    folder = work / "native-form-audit/enhanced-source-gaps/matriarch-succubus"
    terrain_receipt = read(folder / "terrain-receipt.json")
    assert digest(stage / "scripts" / TEST) == digest(folder / TEST) == terrain_receipt["test_sha256"]
    terrain = terrain_receipt["bodies"]
    rendered = read(folder / "motion-render-receipt.json")
    staff = read(folder / "sceptre-clearance.json")
    wings = read(folder / "wing-receipt.json")
    assert terrain.keys() == rendered.keys() == {str(body) for body in SPRITES}
    assert staff["sample_rate"] == wings["sample_rate"] == 240 and wings["passed"]
    groups = {}
    for body, slots in SPRITES.items():
        groups.update(common["source_tables"](root, source, {body: slots}, TYPES[body],
                                              flight_fallback=body == 149, member_hashes=MEMBERS))
    rows, copies = {}, {}
    for body, slots in SPRITES.items():
        clips = [clip for clip, _, _ in slots.values()]
        motion, render = terrain[str(body)], rendered[str(body)]
        expected = (2325, 150, 9150, 0) if body == 87 else (1860, 120, 3720, 3)
        assert (motion["poses"], motion["falls"], motion["fall_samples"], motion["flight_flags"]) == expected
        assert (motion["routes"], motion["classic"]) == (24 * len(TYPES[body]), 18 * len(TYPES[body]))
        assert min(motion["gap"], motion["fall_gap"]) >= .0018 and motion["jump"] < .002
        assert render["scene_sha256"] == motion["hashes"]["modern"]
        assert render["poses"] == 10 * len(clips) and set(render["clips"]) == set(clips)
        assert render["minimum_foreground_box_pixels"] >= 5000
        measurements = staff["treatments"] if body == 87 else wings["treatments"]
        assert measurements.keys() == motion["hashes"].keys() == {"original", "rounded", "modern"}
        for treatment, measurement in measurements.items():
            assert measurement["scene_sha256"] == motion["hashes"][treatment]
            assert measurement["clips"].keys() == set(clips)
            for clip in measurement["clips"].values():
                if body == 87:
                    assert clip["crossings"] == 0 and clip["floor"] >= .23
                else:
                    assert clip["distal_core_crossings"] == 0
                    assert clip["maximum_link_error_m"] < .00005 and clip["maximum_tip_step_m"] < .12
            assert sum(clip["samples"] for clip in measurement["clips"].values()) == (1317 if body == 87 else 1021)
        assets = {name: folder / f"{body}-{name}.scn" for name in sorted(motion["hashes"])}
        rows[str(body)], local = common["fitted_row"](root / "Viewer", body, groups[body], clips, assets, motion["hashes"])
        if body == 149:
            rows[str(body)]["flight_falls_back_to_combat"] = True
        copies.update(local)
    return rows, copies, verify_native(root, stage, folder, groups, terrain, common)


def verify_native(root, stage, folder, groups, terrain, common):
    read, digest = common["read"], common["sha"]
    native_dir = root / "work/creatures/native-matriarch-succubus-enhanced"
    path = native_dir / "matriarch-succubus-native.json"
    native, runtime = read(path), read(native_dir / "matriarch-succubus-native-runtime.json")
    fixture = native_dir / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert digest(file) == runtime[f"{key}_sha256"].lower()
    assert digest(native_dir / "NativeMatriarchSuccubusLive.gd") == native["test_sha256"]
    assert digest(folder / TEST) == native["inputs_sha256"]
    presentation = stage / "Viewer/Presentation"
    assert digest(presentation / "matriarch-sceptre-clearance.gd") == native["clearance_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["records"].keys() == FORMS.keys() and native["checks"] >= 204
    for form, record in native["records"].items():
        name, body, hue, renderer = FORMS[form]
        assert digest(presentation / renderer) == native["renderers"][str(body)]
        assert (record["class"], record["hue"], record["stock_weapon"], record["ai"]) == (name, 0, "Fists", "MageAI")
        assert record["can_move"] and not any(record[flag] for flag in ("can_swim", "can_fly", "tamable"))
        assert len(record["step_delta"]) == 2 and max(map(abs, record["step_delta"])) == 1
        assert record["corpse"] >= 0x40000000 and (record["corpse_body"], record["corpse_hue"]) == (body, hue)
        loot, combat = record["carved"], record["combat"]
        assert loot["gold"] > 0
        if form == "matriarch":
            assert combat["damage"] > 0 and 1 <= combat["cast_attempts"] <= 4
        else:
            assert (loot["ribs"], loot["hides"]) == (1, 0)
            assert combat["controlled_trigger"] and combat["graphic"] == 0x374A
            assert 10 <= combat["damage"] <= 40 and combat["damage"] <= combat["healed"] <= 100
        phase, = record["phases"]
        assert phase["body"] == body and phase["asset_sha256"] == terrain[str(body)]["hashes"]["modern"]
        cases = phase["cases"]
        expected = {(flag, kind, variant) for flag in (0, 64) for kind in TYPES[body] for variant in (0, 1, 255)}
        assert len(cases) == len(expected) and {(c["flags"], c["type"], c["variation"]) for c in cases} == expected
        for case in cases:
            mode = "0" if case["flags"] & 64 else "1"
            kind, variant = str(case["type"]), case["variation"]
            choices = groups[body][mode].get(kind, groups[body]["0"][kind])
            assert case["enhanced"] == (choices[variant % len(choices)] if variant <= 127 else case["classic"])
    return digest(path)
