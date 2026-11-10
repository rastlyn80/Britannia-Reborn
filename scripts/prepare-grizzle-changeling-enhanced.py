# SPDX-License-Identifier: GPL-3.0-or-later
"""Seal the exact Enhanced groups for Interred Grizzle and Changeling."""

MEMBERS = {259: "0xee46140adf64e35f", 264: "0xb6027192e01fd395"}
SPRITES = {
    259: {
        12: ("GrizzleAntlerGuard", 50, "2bb672603087e5e778589c71f470419fbc6a3e8c368e541f3dd0743b8c4aad21"),
        23: ("GrizzleUncurl", 55, "0cde1aa6ce05383c26f2d6ae5bda27a3c27641adaa3c3a7e234d0c987dab18f2"),
        26: ("GrizzleFurCheck", 55, "e469c4548e348df40f837fe2890b7752440c864b5b64bcc2a578d9fed9a7f2cb"),
        27: ("GrizzleSwayThreat", 55, "82743cb9c7fe8a9b60edd02a8cb26c9fbdbd1ada23401f79189214e73ab9d2a2"),
        28: ("GrizzleLowReach", 45, "e1e2a2d8955a0d64f77e6351c418991202745065bed369afacfb4de0d662ce79"),
    },
    264: {
        12: ("ChangelingWingDrop", 45, "aabf957b518f3704441a98d38761f78a8eefd48af3aa49042306bb6dd9303fb7"),
        23: ("ChangelingWingRise", 60, "229ed1285053afcf227a7bbb540f4284e5b330c6131b67d18b1e2d1baa2dc291"),
        26: ("ChangelingHoverReach", 45, "73022eb3822dbefa8c6533e93c04800ae27db6ffeedfce67dc4794d496aab759"),
        27: ("ChangelingWingFlourish", 55, "a9f705aa6aef2385a9e3551eacafd7e72264e879dafc8296a44918600afa1ec0"),
        28: ("ChangelingTuckedHover", 35, "451d327e5d848406882c5335c5bb5ed9074cd505e7b445c344a0e9e466d26112"),
    },
}
TYPES = (5, 8, 11, 15)
TEST = "test-grizzle-changeling-enhanced.gd"
RENDERER = "SourceEnhancedGrizzleChangelingVisual.gd"
FORMS = {
    "grizzle": ("InterredGrizzle", 259, 0x8035),
    "ilhenir": ("Ilhenir", 259, 0x455),
    "changeling": ("Changeling", 264, 0x8035),
}


