# SPDX-License-Identifier: GPL-3.0-or-later
"""Seal the Efreet and Terathan Avenger Enhanced motions."""


MEMBERS = {131: "0xae41645c8fb8d9a5", 152: "0x1564279b544a7dff"}
SPRITES = {
    131: {
        23: ("EfreetLampArrival", 75, "550846319686973836103879ae9b251750f26ec36e67884ff1c485e5035971a5"),
        26: ("EfreetCarpetBalance", 60, "aacf9f4d21e4152497e6712dd310206ab0a46310aee64a07a23619ec25500ed0"),
        27: ("EfreetCarpetSalute", 60, "fed6d7631b2846009f8e8549ecb7a19a6e3c7a436e59bf692e1673ef78ea9743"),
        28: ("EfreetCarpetWatch", 60, "1e36eb0ba2785a1e6d42e71db96d5dabd506c70a4ae0181b49d13848d59056f1"),
    },
    152: {
        12: ("AvengerCrossedPincers", 55, "6e32fdfb3f84a5eae874bf748bd2d02111cd4ba3df3bdf0428e14548468a9e81"),
        23: ("AvengerUnfold", 50, "5e723e96b8e6f44224ddc54d9fe44bd6ce685672ff3699aebede64143ba9b9e0"),
        26: ("AvengerPincerWatch", 50, "101657b9cc4de43b5640d8264819e6bf379e5ccca2464d5d6dad0502e06e918d"),
        27: ("AvengerHighThreat", 60, "2da8affe9360707bf666cfc3448a10d147953721fcc9a88ef3f1ecd2197f25e2"),
        28: ("AvengerQuietBrace", 40, "f2664298979161c66221e03a0894b5bac14e948610fa1c8406ebcdefbb9802b2"),
    },
}
TYPES = {131: (5, 8, 15), 152: (5, 8, 11, 15)}
TEST = "test-efreet-avenger-enhanced.gd"
FORMS = {
    "efreet": ("Efreet", 131, 0x8035, "SourceEnhancedEfreetVisual.gd"),
    "avenger": ("TerathanAvenger", 152, 0x455, "SourceEnhancedTerathanAvengerVisual.gd"),
}
PROP_SCRIPTS = {"SourceEnhancedEfreetVisual.gd", "EfreetEnhancedProps.gd", "efreet-carpet.gdshader", "efreet-smoke.gdshader"}


def prepare_efreet_avenger(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    stage = staged or root
    folder = root / "work/creatures/native-form-audit/enhanced-source-gaps/efreet-terathan-avenger"
    receipt = read(folder / "terrain-receipt.json")
    assert digest(stage / "scripts" / TEST) == digest(folder / TEST) == receipt["test_sha256"]
    terrain = receipt["bodies"]
    assert terrain.keys() == {str(body) for body in SPRITES}
    groups, rows, copies = {}, {}, {}
    for body, slots in SPRITES.items():
        clips = [clip for clip, _, _ in slots.values()]
        groups.update(common["source_tables"](root, source, {body: slots}, TYPES[body], member_hashes=MEMBERS))
        motion = terrain[str(body)]
        expected = (1860, 120, 15, 1860) if body == 131 else (2325, 150, 0, 0)
        assert (motion["poses"], motion["falls"], motion["growth_recoveries"], motion["prop_poses"]) == expected
        assert (motion["routes"], motion["classic"]) == (24 * len(TYPES[body]), 18 * len(TYPES[body]))
        assert min(motion["gap"], motion["fall_gap"]) >= .0018 and motion["jump"] < .002
        if body == 131:
            render = read(folder / "efreet-prop-render-receipt.json")
            assert render["script_sha256"].keys() == PROP_SCRIPTS
            for name, pin in render["script_sha256"].items():
                assert digest(stage / "Viewer/Presentation" / name) == pin
            assert render["poses"] == 20 and render["minimum_foreground_box_pixels"] > 500
            assert set(render["heights"]) == {str(group) for group in slots}
            arrival = render["heights"]["23"]
            assert arrival[0][0] < .01 and arrival[0][1:] == [True, False]
            assert arrival[2][1:] == [True, True]
            assert arrival[-1][0] > .50 and arrival[-1][1:] == [False, True]
        else:
            render = read(folder / "motion-render-receipt.json")["152"]
            assert render["poses"] == 50 and render["minimum_foreground_box_pixels"] >= 11000
            assert set(render["clips"]) == set(clips)
            measured = read(folder / "avenger-pincer-receipt.json")
            assert measured["sample_rate"] == 240 and measured["treatments"].keys() == motion["hashes"].keys()
            for treatment, measurement in measured["treatments"].items():
                assert measurement["scene_sha256"] == motion["hashes"][treatment]
                assert measurement["clips"].keys() == set(clips)
                assert sum(clip["samples"] for clip in measurement["clips"].values()) == 1249
                for clip in measurement["clips"].values():
                    assert .0004 <= clip["floor_gap"] <= clip["maximum_gap"] <= .017
                    assert clip["core_crossings"] == 0 and clip["pincer_centreline_separation"] > .03
        assert render["scene_sha256"] == motion["hashes"]["modern"]
        assets = {name: folder / f"{body}-{name}.scn" for name in sorted(motion["hashes"])}
        rows[str(body)], local = common["fitted_row"](root / "Viewer", body, groups[body], clips, assets, motion["hashes"])
        copies.update(local)
    return rows, copies, verify_native(root, stage, folder, groups, terrain, common)


def verify_native(root, stage, folder, groups, terrain, common):
    read, digest = common["read"], common["sha"]
    native_dir = root / "work/creatures/native-efreet-terathan-avenger-enhanced"
    path = native_dir / "efreet-terathan-avenger-native.json"
    native, runtime = read(path), read(native_dir / "efreet-terathan-avenger-native-runtime.json")
    fixture = native_dir / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert digest(file) == runtime[f"{key}_sha256"].lower()
    assert digest(native_dir / "NativeEfreetAvengerLive.gd") == native["test_sha256"]
    assert digest(folder / TEST) == native["inputs_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["records"].keys() == FORMS.keys() and native["checks"] >= 200
    for form, record in native["records"].items():
        name, body, corpse_hue, renderer = FORMS[form]
        assert digest(stage / "Viewer/Presentation" / renderer) == native["renderers"][str(body)]
        assert (record["class"], record["hue"], record["stock_weapon"], record["ai"]) == (name, 0, "Fists", "MageAI")
        assert record["can_move"] and not (record["tamable"] or record["can_swim"] or record["can_fly"])
        assert len(record["step_delta"]) == 2 and max(map(abs, record["step_delta"])) == 1
        assert record["corpse"] >= 0x40000000 and (record["corpse_body"], record["corpse_hue"]) == (body, corpse_hue)
        combat, loot = record["combat"], record["carved"]
        assert loot["gold"] > 0 and combat["target"] > 0
        if body == 131:
            assert loot["ribs"] == 0 and combat["damage"] > 0 and 1 <= combat["cast_attempts"] <= 4
        else:
            assert loot["ribs"] == 2 and combat["clip"]
            packet, poison = combat["packet"], combat["poison"]
            assert (packet["protocol"], packet["body"], packet["serial"]) == ("classic", body, record["serial"])
            assert packet["action"] in (4, 5, 6)
            assert poison["target"] == combat["target"] and poison["damage"] > 0 and poison["deadly"]
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
