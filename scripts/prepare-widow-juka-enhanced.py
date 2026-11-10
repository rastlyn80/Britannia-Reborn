# SPDX-License-Identifier: GPL-3.0-or-later
"""Pin the named Enhanced Widow and Juka Mage sequences."""

MEMBERS = {157: '0x286f52cb7b588af8', 765: '0xa2cebdc9f5d4275'}
SPRITES = {
    157: {
        12: ('GiantBlackWidowLegReach', 45, '5ba19ffb6efec25c5404f7de7d37d5bc3162a02762303c5c83ace1ad782e9078'),
        23: ('GiantBlackWidowUnfold', 50, 'ee4174d20a83ec793a7651a890dfb3516bd1c0106ca2c29501fa97c124e2ad16'),
        26: ('GiantBlackWidowAbdomenCheck', 40, '0d0a8570eb51948ea01a49fc83614d6d0f322851eab86e6145923c2a099c8700'),
        27: ('GiantBlackWidowRearBrace', 50, 'f5a13f1a33e14d085f32e7e4e2ea682b8ad2a80e1cf972d557450c5a9c470625'),
        28: ('GiantBlackWidowReadyAlert', 40, '80b061b210b40c8a03413655a09363c2e9bbaf96f0d7f3aa6aced8df530cd7ef'),
    },
    765: {
        23: ('JukaMageUnbow', 45, 'fd261b6c3dff56b79e745a897d0f5c034a967f61c425c56b2a9ccdee6a47bbeb'),
        28: ('JukaMageStepReady', 30, '28adf48c3a0f405813ba48747f709205bc4ffc841ba68bc5053ef183bd9f44cf'),
    },
}

TYPES = {157: (5, 8, 11, 15), 765: (8, 15)}
FORMS = {"widow": ("GiantBlackWidow", 157, 0x8035, "MeleeAI"),
         "juka": ("JukaMage", 765, 0x455, "MageAI")}
RENDERERS = {157: "SourceEnhancedBlackWidowVisual.gd", 765: "SourceEnhancedJukaMageVisual.gd"}


def prepare_widow_juka(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    stage = staged or root
    folder = root / "work/creatures/native-form-audit/enhanced-source-gaps/giant-black-widow-juka-mage"
    terrain = read(folder / "runtime-receipt.json")
    render = read(folder / "motion-render-receipt.json")
    dense = read(folder / "dense-clearance-receipt.json")
    assert dense["sample_rate"] == 240
    assert terrain.keys() == render.keys() == dense["bodies"].keys() == {str(body) for body in SPRITES}
    groups, rows, copies = {}, {}, {}
    for body, slots in SPRITES.items():
        clips = [clip for clip, _, _ in slots.values()]
        groups.update(common["source_tables"](
            root, source, {body: slots}, TYPES[body], member_hashes=MEMBERS))
        key = str(body)
        motion, views, measurements = terrain[key], render[key], dense["bodies"][key]
        expected = (2325, 150, 15, 96, 72) if body == 157 else (930, 60, 0, 48, 36)
        assert tuple(motion[name] for name in ("poses", "falls", "growth", "routes", "classic")) == expected
        assert min(motion["gap"], motion["fall_gap"]) >= .0018 and motion["jump"] < .002
        assert views["poses"] == 10 * len(clips) and set(views["clips"]) == set(clips)
        assert views["scene_sha256"] == motion["hashes"]["modern"]
        assert views["minimum_foreground_box_pixels"] >= (36 if body == 157 else 4800)
        assert measurements.keys() == motion["hashes"].keys() == {"original", "rounded", "modern"}
        for treatment, measurement in measurements.items():
            assert measurement["scene_sha256"] == motion["hashes"][treatment]
            assert measurement["clips"].keys() == set(clips) and measurement["core_triangles"] > 0
            assert sum(clip["samples"] for clip in measurement["clips"].values()) == (1200 if body == 157 else 409)
            for clip in measurement["clips"].values():
                assert clip["crossings"] == 0 and clip["floor_minimum"] >= .0038
                assert clip["normalized_distal_clearance"] >= (.11 if body == 157 else .61)
        assets = {name: folder / f"{body}-{name}.scn" for name in sorted(motion["hashes"])}
        rows[key], local = common["fitted_row"](root / "Viewer", body, groups[body], clips, assets, motion["hashes"])
        copies.update(local)
    return rows, copies, verify_native(root, stage, folder, groups, terrain, read, digest)


def verify_native(root, stage, folder, groups, terrain, read, digest):
    directory = root / "work/creatures/native-widow-juka-mage-enhanced"
    path = directory / "widow-juka-mage-native.json"
    native, runtime = read(path), read(directory / "widow-juka-mage-native-runtime.json")
    fixture = directory / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert digest(file) == runtime[f"{key}_sha256"].lower()
    assert digest(directory / "NativeWidowJukaLive.gd") == native["test_sha256"]
    assert digest(folder / "test-widow-juka-enhanced.gd") == native["inputs_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["checks"] >= 230 and native["records"].keys() == FORMS.keys()
    assert native["renderers"] == {str(body): digest(stage / "Viewer/Presentation" / name)
                                   for body, name in RENDERERS.items()}
    for form, (name, body, corpse_hue, ai) in FORMS.items():
        record = native["records"][form]
        assert (record["class"], record["hue"], record["corpse_body"], record["corpse_hue"], record["ai"]) == (
            name, 0, body, corpse_hue, ai)
        assert record["stock_weapon"] == "Fists" and record["can_move"]
        assert not (record["tamable"] or record["can_swim"] or record["can_fly"])
        assert max(map(abs, record["step_delta"])) == 1 and record["corpse"] >= 0x40000000
        combat, loot = record["combat"], record["carved"]
        special = combat["special"]
        assert loot["gold"] > 0 and combat["target"] > 0
        if body == 157:
            packet = combat["packet"]
            assert (packet["protocol"], packet["body"], packet["serial"]) == ("classic", body, record["serial"])
            assert packet["action"] in (4, 5, 6) and combat["clip"]
            assert special["deadly"] and special["damage"] > 0 and special["target"] == combat["target"]
            assert loot["silk"] >= 5
        else:
            assert combat["damage"] > 0 and loot["gems"] >= 1 and special["lord"] > 0
            assert 18000 <= special["elapsed_ms"] < 22000
            assert special["buffed"] == [base + int(base * ratio) for base, ratio in
                                          zip(special["baseline"], (.75, .50, .50))]
        phase, = record["phases"]
        assert phase["asset_sha256"] == terrain[str(body)]["hashes"]["modern"]
        cases = phase["cases"]
        expected = {(flag, kind, var) for flag in (0, 64) for kind in TYPES[body] for var in (0, 1, 2, 255)}
        assert len(cases) == len(expected) and {(c["flags"], c["type"], c["variation"]) for c in cases} == expected
        for case in cases:
            mode, kind, variant = ("0" if case["flags"] else "1"), str(case["type"]), case["variation"]
            choices = groups[body][mode].get(kind, groups[body]["0"][kind])
            assert case["enhanced"] == (choices[variant % len(choices)] if variant <= 127 else case["classic"])
    return digest(path)

