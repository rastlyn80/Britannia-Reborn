# SPDX-License-Identifier: GPL-3.0-or-later
"""Seal the Orc Captain and Black Solen Worker Enhanced motions."""


MEMBERS = {7: "0xceb98539aea3f4c2", 805: "0x6d7bd036c8e91939"}
SPRITES = {
    7: {
        23: ("OrcCaptainAxeBraceRise", 45, "bd3b224366117019cfdb9d4536e52a10905f51b40da75a4a4580925adc40690b"),
        28: ("OrcCaptainLowAxeAlert", 25, "0266f2d1c6d699147d8e6889144c4805eb4c33717de58b4046d3f49e7f8d5e06"),
    },
    805: {
        12: ("BlackSolenRaisedClawPair", 50, "61b141a7bc78d42806c4dbc2df3273e83d14ba7e21bf9c6d214ccc045c3abb74"),
        23: ("BlackSolenLowUnfold", 50, "2270e94c50f4bde5ba6a8bc4f3a8a6afebd04cbbc95885747861074a8cf29074"),
        26: ("BlackSolenAntennaWatch", 55, "82331998749cdf383e1d3e9b5228694725e4d28039e3ac90c72b93701bdf84e3"),
        27: ("BlackSolenHighClawFeint", 50, "19a38a02341cce0428d3c8d7e40bada3a875a7ec36386b8853ba6f1d83c4ead5"),
        28: ("BlackSolenQuietAlert", 40, "7a840ea11a82664ed6db32dfc5adb2f189b6767e4c3379fe007e2d3cb607c6eb"),
    },
}
TYPES = {7: (8, 15), 805: (5, 8, 11, 15)}
TEST = "test-orc-captain-solen-enhanced.gd"
FORMS = {
    "captain": ("OrcCaptain", 7, 0, 0x8035, "SourceEnhancedOrcCaptainVisual.gd"),
    "solen": ("BlackSolenWorker", 805, 0x453, 0x455, "SourceEnhancedBlackSolenWorkerVisual.gd"),
}


def prepare_orc_captain_solen(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    folder = root / "work/creatures/native-form-audit/enhanced-source-gaps/orc-captain-black-solen-worker"
    stage = staged or root
    receipt = read(folder / "terrain-receipt.json")
    assert digest(stage / "scripts" / TEST) == digest(folder / TEST) == receipt["test_sha256"]
    terrain, rendered = receipt["bodies"], read(folder / "motion-render-receipt.json")
    measured = read(folder / "dense-geometry-receipt.json")
    assert measured["sample_rate"] == 240
    assert terrain.keys() == rendered.keys() == measured["bodies"].keys() == {str(body) for body in SPRITES}
    groups, rows, copies = {}, {}, {}
    for body, slots in SPRITES.items():
        captain = body == 7
        clips = [clip for clip, _, _ in slots.values()]
        groups.update(common["source_tables"](root, source, {body: slots}, TYPES[body], member_hashes=MEMBERS))
        motion, render = terrain[str(body)], rendered[str(body)]
        expected = (930, 60, 15, 15) if captain else (2325, 150, 0, 0)
        assert (motion["poses"], motion["falls"], motion["alternate_falls"], motion["dye_checks"]) == expected
        assert (motion["routes"], motion["classic"]) == (24 * len(TYPES[body]), 18 * len(TYPES[body]))
        assert min(motion["gap"], motion["fall_gap"]) >= .0018 and motion["jump"] < .002
        assert render["scene_sha256"] == motion["hashes"]["modern"]
        assert render["poses"] == 10 * len(clips) and set(render["clips"]) == set(clips)
        assert render["minimum_foreground_box_pixels"] >= (11000 if captain else 15000)
        measurements = measured["bodies"][str(body)]
        assert measurements.keys() == motion["hashes"].keys() == {"original", "rounded", "modern"}
        for treatment, measurement in measurements.items():
            assert measurement["scene_sha256"] == motion["hashes"][treatment]
            assert measurement["clips"].keys() == set(clips)
            for clip in measurement["clips"].values():
                assert .0039 <= clip["minimum_foot_height"] <= clip["maximum_foot_height"] <= .0041
                if captain:
                    assert clip["axe_crossings"] == 0
            assert sum(clip["samples"] for clip in measurement["clips"].values()) == (409 if captain else 1274)
        assets = {name: folder / f"{body}-{name}.scn" for name in sorted(motion["hashes"])}
        rows[str(body)], local = common["fitted_row"](root / "Viewer", body, groups[body], clips, assets, motion["hashes"])
        copies.update(local)
    return rows, copies, verify_native(root, stage, folder, groups, terrain, common)


def verify_native(root, stage, folder, groups, terrain, common):
    read, digest = common["read"], common["sha"]
    native_dir = root / "work/creatures/native-orc-captain-solen-enhanced"
    path = native_dir / "orc-captain-solen-native.json"
    native, runtime = read(path), read(native_dir / "orc-captain-solen-native-runtime.json")
    fixture = native_dir / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert digest(file) == runtime[f"{key}_sha256"].lower()
    assert digest(native_dir / "NativeOrcCaptainSolenLive.gd") == native["test_sha256"]
    assert digest(folder / TEST) == native["inputs_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["records"].keys() == FORMS.keys() and native["checks"] >= 186
    for form, record in native["records"].items():
        name, body, hue, corpse_hue, renderer = FORMS[form]
        assert digest(stage / "Viewer/Presentation" / renderer) == native["renderers"][str(body)]
        assert (record["class"], record["hue"], record["stock_weapon"], record["ai"]) == (name, hue, "Fists", "MeleeAI")
        assert record["can_move"] and not (record["tamable"] or record["can_swim"] or record["can_fly"])
        assert len(record["step_delta"]) == 2 and max(map(abs, record["step_delta"])) == 1
        assert record["corpse"] >= 0x40000000 and (record["corpse_body"], record["corpse_hue"]) == (body, corpse_hue)
        combat = record["combat"]
        packet = combat["packet"]
        assert (packet["protocol"], packet["body"], packet["serial"]) == ("classic", body, record["serial"])
        assert packet["action"] in (4, 5, 6) and combat["clip"]
        loot, interaction = record["carved"], record["interaction"]
        assert loot["gold"] > 0
        if body == 7:
            assert loot["ribs"] == 1
            assert interaction["graphic"] == 0x36BD and 0 < interaction["burn_damage"] <= 50
            assert interaction["friendly_while_masked"] and interaction["enemy_before_and_after"]
            assert interaction["mask_destroyed"] and interaction["item"] >= 0x40000000
        else:
            assert loot["fungus"] == 1
            assert interaction["fixture_assigned_friendship"] and interaction["friendly_before_damage"]
            assert interaction["enemy_after_damage"] and (interaction["damage"], interaction["notice"]) == (1, 1054103)
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
