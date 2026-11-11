# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the Frost Spider's official references and local fitted presentation."""

import runpy


BODY = 20
MEMBER = "0x41b6bd075a5204d7"
SPRITES = {
    11: ("FrostSpiderClawProbe", 45, "293495457186ad15d3870f104377eb1d4198cbf29df5baabd42ad8ed09798557"),
    12: ("FrostSpiderAbdomenRise", 50, "c11cc873468315449e83f63b4659913ec5dc7a8f9bed61f52d2f2852f4138a5b"),
    15: ("FrostSpiderHighDefence", 40, "ddec4b497fb3f95d7d00bea8fac4b90094cab1ea253fb904831da012f280b612"),
    23: ("FrostSpiderUnfold", 45, "f501e7cd6af41d5a7a97edb003d22d856fcd73c2b2b106504ffb71eb57c860be"),
    25: ("FrostSpiderQuietRest", 45, "1ba523aacc1aecc8427199c84f074140d1655e03612a0d7c66f18b9277026254"),
    26: ("FrostSpiderSilkCheck", 50, "08ebc5547fc21e4ad0e857209cf6436953919a3caa224c0d68df3dee0e72c83c"),
    27: ("FrostSpiderRockingSignal", 50, "6647ced91f16e6d05eeed72ed8032d0e0d7231207ef37bdf53d7a1e326d3154a"),
    28: ("FrostSpiderGather", 40, "6f8296a548f68e241c589c320b1f7f0f78d49bd3d5fe766d3ae316e7f36d993e"),
}
TYPES = (2, 5, 8, 11, 14, 15)
RENDERER = "SourceEnhancedFrostSpiderVisual.gd"
FOLDER = "work/creatures/native-form-audit/enhanced-source-gaps/frost-spider-enhanced"


def prepare_frost_spider(root, source, common, staged=None):
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
    assert render["clips"] == clips and render["poses"] == 80 and render["minimum_foreground_box_pixels"] > 4900
    assert render["scene_sha256"] == runtime["hashes"]["modern"]
    dense = read(folder / "dense-clearance-receipt.json")
    assert dense["sample_rate"] == 240 and dense["treatments"].keys() == runtime["hashes"].keys()
    for treatment, measured in dense["treatments"].items():
        assert measured["scene_sha256"] == runtime["hashes"][treatment] and measured["clips"].keys() == set(clips)
        assert sum(clip["samples"] for clip in measured["clips"].values()) == 1787
        assert all(clip["minimum_floor_gap"] > .0035 and clip["minimum_tip_separation"] > .28
                   for clip in measured["clips"].values())
        planted = {name for name, clip in measured["clips"].items() if clip["rear_stance_measured"]}
        assert planted == set(clips) - {"FrostSpiderUnfold", "FrostSpiderGather"}
        assert all(measured["clips"][name]["maximum_rear_foot_drift"] < .0006 for name in planted)
        assert measured["clips"]["FrostSpiderHighDefence"]["maximum_foreleg_lift"] > .75
    assets = {name: folder / f"{BODY}-{name}.scn" for name in runtime["hashes"]}
    row, copies = common["fitted_row"](root / "Viewer", BODY, routes, clips, assets, runtime["hashes"])
    return {str(BODY): row}, copies, verify_native(root, stage, routes, runtime["hashes"]["modern"], read, sha)


def verify_native(root, stage, routes, asset, read, sha):
    folder = root / "work/creatures/native-frost-spider-enhanced"
    path = folder / "frost-spider-native.json"
    native, engine = read(path), read(folder / "frost-spider-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert sha(file) == engine[f"{key}_sha256"].lower()
    assert sha(folder / "NativeFrostSpiderLive.gd") == native["test_sha256"]
    assert sha(root / FOLDER / "test-frost-spider-enhanced.gd") == native["inputs_sha256"]
    assert sha(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["renderers"] == {str(BODY): sha(stage / "Viewer/Presentation" / RENDERER)}
    assert native["checks"] >= 180 and native["records"].keys() == {"frost-spider"}
    record = native["records"]["frost-spider"]
    assert (record["class"], record["corpse_body"], record["hue"], record["corpse_hue"]) == ("FrostSpider", BODY, 0, 0x8035)
    assert record["ai"] == "MeleeAI" and record["stock_weapon"] == "Fists" and record["can_move"]
    assert not record["can_swim"] and max(map(abs, record["step_delta"])) == 1
    assert record["corpse"] >= 0x40000000 and record["tamable"]
    combat = record["combat"]
    assert combat["damage"] > 0 and combat["packet"]["protocol"] == "classic" and combat["packet"]["body"] == BODY
    assert record["carved"]["gold"] > 0 and record["carved"]["spiders_silk"] == 7
    tame = record["taming"]
    assert tame["serial"] != record["serial"] and 1 <= tame["attempts"] <= 3
    assert (tame["skill"], tame["minimum_skill"], tame["control_slots"], tame["cold_damage_percent"], tame["order"]) == (
        120.0, 74.7, 1, 80, "Follow"
    )
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