def prepare_grizzle_changeling(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    stage = staged or root
    folder = root / "work/creatures/native-form-audit/enhanced-source-gaps/interred-grizzle-changeling"
    receipt = read(folder / "terrain-receipt.json")
    assert digest(stage / "scripts" / TEST) == digest(folder / TEST) == receipt["test_sha256"]
    terrain = receipt["bodies"]
    render = read(folder / "motion-render-receipt.json")
    dense = read(folder / "dense-clearance-receipt.json")
    assert dense["sample_rate"] == 240
    assert terrain.keys() == render.keys() == dense["bodies"].keys() == {str(body) for body in SPRITES}
    groups, rows, copies = {}, {}, {}
    for body, slots in SPRITES.items():
        clips = [clip for clip, _, _ in slots.values()]
        changeling = body == 264
        groups.update(common["source_tables"](
            root, source, {body: slots}, TYPES, member_hashes=MEMBERS, flight_fallback=changeling
        ))
        key = str(body)
        motion, views, measurements = terrain[key], render[key], dense["bodies"][key]
        assert (motion["poses"], motion["falls"], motion["routes"], motion["classic"]) == (2325, 150, 96, 72)
        assert motion["flight_comparisons"] == (72 if changeling else 0)
        if changeling:
            assert motion["hover_samples"] >= 2100 and .42 < motion["hover_peak"] < .50
        assert min(motion["gap"], motion["fall_gap"]) >= .0018
        assert motion["jump"] < .002 and views["scene_sha256"] == motion["hashes"]["modern"]
        assert views["poses"] == 50 and set(views["clips"]) == set(clips)
        assert views["minimum_foreground_box_pixels"] >= (4800 if changeling else 7100)
        assert measurements.keys() == motion["hashes"].keys() == {"original", "rounded", "modern"}
        for treatment, measurement in measurements.items():
            assert measurement["scene_sha256"] == motion["hashes"][treatment]
            assert measurement["clips"].keys() == set(clips) and measurement["core_triangles"] >= 130
            assert sum(clip["samples"] for clip in measurement["clips"].values()) == (1196 if changeling else 1278)
            for clip in measurement["clips"].values():
                assert clip["crossings"] == 0
                if changeling:
                    assert .06 <= clip["floor_minimum"] <= clip["floor_peak"] < .43
                    assert 1.24 <= clip["wing_span"] <= 1.26
                else:
                    assert .0035 <= clip["floor_minimum"] <= clip["floor_peak"] <= .008
        assets = {name: folder / f"{body}-{name}.scn" for name in sorted(motion["hashes"])}
        rows[key], local = common["fitted_row"](root / "Viewer", body, groups[body], clips, assets, motion["hashes"])
        if changeling:
            rows[key]["flight_falls_back_to_combat"] = True
        copies.update(local)
    return rows, copies, verify_native(root, stage, folder, groups, terrain, common)


def verify_native(root, stage, folder, groups, terrain, common):
    read, digest = common["read"], common["sha"]
    native_dir = root / "work/creatures/native-grizzle-changeling-enhanced"
    path = native_dir / "grizzle-changeling-native.json"
    native, runtime = read(path), read(native_dir / "grizzle-changeling-native-runtime.json")
    fixture = native_dir / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert digest(file) == runtime[f"{key}_sha256"].lower()
    assert digest(native_dir / "NativeGrizzleChangelingLive.gd") == native["test_sha256"]
    assert digest(folder / TEST) == native["inputs_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["records"].keys() == FORMS.keys() and native["checks"] >= 280
    assert set(native["renderers"]) == {"259", "264"}
    assert set(native["renderers"].values()) == {digest(stage / "Viewer/Presentation" / RENDERER)}
    for form, record in native["records"].items():
        name, body, corpse_hue = FORMS[form]
        assert (record["class"], record["hue"], record["stock_weapon"], record["ai"]) == (name, 0, "Fists", "MageAI")
        assert record["can_move"] and not (record["tamable"] or record["can_swim"] or record["can_fly"])
        assert len(record["step_delta"]) == 2 and max(map(abs, record["step_delta"])) == 1
        assert record["corpse"] >= 0x40000000 and (record["corpse_body"], record["corpse_hue"]) == (body, corpse_hue)
        combat, loot = record["combat"], record["carved"]
        special = combat["special"]
        assert loot["gold"] > 0 and combat["target"] > 0
        if form == "grizzle":
            assert combat["damage"] > 0 and 1 <= combat["cast_attempts"] <= 4
            assert (special["graphic"], special["hue"]) == (0x122A, 0x95) and 1 <= len(special["pools"]) <= 3
        else:
            packet = combat["packet"]
            assert (packet["protocol"], packet["body"], packet["serial"]) == ("classic", body, record["serial"])
            assert packet["action"] in (4, 5, 6) and combat["clip"]
        if form == "ilhenir":
            assert loot["bones"] and special["walk_only"] and special["released"]
            assert special["notice"] == 1072069 and 27000 <= special["elapsed_ms"] < 35000
        if form == "changeling":
            assert loot["arrows"] >= 35 and loot["bolts"] >= 25
            assert special["serial"] == record["serial"] and special["revealed_body"] == 264
            assert special["human_body"] in (400, 401) and special["hair"] == 0x203B and special["hair_hue"] == 0x455
            assert special["robe"] > 0 and special["robe_hue"] == 0x489
        phase, = record["phases"]
        assert phase["body"] == body and phase["asset_sha256"] == terrain[str(body)]["hashes"]["modern"]
        cases = phase["cases"]
        expected = {(flag, kind, variant) for flag in (0, 64) for kind in TYPES for variant in (0, 1, 255)}
        assert len(cases) == len(expected) and {(c["flags"], c["type"], c["variation"]) for c in cases} == expected
        for case in cases:
            mode = "0" if case["flags"] & 64 else "1"
            kind, variant = str(case["type"]), case["variation"]
            choices = groups[body][mode].get(kind, groups[body]["0"][kind])
            assert case["enhanced"] == (choices[variant % len(choices)] if variant <= 127 else case["classic"])
    return digest(path)
