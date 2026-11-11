# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the Shadow Fiend's official references and local fitted presentation."""

import runpy


BODY = 168
MEMBER = "0xaf4b33c0941b7fc0"
SPRITES = {
    11: ("ShadowFiendShoulderFeint", 40, "5a5939de1615854e0b23efc5902c9bd507f900fa62596df8405663a5d7773200"),
    12: ("ShadowFiendRaisedClaws", 40, "31f2672fe6096ed80a0a378f41f1ae330182dc2c1b899fecb8bd491adcbf7581"),
    15: ("ShadowFiendHighWard", 30, "507c3c13b33223557386ef100efdbd1001b07222d5ee3ba91cbceb22767251b4"),
    23: ("ShadowFiendManifest", 40, "01057dcc8ace0a65f67944341515f5775df38d0dc84d9fcd973580830aedee7d"),
    25: ("ShadowFiendQuietStand", 60, "49b984773cc818ab2f89d9aefb772af79236090c41a48c9fdd020c3c1403bc56"),
    26: ("ShadowFiendScentTurn", 55, "cc2c4722ac6ee708950c902dfbd6f03edbbc931d3861eeeae5168ddca08b8963"),
    27: ("ShadowFiendTwistedGuard", 45, "aa0ea400b39610e44cf25ff24875055586ae7b4fb46387c08c51f71d304b7770"),
    28: ("ShadowFiendOpenGuard", 25, "b6bbf1e4adbe3ca6ec806181ae15ab4e0a944f11e644c0fcee19bc8a3de2c2d1"),
}
TYPES = (2, 5, 8, 11, 14, 15)
RENDERER = "SourceEnhancedShadowFiendVisual.gd"
FOLDER = "work/creatures/native-form-audit/enhanced-source-gaps/shadow-fiend-enhanced"


def prepare_shadow_fiend(root, source, common, staged=None):
    read, sha = common["read"], common["sha"]
    stage = staged or root
    folder = root / FOLDER
    routed = {group: entry for group, entry in SPRITES.items() if group != 25}
    routes = common["source_tables"](root, source, {BODY: routed}, TYPES, member_hashes={BODY: MEMBER})[BODY]
    _, frame_count, frame_sha = SPRITES[25]
    idle = source / f"ec-frame-{BODY}-25.bin"
    assert sha(idle) == frame_sha
    decode = runpy.run_path(str(root / "scripts/uo-enhanced-frames.py"))["read_amou"]
    identity, frames = decode(idle.read_bytes())
    assert identity == BODY and len(frames) == frame_count and all(frame.group == 25 for frame in frames)
    inspect = runpy.run_path(str(root / "scripts/uo-human-sequences.py"))["inspect"]
    named, = (row for row in inspect(source / "AnimationSequence.uop", {BODY}) if row["uop_name_hash"] == MEMBER)
    assert named["modes"][1]["movement"][0] == {"action": 0, "one_handed_group": 25, "two_handed_group": 25}
    clips = [row[0] for row in SPRITES.values()]
    runtime = read(folder / "runtime-receipt.json")
    assert tuple(runtime[key] for key in ("poses", "falls", "routes", "classic", "gaits")) == (3720, 240, 144, 108, 18)
    assert runtime["gap"] >= .0029 and runtime["fall_gap"] >= .0019 and runtime["handoff"] < .002
    render = read(folder / "motion-render-receipt.json")[str(BODY)]
    assert render["clips"] == clips and render["poses"] == 80 and render["minimum_foreground_box_pixels"] > 7900
    assert render["scene_sha256"] == runtime["hashes"]["modern"]
    dense = read(folder / "dense-clearance-receipt.json")
    assert dense["sample_rate"] == 240 and dense["treatments"].keys() == runtime["hashes"].keys()
    for treatment, measured in dense["treatments"].items():
        assert measured["scene_sha256"] == runtime["hashes"][treatment] and measured["clips"].keys() == set(clips)
        assert sum(clip["samples"] for clip in measured["clips"].values()) == 1743
        assert all(clip["crossings"] == 0 and clip["maximum_supported_foot_gap"] < .125
                   for clip in measured["clips"].values())
    assets = {name: folder / f"{BODY}-{name}.scn" for name in runtime["hashes"]}
    row, copies = common["fitted_row"](root / "Viewer", BODY, routes, clips, assets, runtime["hashes"])
    return {str(BODY): row}, copies, verify_native(root, stage, routes, runtime["hashes"]["modern"], read, sha)


def verify_native(root, stage, routes, asset, read, sha):
    folder = root / "work/creatures/native-shadow-fiend-enhanced"
    path = folder / "shadow-fiend-native.json"
    native, engine = read(path), read(folder / "shadow-fiend-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert sha(file) == engine[f"{key}_sha256"].lower()
    assert sha(folder / "NativeShadowFiendLive.gd") == native["test_sha256"]
    assert sha(root / FOLDER / "test-shadow-fiend-enhanced.gd") == native["inputs_sha256"]
    assert sha(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["renderers"] == {str(BODY): sha(stage / "Viewer/Presentation" / RENDERER)}
    assert native["checks"] >= 195 and native["records"].keys() == {"shadow-fiend"}
    record = native["records"]["shadow-fiend"]
    assert (record["class"], record["body"], record["hue"], record["dyed_hue"]) == ("ShadowFiend", BODY, 0, 0x8035)
    assert record["ai"] == "MeleeAI" and record["stock_weapon"] == "Fists" and record["can_move"]
    assert not record["can_swim"] and max(map(abs, record["step_delta"])) == 1
    first, second = record["death"]
    assert first == second and first["corpse"] >= 0x40000000 and first["effect"] == 0x376A and not first["persistent"]
    combat = record["combat"]
    assert combat["damage"] > 0 and combat["packet"]["protocol"] == "classic" and combat["packet"]["body"] == BODY
    phase, = record["phases"]
    assert phase["asset_sha256"] == asset
    expected = {(flags, kind, variant) for flags in (0, 64) for kind in TYPES for variant in (0, 1, 2, 255)}
    cases = phase["cases"]
    assert len(cases) == len(expected)
    assert {(row["flags"], row["type"], row["variation"]) for row in cases} == expected
    for case in cases:
        mode, kind, variant = ("0" if case["flags"] else "1"), str(case["type"]), case["variation"]
        choices = routes[mode].get(kind, routes["0"][kind])
        assert case["enhanced"] == (choices[variant % len(choices)] if variant <= 127 else case["classic"])
    return sha(path)
