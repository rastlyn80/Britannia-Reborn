# SPDX-License-Identifier: GPL-3.0-or-later
"""Pin the named Enhanced Rune Beetle and Doppleganger sequences."""

import runpy

MEMBERS = {244: '0x39591176444051b', 777: '0x700e7bea7cc93590'}
SPRITES = {
    244: {
        1: ('RuneBeetleQuietGuard', 50, 'aa7433d2bd6d57c258ac1e664471d75050a971a796d0a1e20a568c738afbf9ae'),
        25: ('RuneBeetlePeaceWatch', 50, 'fcd78dafea66230ed39b8a4cb62c069117441857026099c7bd6abb557789a72f'),
        26: ('RuneBeetleCrestDip', 45, '350682a34bc622b7fcdb5d79006bd59eab4492ff05c638a1ee4a916ee01ce58e'),
        27: ('RuneBeetleScarletCrest', 45, '84a61b2c1b32c3a807ae151ec1b18ae272e9f6d52abbafa3606ccbaa4f6787db'),
        28: ('RuneBeetleGuardAlert', 40, '35e6b4fabd5cc6bc2f581575ae41b1c268be6099b91331a1062d0c2494dd58b3'),
    },
    777: {
        12: ('DopplegangerCrossedSweep', 50, '983fda152c556342cf68587f2233628835e8f0deeae2606b36fbb8b268207a46'),
        23: ('DopplegangerFormRise', 65, 'bbbb34d84fd34f305f5459ae99e75c3ceaa363d05d1429214f6acbfc93f4e3c3'),
        26: ('DopplegangerLowWatch', 75, '20d26f593585b63b5c608663170ea061a335842f39cf800bf0f6319ae83cef06'),
        27: ('DopplegangerHighGuard', 60, '1fc94b46d86ed08b6f0338ed39cac99771f804c10228332ed4b33a687cf247a8'),
        28: ('DopplegangerStepAlert', 40, '1ad6d534caab92247efc86b7ed9abb4ab1a3ece5be1d68bfe14743ad50a26492'),
    },
}

TYPES = {244: (2, 5, 8, 14, 15), 777: (5, 8, 11, 15)}
FORMS = {"rune": ("RuneBeetle", 244, 0x8035, "MageAI"), "dopple": ("Doppleganger", 777, 0x455, "MeleeAI")}
RENDERERS = {244: "SourceEnhancedRuneBeetleVisual.gd", 777: "SourceEnhancedDopplegangerVisual.gd"}


def prepare_rune_dopple(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    stage = staged or root
    folder = root / "work/creatures/native-form-audit/enhanced-source-gaps/rune-beetle-doppleganger"
    terrain = read(folder / "runtime-receipt.json")
    render = read(folder / "motion-render-receipt.json")
    dense = read(folder / "dense-clearance-receipt.json")
    assert dense["sample_rate"] == 240
    assert terrain.keys() == render.keys() == dense["bodies"].keys() == {str(body) for body in SPRITES}
    groups = {}
    for body, slots in SPRITES.items():
        groups.update(common["source_tables"](root, source, {body: slots}, TYPES[body], member_hashes=MEMBERS))
    inspect = runpy.run_path(str(root / "scripts/uo-human-sequences.py"))["inspect"]
    rune, = [row for row in inspect(source / "AnimationSequence.uop", {244}) if row["uop_name_hash"] == MEMBERS[244]]
    for mode, expected in zip(rune["modes"], (1, 25), strict=True):
        assert mode["default_group"] == expected and mode["movement"][0] == {
            "action": 0, "one_handed_group": expected, "two_handed_group": expected}
    rows, copies = {}, {}
    for body, slots in SPRITES.items():
        clips = [clip for clip, _, _ in slots.values()]
        key = str(body)
        motion, views, measurements = terrain[key], render[key], dense["bodies"][key]
        assert (motion["poses"], motion["falls"], motion["routes"], motion["classic"]) == ((2325, 150, 120, 90) if body == 244 else (2325, 150, 96, 72))
        assert min(motion["gap"], motion["fall_gap"]) >= .0018 and motion["jump"] < .002
        assert motion["growth"] == (15 if body == 777 else 0) and motion["gaits"] == (24 if body == 244 else 0)
        assert views["poses"] == 50 and set(views["clips"]) == set(clips)
        assert views["scene_sha256"] == motion["hashes"]["modern"]
        assert views["minimum_foreground_box_pixels"] > (14000 if body == 244 else 1200)
        assert measurements.keys() == motion["hashes"].keys() == {"original", "rounded", "modern"}
        for treatment, measurement in measurements.items():
            assert measurement["scene_sha256"] == motion["hashes"][treatment]
            assert measurement["clips"].keys() == set(clips) and measurement["core_triangles"] > 0
            assert sum(clip["samples"] for clip in measurement["clips"].values()) == (1108 if body == 244 else 1202)
            for clip in measurement["clips"].values():
                assert clip["crossings"] == 0 and clip["floor_minimum"] > .0038
        assets = {name: folder / f"{body}-{name}.scn" for name in sorted(motion["hashes"])}
        rows[key], local = common["fitted_row"](root / "Viewer", body, groups[body], clips, assets, motion["hashes"])
        copies.update(local)
    return rows, copies, verify_native(root, stage, folder, groups, terrain, read, digest)


def verify_native(root, stage, folder, groups, terrain, read, digest):
    directory = root / "work/creatures/native-rune-dopple-enhanced"
    path = directory / "rune-dopple-native.json"
    native, runtime = read(path), read(directory / "rune-dopple-native-runtime.json")
    fixture = directory / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert digest(file) == runtime[f"{key}_sha256"].lower()
    assert digest(directory / "NativeRuneDoppleLive.gd") == native["test_sha256"]
    assert digest(folder / "test-rune-dopple-enhanced.gd") == native["inputs_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["checks"] >= 270 and native["records"].keys() == FORMS.keys()
    assert native["renderers"] == {str(body): digest(stage / "Viewer/Presentation" / name)
                                   for body, name in RENDERERS.items()}
    for form, (name, body, corpse_hue, ai) in FORMS.items():
        record = native["records"][form]
        assert (record["class"], record["hue"], record["corpse_body"], record["corpse_hue"], record["ai"]) == (
            name, 0, body, corpse_hue, ai)
        assert record["stock_weapon"] == "Fists" and record["can_move"]
        assert record["tamable"] == (body == 244) and not (record["can_swim"] or record["can_fly"])
        assert max(map(abs, record["step_delta"])) == 1 and record["corpse"] >= 0x40000000
        combat, loot = record["combat"], record["carved"]
        assert loot["gold"] > 0 and combat["target"] > 0
        if body == 244:
            assert 8500 <= combat["elapsed_ms"] <= 12000
            before = combat["before"]
            expected = [value - value // 2 if combat["ml"] else max(0, value - 70) for value in before]
            assert len(before) == 5 and expected == combat["after"] and expected != before
        else:
            packet = combat["packet"]
            assert (packet["protocol"], packet["body"], packet["serial"]) == ("classic", body, record["serial"])
            assert packet["action"] in (4, 5, 6) and combat["clip"]
            assert loot["hides"] >= 6 and loot["ribs"] >= 1
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

