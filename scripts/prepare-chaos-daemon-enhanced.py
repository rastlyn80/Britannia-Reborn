# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the Chaos Daemon's official references and local fitted presentation."""

import runpy


BODY = 792
MEMBER = "0x6501ed1a3fab533a"
SPRITES = {
    11: ("ChaosDaemonLowHunch", 50, "6f16475619d02fc6da4ec865c8329208db3c4b57f8a9bcb6d93e2aaf022ab7f0"),
    12: ("ChaosDaemonClawInvocation", 55, "5e776cac83f1d63d94ce4ce93b3df4bcabd4b45775dd92c03d89bbebede64251"),
    15: ("ChaosDaemonHighGuard", 45, "b08b10686ada2337a697c55c3a3847c43e3fe924bfb3b294f38c2b1d033a287d"),
    23: ("ChaosDaemonCrouchingRise", 60, "79361b4644dcf58267a8de7e8b129039fedea572eee31a152278b7b0f3a16e95"),
    25: ("ChaosDaemonQuietBreath", 60, "f42814d0e8f19a08202732083b09565b21f8ebbcc709e9eb9014a183cc23365d"),
    26: ("ChaosDaemonWatch", 55, "f26200f728366383db2c6ea4d406e4f4bbea8ad1e0fadf660e89de9d250b42f7"),
    27: ("ChaosDaemonWideThreat", 50, "a589b27c15cd96ae686050f93544182734dde4e5bf0d5f3b7cbecc3603e3972a"),
    28: ("ChaosDaemonCombatSet", 55, "60d84dbca828d1d5b03a7c0979afd958c9c3ad240c58905163129e023f108f71"),
}
TYPES = (2, 5, 8, 11, 14, 15)
RENDERER = "SourceEnhancedChaosDaemonVisual.gd"
FOLDER = "work/creatures/native-form-audit/enhanced-source-gaps/chaos-daemon-enhanced"


def prepare_chaos_daemon(root, source, common, staged=None):
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
    assert render["clips"] == clips and render["poses"] == 80 and render["minimum_foreground_box_pixels"] > 5000
    assert render["scene_sha256"] == runtime["hashes"]["modern"]
    dense = read(folder / "dense-clearance-receipt.json")
    assert dense["sample_rate"] == 240 and dense["treatments"].keys() == runtime["hashes"].keys()
    for treatment, measured in dense["treatments"].items():
        assert measured["scene_sha256"] == runtime["hashes"][treatment] and measured["clips"].keys() == set(clips)
        assert sum(clip["samples"] for clip in measured["clips"].values()) == 1944
        assert all(clip["crossings"] == 0 and clip["maximum_supported_foot_gap"] < .004
                   for clip in measured["clips"].values())
    assets = {name: folder / f"{BODY}-{name}.scn" for name in runtime["hashes"]}
    row, copies = common["fitted_row"](root / "Viewer", BODY, routes, clips, assets, runtime["hashes"])
    return {str(BODY): row}, copies, verify_native(root, stage, routes, runtime["hashes"]["modern"], read, sha)


def verify_native(root, stage, routes, asset, read, sha):
    folder = root / "work/creatures/native-chaos-daemon-enhanced"
    path = folder / "chaos-daemon-native.json"
    native, engine = read(path), read(folder / "chaos-daemon-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert sha(file) == engine[f"{key}_sha256"].lower()
    assert sha(folder / "NativeChaosDaemonLive.gd") == native["test_sha256"]
    assert sha(root / FOLDER / "test-chaos-daemon-enhanced.gd") == native["inputs_sha256"]
    assert sha(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["renderers"] == {str(BODY): sha(stage / "Viewer/Presentation" / RENDERER)}
    assert native["checks"] >= 180 and native["records"].keys() == {"chaos-daemon"}
    record = native["records"]["chaos-daemon"]
    assert (record["class"], record["corpse_body"], record["hue"], record["corpse_hue"]) == ("ChaosDaemon", BODY, 0, 0x8035)
    assert record["ai"] == "MeleeAI" and record["stock_weapon"] == "Fists" and record["can_move"]
    assert not record["can_swim"] and max(map(abs, record["step_delta"])) == 1
    assert record["corpse"] >= 0x40000000 and record["crushing_blow"]
    combat = record["combat"]
    assert combat["damage"] > 0 and combat["packet"]["protocol"] == "classic" and combat["packet"]["body"] == BODY
    assert combat["effect"]["graphic"] == 0xFB4 and combat["effect"]["kind"] == "moving"
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
