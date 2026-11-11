# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the Gore Fiend's official references and local fitted presentation."""

import runpy


BODY = 305
MEMBER = "0x68d63e7167db3a74"
SPRITES = {
    11: ("GoreFiendLowFeint", 45, "249f4ec3f866c9cfe675e83895926f9ae7d000e9609830938626003686508d54"),
    12: ("GoreFiendRaisedClaws", 60, "23620d5fea49e8cd1c903084c5109ca204eb8a70657a01952929221b6d2f49c3"),
    15: ("GoreFiendCurlGuard", 40, "92715552a1544d83f9bf630b10ccf54bf47756eee3c1bef4b4359d0cdca9a901"),
    23: ("GoreFiendUncoil", 35, "22c11e19c8dcf3ee5056a08384c7f78554c432e88b1a9781ffb1f81edccd918b"),
    25: ("GoreFiendQuietHunch", 45, "477546e16aeb64b470a43aba7465dd596b17da27b9b56d353d8cf192f9294d5b"),
    26: ("GoreFiendScentDip", 65, "6ac6dbff58dff4c252d51274d214fadecb03b9e19311ecb9728cae4e6d0dd276"),
    27: ("GoreFiendNeckThreat", 50, "11a107c8552e51ba7d1c13976e3f222c8f36b70d5776204373614eb333c667bd"),
    28: ("GoreFiendLowReach", 50, "53c787c2e981fa3f6dc943ea36f629648c9b6325daefaac0b3589e0db8c0ee3b"),
}
TYPES = (2, 5, 8, 11, 14, 15)
RENDERER = "SourceEnhancedGoreFiendVisual.gd"
FOLDER = "work/creatures/native-form-audit/enhanced-source-gaps/gore-fiend-enhanced"


def prepare_gore_fiend(root, source, common, staged=None):
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
    assert render["clips"] == clips and render["poses"] == 80 and render["minimum_foreground_box_pixels"] > 10400
    assert render["scene_sha256"] == runtime["hashes"]["modern"]
    dense = read(folder / "dense-clearance-receipt.json")
    assert dense["sample_rate"] == 240 and dense["treatments"].keys() == runtime["hashes"].keys()
    for treatment, measured in dense["treatments"].items():
        assert measured["scene_sha256"] == runtime["hashes"][treatment] and measured["clips"].keys() == set(clips)
        assert sum(clip["samples"] for clip in measured["clips"].values()) == 1783
        assert all(clip["crossings"] == 0 and clip["maximum_supported_foot_gap"] < .016
                   for clip in measured["clips"].values())
    assets = {name: folder / f"{BODY}-{name}.scn" for name in runtime["hashes"]}
    row, copies = common["fitted_row"](root / "Viewer", BODY, routes, clips, assets, runtime["hashes"])
    return {str(BODY): row}, copies, verify_native(root, stage, routes, runtime["hashes"]["modern"], read, sha)


def verify_native(root, stage, routes, asset, read, sha):
    folder = root / "work/creatures/native-gore-fiend-enhanced"
    path = folder / "gore-fiend-native.json"
    native, engine = read(path), read(folder / "gore-fiend-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert sha(file) == engine[f"{key}_sha256"].lower()
    assert sha(folder / "NativeGoreFiendLive.gd") == native["test_sha256"]
    assert sha(root / FOLDER / "test-gore-fiend-enhanced.gd") == native["inputs_sha256"]
    assert sha(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["renderers"] == {str(BODY): sha(stage / "Viewer/Presentation" / RENDERER)}
    assert native["checks"] >= 180 and native["records"].keys() == {"gore-fiend"}
    record = native["records"]["gore-fiend"]
    assert (record["class"], record["corpse_body"], record["hue"], record["corpse_hue"]) == ("GoreFiend", BODY, 0, 0x8035)
    assert record["ai"] == "MeleeAI" and record["stock_weapon"] == "Fists" and record["can_move"]
    assert not record["can_swim"] and max(map(abs, record["step_delta"])) == 1
    assert record["corpse"] >= 0x40000000 and record["bleed_immune"] and record["bleed_control"]
    combat = record["combat"]
    assert combat["damage"] > 0 and combat["packet"]["protocol"] == "classic" and combat["packet"]["body"] == BODY
    assert record["carved"]["gold"] > 0
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
