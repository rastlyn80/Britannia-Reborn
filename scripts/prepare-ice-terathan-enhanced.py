# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the fitted Ice Elemental, Terathan Drone and Terathan Warrior."""

MEMBERS = {161: "0x4d8de1d62740dd94", 70: "0x7138a9cb422d1bb9", 71: "0xe35d305252c6562e"}
SPRITES = {
    161: {
        23: ("IceElementalCrossedRise", 45, "c0b2b39d7cd0a0393a9f7400d21d4758a5fef3c39758d982303e5cb3abf53243"),
        28: ("IceElementalSpreadAlert", 25, "ba4b816d1f4cbc1fb474fccdbdc6004b3bb12397b9f5d10202816c680a7d1e64"),
    },
    70: {
        1: ("TerathanWarriorLowWatch", 40, "eace9aa005b56e88c142617db79b8fa22da9b50b6a3a8ad8ec1938d86a041d52"),
        12: ("TerathanWarriorRaisedPincers", 35, "8c65d63baf165a4e52a605ad7a1afe34b76ace60d050421c6b3f82f732e9ef65"),
        23: ("TerathanWarriorUnfold", 40, "ae7b5144bc770e26eb3912641d1dd5971861e1467a38434156d71b7263ebd752"),
        27: ("TerathanWarriorLowPincerBrace", 35, "b1b827b89feee9155496321f06f54bd99ca6fa0c81b721a4d4098a6751376d32"),
        28: ("TerathanWarriorForwardAlert", 30, "9a3745c320ddf363a8b9a5317d19c11a57aeb5ae45a916f8bd69653bc0bae282"),
    },
    71: {
        1: ("TerathanDroneLowWatch", 40, "c0ae43b1a4c4d11d612b3f58edd85ecf54ec888f93e7a441191a9a31a88fa85a"),
        12: ("TerathanDroneRaisedPincers", 40, "17d9b8248a93a8b312509762fffaaa21c37004988c4fd4cf128f160432c5f23d"),
        23: ("TerathanDroneUnfold", 75, "d9007542f94251e0261e75fb24f89723c8fa46ac91a0b8f0612977221d17914e"),
        27: ("TerathanDroneLowPincerBrace", 45, "36e0cba4ee38890737a96570b50e40089b7b3ba81bee878cd87d4d7e25d3d8e1"),
        28: ("TerathanDroneForwardAlert", 25, "01aae78b500bc41cfd7068ae10320f0306f329e74f27eeb4de48ae5487ce9ec7"),
    },
}
TYPES = {161: (8, 15), 70: (5, 8, 11, 15), 71: (5, 8, 11, 15)}
TREATMENTS = {"original", "rounded", "modern"}
TEST = "test-ice-terathan-enhanced.gd"
FORMS = {
    "ice": ("IceElemental", 161, 0x8035, "MageAI", "SourceEnhancedIceElementalVisual.gd"),
    "warrior": ("TerathanWarrior", 70, 0x8035, "MeleeAI", "SourceEnhancedTerathanVisual.gd"),
    "drone": ("TerathanDrone", 71, 0x455, "MeleeAI", "SourceEnhancedTerathanVisual.gd"),
}


