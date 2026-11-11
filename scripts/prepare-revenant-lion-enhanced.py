# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the Revenant Lion's official references and local fitted presentation."""

import runpy


BODY = 251
MEMBER = "0xc5ef80038f3963f7"
SPRITES = {
    4: ("RevenantLionPounce", 50, "d6552336adaaf11d88d84ed999e877359d56359a66d374bd038451bf99bb89fe"),
    15: ("RevenantLionShortSnarl", 30, "d0ca701267ec0f104f1f363e3d53e0635050f2fdb38d7f4c7d688d88d7cdb6a3"),
    23: ("RevenantLionRise", 35, "463b4f02bed93ba274e245bc59f172d656968be38115104984bf28c1448607a5"),
    25: ("RevenantLionQuietStand", 50, "22a59379c9acc9f44d531e21a395b58a4ef490125d4039052d066f92767a4b41"),
    26: ("RevenantLionScentDip", 65, "b07a21fa906d02c4b7b8c7f4575cd9de51974deb7b1352d6d6439540042fe92d"),
    27: ("RevenantLionChallenge", 55, "28dc2a533fbd943822f67791810a324cdfaf46c42fc2f95702a1fc8cbd4d8351"),
    28: ("RevenantLionLowGuard", 30, "9358e35aa0c05002b176877542219289c2fee350a4c14207b65227fa8b667326"),
}
TYPES = (2, 5, 8, 11, 14, 15)
RENDERER = "SourceEnhancedRevenantLionVisual.gd"
FOLDER = "work/creatures/native-form-audit/enhanced-source-gaps/revenant-lion-enhanced"


def prepare_revenant_lion(root, source, common, staged=None):
    read, sha = common["read"], common["sha"]
    stage = staged or root
    folder = root / FOLDER
    routes = common["source_tables"](root, source, {BODY: SPRITES}, TYPES, member_hashes={BODY: MEMBER})[BODY]
    inspect = runpy.run_path(str(root / "scripts/uo-human-sequences.py"))["inspect"]
    named, = (row for row in inspect(source / "AnimationSequence.uop", {BODY}) if row["uop_name_hash"] == MEMBER)
    assert named["modes"][1]["movement"][0] == {"action": 0, "one_handed_group": 25, "two_handed_group": 25}
    clips = [row[0] for row in SPRITES.values()]
    runtime = read(folder / "runtime-receipt.json")
    assert tuple(runtime[key] for key in ("poses", "falls", "routes", "classic", "gaits")) == (3255, 210, 144, 108, 18)
    assert runtime["gap"] >= .0029 and runtime["fall_gap"] >= .0019 and runtime["handoff"] < .002
    render = read(folder / "motion-render-receipt.json")[str(BODY)]
    assert render["clips"] == clips and render["poses"] == 70 and render["minimum_foreground_box_pixels"] > 11000
    assert render["scene_sha256"] == runtime["hashes"]["modern"]
    dense = read(folder / "dense-clearance-receipt.json")
    assert dense["sample_rate"] == 240 and dense["treatments"].keys() == runtime["hashes"].keys()
    for treatment, measured in dense["treatments"].items():
        assert measured["scene_sha256"] == runtime["hashes"][treatment] and measured["clips"].keys() == set(clips)
        assert sum(clip["samples"] for clip in measured["clips"].values()) == 1543
        assert all(clip["crossings"] == 0 and clip["maximum_supported_foot_gap"] < .004
                   for clip in measured["clips"].values())
    assets = {name: folder / f"{BODY}-{name}.scn" for name in runtime["hashes"]}
    row, copies = common["fitted_row"](root / "Viewer", BODY, routes, clips, assets, runtime["hashes"])
    return {str(BODY): row}, copies, verify_native(root, stage, routes, runtime["hashes"]["modern"], read, sha)


def verify_native(root, stage, routes, asset, read, sha):
    folder = root / "work/creatures/native-revenant-lion-enhanced"
    path = folder / "revenant-lion-native.json"
    native, engine = read(path), read(folder / "revenant-lion-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert sha(file) == engine[f"{key}_sha256"].lower()
    assert sha(folder / "NativeRevenantLionLive.gd") == native["test_sha256"]
    assert sha(root / FOLDER / "test-revenant-lion-enhanced.gd") == native["inputs_sha256"]
    assert sha(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["renderers"] == {str(BODY): sha(stage / "Viewer/Presentation" / RENDERER)}
    assert native["checks"] >= 195 and native["records"].keys() == {"revenant-lion"}
    record = native["records"]["revenant-lion"]
    assert (record["class"], record["corpse_body"], record["hue"], record["corpse_hue"]) == ("RevenantLion", BODY, 0, 0x8035)
    assert record["ai"] == "MageAI" and record["stock_weapon"] == "Fists" and record["can_move"]
    assert record["greater_poison_immune"] and record["bleed_immune"] and record["bleed"]
    assert not record["can_fly"] and not record["can_swim"] and not record["tamable"]
    assert record["corpse"] >= 0x40000000 and max(map(abs, record["step_delta"])) == 1
    combat, loot = record["combat"], record["carved"]
    assert combat["damage"] > 0 and combat["greater_poison"] and combat["bleeding"]
    assert combat["packet"]["protocol"] == "classic" and combat["packet"]["body"] == BODY
    assert 6 <= loot["reagents"] <= 8 and loot["gold"] > 0 and loot["bone_parts"] == 1
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
