# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the AntLion's official references and local fitted presentation."""

import runpy


BODY = 787
MEMBER = "0xf64feeee4faf54cb"
SPRITES = {
    1: ("AntLionCombatWatch", 60, "42ba77edabe8707a6f76ae7d194e79946b5552ae7a89fbf6220ce09d797f5cb6"),
    11: ("AntLionPincerFeint", 50, "8ecabda9d731b0e717655cd0ad0dc5fef91ef8688c93c1acf79dee33769a711e"),
    12: ("AntLionPincerCross", 50, "3701fd55e7e7836b71960f8276ea4df0ceaeeab29318d3d9eaa268de6d8b956f"),
    15: ("AntLionWard", 40, "f4dce46b32c59f6da214f63abef9241548b08bd802edb4ca2ecb22e6eedc34d8"),
    23: ("AntLionBurrowRise", 45, "55167b451a46d5f7631677c29b98f338add2bf3272f216c7590501c8c8d2550b"),
    25: ("AntLionQuietWatch", 55, "9e24b1c5825aaeb82da6cc21eadc41e401b1166a876ed2c28653b32ca2750c4b"),
    27: ("AntLionHighClaws", 55, "8ea503b2a054762ff87283d2574e521affefdfae903ae933c2b226615125f971"),
    28: ("AntLionSweep", 50, "57c2f1d763d3f8e6984549a871a7606cfff86b0eaf2e71f4fdbcf6039e0a8fe0"),
}
TYPES = (2, 5, 8, 11, 14, 15)
RENDERER = "SourceEnhancedAntLionVisual.gd"
FOLDER = "work/creatures/native-form-audit/enhanced-source-gaps/antlion-enhanced"


def prepare_antlion(root, source, common, staged=None):
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
    assert render["clips"] == clips and render["poses"] == 80 and render["minimum_foreground_box_pixels"] > 9300
    assert render["scene_sha256"] == runtime["hashes"]["modern"]
    dense = read(folder / "dense-clearance-receipt.json")
    assert dense["sample_rate"] == 240 and dense["treatments"].keys() == runtime["hashes"].keys()
    for treatment, measured in dense["treatments"].items():
        assert measured["scene_sha256"] == runtime["hashes"][treatment] and measured["clips"].keys() == set(clips)
        assert sum(clip["samples"] for clip in measured["clips"].values()) == 1742
        assert all(clip["crossings"] == 0 and clip["maximum_supported_foot_gap"] < .041
                   for clip in measured["clips"].values())
    assets = {name: folder / f"{BODY}-{name}.scn" for name in runtime["hashes"]}
    row, copies = common["fitted_row"](root / "Viewer", BODY, routes, clips, assets, runtime["hashes"])
    return {str(BODY): row}, copies, verify_native(root, stage, routes, runtime["hashes"]["modern"], read, sha)


def verify_native(root, stage, routes, asset, read, sha):
    folder = root / "work/creatures/native-antlion-enhanced"
    path = folder / "antlion-native.json"
    native, engine = read(path), read(folder / "antlion-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert sha(file) == engine[f"{key}_sha256"].lower()
    assert sha(folder / "NativeAntLionLive.gd") == native["test_sha256"]
    assert sha(root / FOLDER / "test-antlion-enhanced.gd") == native["inputs_sha256"]
    assert sha(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["renderers"] == {str(BODY): sha(stage / "Viewer/Presentation" / RENDERER)}
    assert native["checks"] >= 175 and native["records"].keys() == {"antlion"}
    record = native["records"]["antlion"]
    assert (record["class"], record["corpse_body"], record["hue"], record["corpse_hue"]) == ("AntLion", BODY, 0, 0x8035)
    assert record["ai"] == "MeleeAI" and record["stock_weapon"] == "Fists" and record["can_move"]
    assert not record["can_swim"] and max(map(abs, record["step_delta"])) == 1
    assert record["corpse"] >= 0x40000000
    combat, loot = record["combat"], record["carved"]
    assert combat["damage"] > 0 and combat["packet"]["protocol"] == "classic" and combat["packet"]["body"] == BODY
    assert loot["bones"] == 3 and 1 <= loot["fertile_dirt"] <= 5 and 1 <= loot["ore"] <= 10 and loot["ore_id"] == 0x19B9
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
