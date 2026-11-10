# SPDX-License-Identifier: GPL-3.0-or-later
"""Seal the fitted Skittering Hopper and Fan Dancer from local evidence."""

MEMBERS = {302: "0xefaf05f899af4ab4", 247: "0x3c257b9a3e1c72a1"}
SPRITES = {
    302: {
        12: ("HopperWingSignal", 55, "b2a9041ebb0aef62acf14c494c97675eebeec274e99c7bb08d4bca08edf8b284"),
        23: ("HopperUnfurl", 50, "c45f5c311fd2ff3add6614c67623172d27ff8e523f7ceb187baa7cf13298de32"),
        26: ("HopperSettledWingWatch", 55, "99f150fc278304c2434d6246106bf96c1a15f5fd9d1aad4c72168360aafc2cf8"),
        27: ("HopperRaisedWingBrace", 55, "ee04d55ec86be3b3c00f35e8ae2d651710b8653a03fd63b467f018b4357f8e55"),
        28: ("HopperWingAlert", 40, "1e81f3ef7a4ed34f3a7b6cae07a0b8c928bb77fd3b3b2d18d6009b5b8062fb94"),
    },
    247: {
        4: ("FanDancerSteppingSweep", 45, "baa235a09dc4b17615f125d1ed8120463e3b461a01655fc191203ff3d8747422"),
        23: ("FanDancerTurningRise", 60, "fe27feb167d53c04b3ccd0403821ab0737f87cc7b04ebd7b8edb5d11c7139dd3"),
        26: ("FanDancerFanScreen", 55, "53068fa2fe738152f30d645163937ec724d14997b1905d91eebe79a914efcaff"),
        27: ("FanDancerRearStepFlourish", 55, "bb0d2fb72241dcb1ea517037601e87401baf3d78a91735cc8ac28a3122a1a9f9"),
        28: ("FanDancerCrossedAlert", 55, "339771bd26baf5400bbcf7f4145b153e86fa54b8dc1ef0d68449e1efb6db3d3f"),
    },
}
TYPES = (5, 8, 11, 15)
TREATMENTS = {"original", "rounded", "modern"}
TEST = "test-hopper-fan-enhanced.gd"
FORMS = {
    "hopper": ("SkitteringHopper", 302, 0x8035, "Fists", "SourceEnhancedHopperVisual.gd"),
    "fan": ("FanDancer", 247, 0x455, "Tessen", "SourceEnhancedFanDancerVisual.gd"),
}


def prepare_hopper_fan(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    stage = staged or root
    work = root / "work/creatures"
    folder = work / "native-form-audit/enhanced-source-gaps/skittering-hopper-fan-dancer"
    receipt = read(folder / "terrain-receipt.json")
    assert digest(stage / "scripts" / TEST) == digest(folder / TEST) == receipt["test_sha256"]
    terrain = receipt["bodies"]
    rendered = read(folder / "motion-render-receipt.json")
    assert terrain.keys() == rendered.keys() == {str(body) for body in SPRITES}
    groups = common["source_tables"](root, source, SPRITES, TYPES, member_hashes=MEMBERS)
    rows, copies = {}, {}
    for body, slots in SPRITES.items():
        clips = [clip for clip, _, _ in slots.values()]
        motion, render = terrain[str(body)], rendered[str(body)]
        assert (motion["poses"], motion["falls"], motion["routes"], motion["classic"]) == (2325, 150, 96, 72)
        assert min(motion["gap"], motion["fall_gap"]) >= .0018 and motion["jump"] < .002
        assert render["scene_sha256"] == motion["hashes"]["modern"] and motion["hashes"].keys() == TREATMENTS
        assert render["poses"] == 50 and set(render["clips"]) == set(clips)
        assert render["minimum_foreground_box_pixels"] >= 6000
        assets = {name: folder / f"{body}-{name}.scn" for name in sorted(TREATMENTS)}
        rows[str(body)], local = common["fitted_row"](root / "Viewer", body, groups[body], clips, assets, motion["hashes"])
        copies.update(local)
    return rows, copies, verify_native(root, stage, work, folder, groups, terrain, common)


def verify_native(root, stage, work, folder, groups, terrain, common):
    read, digest = common["read"], common["sha"]
    native_dir = work / "native-hopper-fan-enhanced"
    path = native_dir / "hopper-fan-native.json"
    native, runtime = read(path), read(native_dir / "hopper-fan-native-runtime.json")
    fixture = native_dir / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert digest(file) == runtime[f"{key}_sha256"].lower()
    assert digest(native_dir / "NativeHopperFanLive.gd") == native["test_sha256"]
    assert digest(folder / TEST) == native["inputs_sha256"]
    presentation = stage / "Viewer/Presentation"
    assert digest(presentation / "SourceEnhancedHopperWing.gdshader") == native["wing_shader_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["records"].keys() == FORMS.keys() and native["checks"] == 224
    for form, record in native["records"].items():
        name, body, hue, weapon, renderer = FORMS[form]
        assert digest(presentation / renderer) == native["renderers"][str(body)]
        assert (record["class"], record["hue"], record["stock_weapon"], record["ai"]) == (name, 0, weapon, "MeleeAI")
        assert record["can_move"] and not record["can_swim"] and not record["can_fly"]
        assert record["tamable"] == (form == "hopper")
        assert len(record["step_delta"]) == 2 and max(map(abs, record["step_delta"])) == 1
        assert record["corpse"] >= 0x40000000 and (record["corpse_body"], record["corpse_hue"]) == (body, hue)
        assert record["carved"]["gold"] > 0
        combat, abilities = record["combat"], record["abilities"]
        packet = combat["packet"]
        assert (packet["protocol"], packet["body"], packet["serial"]) == ("classic", body, record["serial"])
        assert packet["action"] in (4, 5, 6) and combat["clip"]
        if form == "hopper":
            assert not abilities and combat["mode"] == "autonomous" and not combat["passive_consumed_stock_swing"]
        else:
            assert record["carved"]["tessen"] in (0x27A3, 0x27EE)
            assert combat["mode"] == "controlled_stock_animation" and combat["passive_consumed_stock_swing"]
            assert abilities.keys() == {"fire", "throw"} and all(effect["damage"] > 0 for effect in abilities.values())
            assert (abilities["fire"]["resistance"], abilities["fire"]["packet"]["graphic"]) == (-10, 0x3709)
            assert (abilities["throw"]["packet"]["source"], abilities["throw"]["packet"]["graphic"]) == (0, 0x27A3)
        phase, = record["phases"]
        assert phase["body"] == body and phase["asset_sha256"] == terrain[str(body)]["hashes"]["modern"]
        cases = phase["cases"]
        expected = {(flag, kind, variation) for flag in (0, 64) for kind in TYPES for variation in (0, 1, 255)}
        assert len(cases) == len(expected) and {(c["flags"], c["type"], c["variation"]) for c in cases} == expected
        for case in cases:
            mode = "0" if case["flags"] & 64 else "1"
            kind, variation = str(case["type"]), case["variation"]
            choices = groups[body][mode].get(kind, groups[body]["0"][kind])
            assert case["enhanced"] == (choices[variation % len(choices)] if variation <= 127 else case["classic"])
    return digest(path)
