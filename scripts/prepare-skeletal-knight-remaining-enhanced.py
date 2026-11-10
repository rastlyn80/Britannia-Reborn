# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the completed Skeletal Knight fitting against its pinned reference groups."""

BODY = 147
MEMBERS = {BODY: "0xef8c3adcc94babf"}
SPRITES = {
    23: ("SkeletalKnightShieldRise", 45, "e62847437d65438f473f28ce52fd6b261a66117d8d002fbb76f1797fd95b3f45"),
    28: ("SkeletalKnightSwordAlert", 25, "516046a20ab7694633f09b860a566c2d57895947ede70463f352daa34d64a035"),
    4: ("SkeletalKnightOverheadSweep", 40, "91f5e4636bd315d634fc7d596dac09622c2ceab83455ea44a6dee50e09285032"),
    11: ("SkeletalKnightLowBrace", 65, "10db8491bb099e088668cbe3712533b1f3904ad09d2fa9803e4007580f2097a5"),
    15: ("SkeletalKnightShieldFlinch", 25, "8c00ba0626480c10093a73bcaf1a2575b65c6287f479b851a1c3148fcbff2f5b"),
    26: ("SkeletalKnightBladeCheck", 65, "86a49d84ff2a6487fdd3658bee201b5ad76728a752a421f5a0b601cdd8fd1537"),
    27: ("SkeletalKnightWideStagger", 50, "29a7a9019f68669d4ae4b85175699c4bd842b240db1997349123010cb9c141aa"),
}
TYPES = (2, 5, 8, 11, 14, 15)
TREATMENTS = ("original", "rounded", "modern")
TEST = "test-skeletal-knight-remaining.gd"


def prepare_skeletal_knight_remaining(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    stage = staged or root
    work = root / "work/creatures"
    scenes = work / "native-form-audit/enhanced-source-gaps/bone-knight-acid-elemental/remaining-groups"
    groups = common["source_tables"](root, source, {BODY: SPRITES}, TYPES, member_hashes=MEMBERS)[BODY]
    receipt = read(scenes / "fitted-runtime-receipt.json")
    assert digest(scenes / TEST) == receipt["test_sha256"] == digest(stage / "scripts/test-skeletal-knight-remaining-enhanced.gd")
    assert (receipt["terrain"], receipt["falls"], receipt["routes"], receipt["classic"]) == (3255, 315, 144, 108)
    assert receipt["minimum_gap"] >= .0019 and receipt["prop_gap"] >= .0019 and receipt["maximum_jump"] < .002
    hashes = receipt["hashes"]
    assert hashes.keys() == set(TREATMENTS)
    rendered = read(scenes / "motion-render-receipt.json")[str(BODY)]
    fresh = {value[0] for group, value in SPRITES.items() if group not in (23, 28)}
    assert rendered["scene_sha256"] == hashes["modern"] and set(rendered["clips"]) == fresh
    assert rendered["poses"] == 50 and rendered["minimum_foreground_box_pixels"] >= 3000
    verify_props(read(scenes / "fitted-prop-receipt.json"), hashes, fresh)
    assets = {name: scenes / f"{BODY}-{name}.scn" for name in TREATMENTS}
    row, copies = common["fitted_row"](root / "Viewer", BODY, groups, [value[0] for value in SPRITES.values()], assets, hashes)
    return {str(BODY): row}, copies, verify_native(root, work, scenes, groups, hashes["modern"], common)


def verify_props(receipt, hashes, clips):
    assert receipt["failures"] == 0 and receipt["treatments"].keys() == hashes.keys()
    for name, treatment in receipt["treatments"].items():
        assert treatment["scene_sha256"] == hashes[name] and treatment["clips"].keys() == clips
        assert sum(clip["samples"] for clip in treatment["clips"].values()) == 2206
        for clip in treatment["clips"].values():
            assert clip["floor"] >= .001 and clip["grip_error"] <= .00001 and clip["tip_step"] <= .055
            assert not (clip["body_crossings"] or clip["prop_crossings"])


def verify_native(root, work, scenes, groups, modern, common):
    read, digest = common["read"], common["sha"]
    folder = work / "native-skeletal-knight-remaining-enhanced"
    path = folder / "skeletal-knight-remaining-native.json"
    native = read(path)
    runtime = read(folder / "skeletal-knight-remaining-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert digest(file) == runtime[f"{key}_sha256"].lower()
    assert digest(folder / "NativeSkeletalKnightRemainingLive.gd") == native["test_sha256"]
    assert digest(scenes / TEST) == native["inputs_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert digest(root / "Viewer/Presentation/SourceEnhancedSkeletalMageVisual.gd") == native["renderers"]["knight"]
    assert native["records"].keys() == {"knight"} and native["checks"] >= 140
    record = native["records"]["knight"]
    assert (record["class"], record["hue"], record["stock_weapon"]) == ("SkeletalKnight", 0, "Fists")
    assert record["can_move"] and not record["can_swim"] and not record["tamable"]
    assert len(record["step_delta"]) == 2 and max(map(abs, record["step_delta"])) == 1
    assert record["corpse"] >= 0x40000000 and (record["corpse_body"], record["corpse_hue"]) == (BODY, 0x8035)
    assert record["loot"] == {"sword": True, "shield": True}
    swing = record["swing"]
    packet = swing["packet"]
    assert (packet["protocol"], packet["body"], packet["serial"]) == ("classic", BODY, record["serial"])
    assert packet["action"] in (4, 5, 6) and swing["clip"]
    phase, = record["phases"]
    assert phase["body"] == BODY and phase["asset_sha256"] == modern
    cases = phase["cases"]
    expected = {(flags, kind, variation) for flags in (0, 64) for kind in TYPES for variation in (0, 1, 255)}
    assert len(cases) == len(expected) and {(case["flags"], case["type"], case["variation"]) for case in cases} == expected
    for case in cases:
        mode = "0" if case["flags"] else "1"
        kind, variation = str(case["type"]), case["variation"]
        choices = groups[mode].get(kind, groups["0"][kind])
        assert case["enhanced"] == (choices[variation % len(choices)] if variation <= 127 else case["classic"])
    return digest(path)
