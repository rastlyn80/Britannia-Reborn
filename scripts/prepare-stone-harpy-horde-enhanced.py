# SPDX-License-Identifier: GPL-3.0-or-later
"""Seal the Stone Harpy and wild Horde Minion Enhanced fits."""

MEMBERS = {73: "0x54dd45112cdc03fd", 776: "0x2b623c50cddffa83"}
SPRITES = {
    73: {
        11: ("StoneHarpyFoldAndSweep", 45, "d54f74f356370279e7439bf4cd1d933814e4737f8e34180453f5cb24b7c3f0e4"),
        12: ("StoneHarpyDoubleWingbeat", 50, "1209d10ddd9b1221ca6e53d3118f969f5bb443b8759eaa11970827af6d22dc37"),
        15: ("StoneHarpyShieldAndFlare", 35, "491c2d07aadfcac53150ca730c4e09150ad767dc67ea836d3231563b9618670f"),
        23: ("StoneHarpyFoldedLaunch", 55, "14a27c3b322efb04aa6040a6c4e93b7996c7175e06c938530f9f0fc06cf504cd"),
        26: ("StoneHarpyNarrowWatch", 55, "78fa8c7a76a0e0c47e7485f78d5b0c139ecf8655ec5b10905cee1ed08fcbfc16"),
        27: ("StoneHarpyBankedSpread", 55, "0560705d6ae43d719cc8127415fd88ce29a8ebf20b2c8f38ce0d59612e340d83"),
        28: ("StoneHarpyOpenAlert", 45, "600fdb92959c8a41fdfea573096053dff233b098c3e74b767aa87a2bcec5d20a"),
    },
    776: {
        12: ("HordeMinionOverheadLunge", 45, "3fbf2b5e3a5cacf6df0354e5b486159241b868449cbfe0920ec178c7ad58d880"),
        23: ("HordeMinionUncurl", 45, "6fbc8baa800bd23e5a945e1e47e44d4a97a637447b13e57b082b78ede8b9972e"),
        26: ("HordeMinionUneasyWatch", 55, "51b3829f67c554904c5037bc108500d1bd03ac6c59219b903807340176374904"),
        27: ("HordeMinionGraspingGuard", 50, "c4850cedc7b86f86d392ccd79f572e211d1376d28050098d35f484fd7db5ddf3"),
        28: ("HordeMinionRaisedClawAlert", 40, "2c8117342b45fb0ae5eb7c334f2588624b0acf9251a13d2a3610d5aadd8bb59a"),
    },
}
TYPES = {73: (2, 5, 8, 11, 14, 15), 776: (5, 8, 11, 15)}
TEST = "test-stone-harpy-horde-enhanced.gd"
FORMS = {
    "stoneharpy": ("StoneHarpy", 73, 0x8035, "SourceEnhancedStoneHarpyVisual.gd"),
    "horde": ("HordeMinion", 776, 0x455, "SourceEnhancedHordeMinionVisual.gd"),
}


