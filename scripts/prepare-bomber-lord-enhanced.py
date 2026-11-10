# SPDX-License-Identifier: GPL-3.0-or-later
"""Pin the named Enhanced Orc Bomber and Ogre Lord sequences."""

MEMBERS = {182: '0xe2a9431f9abe3b85', 83: '0x345f12ca480cd4f1'}
SPRITES = {
    182: {
        4: ('OrcBomberCastAndDip', 35, '583a9c88f71b09f62c1c122661b659f92c2bec243ecc50aad0bc7c9f1beacb8e'),
        23: ('OrcBomberUnfold', 45, '87131e7315530becc3af8853f34ca11d477801e4636134b4031aa2e966152271'),
        26: ('OrcBomberPalmCheck', 40, '1e787b27fcdcfa4650ee6a9216a5dc4436aad1d5d2a3d5764341b2fde6a5cba7'),
        27: ('OrcBomberHighFeint', 60, 'c0a20fe9a7270935aed383ec3c1cb9c00ccdd105e1304336a8239a78416db5e6'),
        28: ('OrcBomberForwardGuard', 40, 'c0b06db7c01e080874d32ab675bb3438853638eb3374a9237953206ac1c19131'),
    },
    83: {
        4: ('OgreLordDownwardClub', 45, '6dd01a581df9c56ae0d55d9cc62327f8e1701016cebb51b43f65fb9599f325dd'),
        23: ('OgreLordCrouchRise', 35, 'b7381f840e904566de5286e9b383bc40e835aecc117ef231540e0c02bbdb8c2e'),
        26: ('OgreLordClubCheck', 65, 'bca9b46254b071ee483fee88e721259db8cdfcce28c897c2aac62911fe3e973d'),
        27: ('OgreLordOverheadGuard', 65, 'b051316d90b6c17e005b583295e341a2022563e85cbdfb5098ff2666e69a48e6'),
        28: ('OgreLordClubLift', 35, 'fe8d1c0dca7ec487290439b644cf1331f9097cbbb5abc8b3882ec3f819bceb19'),
    },
}

TYPES = (5, 8, 11, 15)
FORMS = {"bomber": ("OrcBomber", 182, 0x8035), "lord": ("OgreLord", 83, 0x455)}
RENDERERS = {182: "SourceEnhancedOrcBomberVisual.gd", 83: "SourceEnhancedOgreLordVisual.gd"}


def prepare_bomber_lord(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    stage = staged or root
    folder = root / "work/creatures/native-form-audit/enhanced-source-gaps/orc-bomber-ogre-lord"
    terrain = read(folder / "runtime-receipt.json")
    render = read(folder / "motion-render-receipt.json")
    dense = read(folder / "dense-clearance-receipt.json")
    assert dense["sample_rate"] == 240
    assert terrain.keys() == render.keys() == dense["bodies"].keys() == {str(body) for body in SPRITES}
    groups = common["source_tables"](root, source, SPRITES, TYPES, member_hashes=MEMBERS)
    rows, copies = {}, {}
    for body, slots in SPRITES.items():
        clips = [clip for clip, _, _ in slots.values()]
        key = str(body)
        motion, views, measurements = terrain[key], render[key], dense["bodies"][key]
        assert (motion["poses"], motion["falls"], motion["routes"], motion["classic"]) == (2325, 150, 96, 72)
        assert min(motion["gap"], motion["fall_gap"]) >= .0018 and motion["jump"] < .002
        assert motion["bomb_origins"] == (3 if body == 182 else 0)
        if body == 83:
            assert motion["club_ground"] >= .08 and motion["club_grip_error"] < .001
        assert views["poses"] == 50 and set(views["clips"]) == set(clips)
        assert views["scene_sha256"] == motion["hashes"]["modern"]
        assert views["minimum_foreground_box_pixels"] > (5800 if body == 182 else 8900)
        assert measurements.keys() == motion["hashes"].keys() == {"original", "rounded", "modern"}
        for treatment, measurement in measurements.items():
            assert measurement["scene_sha256"] == motion["hashes"][treatment]
            assert measurement["clips"].keys() == set(clips) and measurement["core_triangles"] > 0
            assert sum(clip["samples"] for clip in measurement["clips"].values()) == (1064 if body == 182 else 1172)
            for clip in measurement["clips"].values():
                assert clip["forearm_crossings"] == clip["club_crossings"] == 0
                if body == 83:
                    assert clip["palm_error"] < .001 and clip["club_floor"] >= .08
        assets = {name: folder / f"{body}-{name}.scn" for name in sorted(motion["hashes"])}
        rows[key], local = common["fitted_row"](root / "Viewer", body, groups[body], clips, assets, motion["hashes"])
        copies.update(local)
    return rows, copies, verify_native(root, stage, folder, groups, terrain, read, digest)


def verify_native(root, stage, folder, groups, terrain, read, digest):
    directory = root / "work/creatures/native-bomber-ogre-lord-enhanced"
    path = directory / "bomber-ogre-lord-native.json"
    native, runtime = read(path), read(directory / "bomber-ogre-lord-native-runtime.json")
    fixture = directory / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert digest(file) == runtime[f"{key}_sha256"].lower()
    assert digest(directory / "NativeBomberLordLive.gd") == native["test_sha256"]
    assert digest(folder / "test-bomber-lord-enhanced.gd") == native["inputs_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["checks"] >= 180 and native["records"].keys() == FORMS.keys()
    assert native["renderers"] == {str(body): digest(stage / "Viewer/Presentation" / name)
                                   for body, name in RENDERERS.items()}
    for form, (name, body, corpse_hue) in FORMS.items():
        record = native["records"][form]
        assert (record["class"], record["hue"], record["corpse_body"], record["corpse_hue"], record["ai"]) == (
            name, 0, body, corpse_hue, "MeleeAI")
        assert record["stock_weapon"] == "Fists" and record["can_move"]
        assert not (record["tamable"] or record["can_swim"] or record["can_fly"])
        assert max(map(abs, record["step_delta"])) == 1 and record["corpse"] >= 0x40000000
        combat, loot = record["combat"], record["carved"]
        assert loot["gold"] > 0 and combat["target"] > 0
        if body == 182:
            assert 0 < combat["damage"] <= 20 and loot["ash"] >= 6
            assert len(combat["effects"]) == 2
            for effect in combat["effects"]:
                assert (effect["source"], effect["target"], effect["graphic"]) == (record["serial"], combat["target"], 0x1c19)
                assert effect["kind"] == "moving" and effect["speed"] == 1 and effect["duration"] == 0 and effect["explodes"]
        else:
            packet = combat["packet"]
            assert (packet["protocol"], packet["body"], packet["serial"]) == ("classic", body, record["serial"])
            assert packet["action"] in (4, 5, 6) and combat["clip"]
            assert loot["clubs"] >= 1 and loot["ribs"] >= 2
        phase, = record["phases"]
        assert phase["asset_sha256"] == terrain[str(body)]["hashes"]["modern"]
        cases = phase["cases"]
        expected = {(flag, kind, var) for flag in (0, 64) for kind in TYPES for var in (0, 1, 2, 255)}
        assert len(cases) == len(expected) and {(c["flags"], c["type"], c["variation"]) for c in cases} == expected
        for case in cases:
            mode, kind, variant = ("0" if case["flags"] else "1"), str(case["type"]), case["variation"]
            choices = groups[body][mode].get(kind, groups[body]["0"][kind])
            assert case["enhanced"] == (choices[variant % len(choices)] if variant <= 127 else case["classic"])
    return digest(path)