def prepare_ice_terathan(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    stage = staged or root
    work = root / "work/creatures"
    gaps = work / "native-form-audit/enhanced-source-gaps"
    ice, terathan = gaps / "ice-elemental", gaps / "terathan-drone-warrior"
    receipt = read(terathan / "terrain-receipt.json")
    assert digest(stage / "scripts" / TEST) == digest(terathan / TEST) == receipt["test_sha256"]
    terrain = receipt["bodies"]
    rendered = read(ice / "motion-render-receipt.json") | read(terathan / "motion-render-receipt.json")
    assert terrain.keys() == rendered.keys() == {str(body) for body in SPRITES}
    groups, rows, copies = {}, {}, {}
    for body, slots in SPRITES.items():
        groups.update(common["source_tables"](root, source, {body: slots}, TYPES[body], member_hashes=MEMBERS))
        clips = [clip for clip, _, _ in slots.values()]
        motion, render = terrain[str(body)], rendered[str(body)]
        assert (motion["poses"], motion["falls"]) == (465 * len(clips), 30 * len(clips))
        assert (motion["routes"], motion["classic"]) == (24 * len(TYPES[body]), 18 * len(TYPES[body]))
        assert min(motion["gap"], motion["fall_gap"]) >= .0018 and motion["jump"] < .002
        assert motion["retained_falls"] == (30 if body == 161 else 0)
        assert render["scene_sha256"] == motion["hashes"]["modern"] and motion["hashes"].keys() == TREATMENTS
        assert render["poses"] == 10 * len(clips) and set(render["clips"]) == set(clips)
        assert render["minimum_foreground_box_pixels"] >= 4000
        folder = ice if body == 161 else terathan
        assets = {name: folder / f"{body}-{name}.scn" for name in sorted(TREATMENTS)}
        rows[str(body)], local = common["fitted_row"](root / "Viewer", body, groups[body], clips, assets, motion["hashes"])
        copies.update(local)
    clearance = read(ice / "crystal-clearance.json")
    assert not clearance["failed"] and clearance["inspection_rate"] == 360
    assert clearance["treatments"].keys() == TREATMENTS
    for name, treatment in clearance["treatments"].items():
        assert treatment["scene_sha256"] == terrain["161"]["hashes"][name]
        assert set(treatment["clips"]) == {"IceElementalCrossedRise", "IceElementalSpreadAlert", "Idle", "Walk", "Run", "Death", "Death2"}
        assert sum(clip["samples"] for clip in treatment["clips"].values()) == 4038
        for clip in treatment["clips"].values():
            assert clip["body_crossings"] == 0 and clip["minimum_blade_distance"] >= .08
    return rows, copies, verify_native(root, stage, work, terathan, groups, terrain, common)


def verify_native(root, stage, work, terathan, groups, terrain, common):
    read, digest = common["read"], common["sha"]
    folder = work / "native-ice-terathan-enhanced"
    path = folder / "ice-terathan-native.json"
    native, runtime = read(path), read(folder / "ice-terathan-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert digest(file) == runtime[f"{key}_sha256"].lower()
    assert digest(folder / "NativeIceTerathanLive.gd") == native["test_sha256"]
    assert digest(terathan / TEST) == native["inputs_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["records"].keys() == FORMS.keys() and native["checks"] >= 285
    for form, record in native["records"].items():
        name, body, hue, ai, renderer = FORMS[form]
        assert digest(stage / "Viewer/Presentation" / renderer) == native["renderers"][str(body)]
        assert (record["class"], record["hue"], record["stock_weapon"], record["ai"]) == (name, 0, "Fists", ai)
        assert record["can_move"] and not any(record[field] for field in ("can_swim", "can_fly", "tamable"))
        assert len(record["step_delta"]) == 2 and max(map(abs, record["step_delta"])) == 1
        assert record["corpse"] >= 0x40000000 and (record["corpse_body"], record["corpse_hue"]) == (body, hue)
        loot, combat = record["carved"], record["combat"]
        assert loot["gold"] > 0
        if body == 161:
            assert loot["pearls"] >= 1 and loot["reagents"] >= 4
            assert combat["damage"] > 0 and 1 <= combat["cast_attempts"] <= 4
        else:
            assert loot["ribs"] >= 4 and (body != 71 or loot["silk"] >= 2)
            packet = combat["packet"]
            assert (packet["protocol"], packet["body"], packet["serial"]) == ("classic", body, record["serial"])
            assert packet["action"] in (4, 5, 6) and combat["clip"]
        phase, = record["phases"]
        assert phase["body"] == body and phase["asset_sha256"] == terrain[str(body)]["hashes"]["modern"]
        cases = phase["cases"]
        expected = {(flag, kind, variation) for flag in (0, 64) for kind in TYPES[body] for variation in (0, 1, 255)}
        assert len(cases) == len(expected) and {(c["flags"], c["type"], c["variation"]) for c in cases} == expected
        for case in cases:
            mode = "0" if case["flags"] & 64 else "1"
            kind, variation = str(case["type"]), case["variation"]
            choices = groups[body][mode].get(kind, groups[body]["0"][kind])
            assert case["enhanced"] == (choices[variation % len(choices)] if variation <= 127 else case["classic"])
    return digest(path)