def prepare_stone_harpy_horde(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    stage = staged or root
    folder = root / "work/creatures/native-form-audit/enhanced-source-gaps/stone-harpy-horde-minion"
    terrain_receipt = read(folder / "terrain-receipt.json")
    assert digest(stage / "scripts" / TEST) == digest(folder / TEST) == terrain_receipt["test_sha256"]
    terrain = terrain_receipt["bodies"]
    rendered = read(folder / "motion-render-receipt.json")
    sampled = read(folder / "dense-motion-receipt.json")
    assert terrain.keys() == rendered.keys() == sampled["bodies"].keys() == {str(body) for body in SPRITES}
    assert sampled["sample_rate"] == 240 and sampled["passed"]
    groups = {}
    for body, slots in SPRITES.items():
        groups.update(common["source_tables"](root, source, {body: slots}, TYPES[body],
                                              flight_fallback=body == 73, member_hashes=MEMBERS))
    rows, copies = {}, {}
    for body, slots in SPRITES.items():
        clips = [clip for clip, _, _ in slots.values()]
        motion, render = terrain[str(body)], rendered[str(body)]
        expected = (3255, 210, 15, 75) if body == 73 else (2325, 150, 0, 0)
        assert (motion["poses"], motion["falls"], motion["flight"], motion["air_falls"]) == expected
        assert (motion["routes"], motion["classic"]) == (24 * len(TYPES[body]), 18 * len(TYPES[body]))
        assert min(motion["gap"], motion["fall_gap"]) >= .0018 and motion["jump"] < .002
        assert render["scene_sha256"] == motion["hashes"]["modern"]
        assert render["poses"] == 10 * len(clips) and set(render["clips"]) == set(clips)
        assert render["minimum_foreground_box_pixels"] >= 6000
        measurements = sampled["bodies"][str(body)]
        assert measurements.keys() == motion["hashes"].keys() == {"original", "rounded", "modern"}
        for treatment, measurement in measurements.items():
            assert measurement["scene_sha256"] == motion["hashes"][treatment]
            assert measurement["clips"].keys() == set(clips)
            assert all(clip["floor_minimum"] >= .0038 and clip["maximum_tip_step"] <= .055
                       for clip in measurement["clips"].values())
            assert sum(clip["samples"] for clip in measurement["clips"].values()) == (1721 if body == 73 else 1200)
        if body == 73:
            launch = measurements["modern"]["clips"]["StoneHarpyFoldedLaunch"]
            assert launch["minimum_tip_span"] <= 1.12 and launch["maximum_tip_span"] >= 2.70
            assert .54 <= launch["floor_maximum"] <= .56
        else:
            lunge = measurements["modern"]["clips"]["HordeMinionOverheadLunge"]
            assert lunge["highest_hand"] >= 1.7 and lunge["floor_maximum"] <= .005
        assets = {name: folder / f"{body}-{name}.scn" for name in sorted(motion["hashes"])}
        rows[str(body)], local = common["fitted_row"](root / "Viewer", body, groups[body], clips, assets, motion["hashes"])
        if body == 73:
            rows[str(body)]["flight_falls_back_to_combat"] = True
        copies.update(local)
    return rows, copies, verify_native(root, stage, folder, groups, terrain, common)


def verify_native(root, stage, folder, groups, terrain, common):
    read, digest = common["read"], common["sha"]
    native_dir = root / "work/creatures/native-stone-harpy-horde-enhanced"
    path = native_dir / "stone-harpy-horde-native.json"
    native, runtime = read(path), read(native_dir / "stone-harpy-horde-native-runtime.json")
    fixture = native_dir / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert digest(file) == runtime[f"{key}_sha256"].lower()
    assert digest(native_dir / "NativeStoneHarpyHordeLive.gd") == native["test_sha256"]
    assert digest(folder / TEST) == native["inputs_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["records"].keys() == FORMS.keys() and native["checks"] >= 355
    for form, record in native["records"].items():
        name, body, hue, renderer = FORMS[form]
        stone = body == 73
        assert digest(stage / "Viewer/Presentation" / renderer) == native["renderers"][str(body)]
        assert (record["class"], record["hue"], record["stock_weapon"], record["ai"]) == (name, 0, "Fists", "MeleeAI")
        assert record["can_fly"] == stone and record["can_move"] and not record["can_swim"] and not record["tamable"]
        assert len(record["step_delta"]) == 2 and max(map(abs, record["step_delta"])) == 1
        assert record["corpse"] >= 0x40000000 and (record["corpse_body"], record["corpse_hue"]) == (body, hue)
        loot, combat = record["carved"], record["combat"]
        if stone:
            assert (loot["ribs"], loot["feathers"]) == (1, 50) and loot["gold"] > 0
        else:
            assert loot["bones"] == 3
        packet = combat["packet"]
        assert (packet["protocol"], packet["body"], packet["serial"]) == ("classic", body, record["serial"])
        assert packet["action"] in (4, 5, 6) and combat["clip"]
        phase, = record["phases"]
        assert phase["body"] == body and phase["asset_sha256"] == terrain[str(body)]["hashes"]["modern"]
        cases = phase["cases"]
        flags = (0, 64, 4, 68) if stone else (0, 64)
        expected = {(flag, kind, variant) for flag in flags for kind in TYPES[body] for variant in (0, 1, 255)}
        assert len(cases) == len(expected) and {(c["flags"], c["type"], c["variation"]) for c in cases} == expected
        for case in cases:
            mode = "0" if case["flags"] & 68 else "1"
            kind, variant = str(case["type"]), case["variation"]
            choices = groups[body][mode].get(kind, groups[body]["0"][kind])
            assert case["enhanced"] == (choices[variant % len(choices)] if variant <= 127 else case["classic"])
    return digest(path)
