# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the Minotaur's official references and local fitted presentation."""

import runpy


BODY = 263
MEMBER = "0x5525127d1d79047b"
SPRITES = {
    4: ("MinotaurHornHook", 45, "de6e970dc3f822293a5c046b2ab59f3b38b82f29186dc6ab6f2ecbf1fe537bf2"),
    11: ("MinotaurLowFeint", 55, "394e938d960c89597dc2a9e33cd237103052f73a37be759d97608520b08c88ca"),
    15: ("MinotaurHighWard", 35, "54071ec3d67bd28b09a0ee7a901eac76901600687265a5d21d48ddfdde4e5766"),
    23: ("MinotaurCrouchingRise", 60, "6bcd1b7782999e03a9763c333fbf0ec5d336059f2db5bebb0606a1c6ed3e3347"),
    25: ("MinotaurQuietStand", 60, "44106c27fe54c50aea4971a5943d4f74de023261cb401374469eb9d9fb79b9ce"),
    26: ("MinotaurScentTurn", 50, "bb7715d7bb1088d0fd77aff143aab244579bc7892ef9e35eadd82780dbc17f70"),
    27: ("MinotaurWideThreat", 50, "d6e3afbcb51693c630ad07c528fd54870fcf5d64df31fbdceea2cda37c5a9f8c"),
    28: ("MinotaurForwardGuard", 50, "0611ca2553979660b64bf3531749736ba39864cbe83c7d978ca964ffa963bcb7"),
}
TYPES = (2, 5, 8, 11, 14, 15)
RENDERER = "SourceEnhancedMinotaurVisual.gd"
FOLDER = "work/creatures/native-form-audit/enhanced-source-gaps/minotaur-enhanced"


def prepare_minotaur(root, source, common, staged=None):
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
    assert render["clips"] == clips and render["poses"] == 80 and render["minimum_foreground_box_pixels"] > 9000
    assert render["scene_sha256"] == runtime["hashes"]["modern"]
    dense = read(folder / "dense-clearance-receipt.json")
    assert dense["sample_rate"] == 240 and dense["treatments"].keys() == runtime["hashes"].keys()
    for treatment, measured in dense["treatments"].items():
        assert measured["scene_sha256"] == runtime["hashes"][treatment] and measured["clips"].keys() == set(clips)
        assert sum(clip["samples"] for clip in measured["clips"].values()) == 1772
        assert all(clip["crossings"] == 0 and clip["maximum_supported_foot_gap"] < .004
                   for clip in measured["clips"].values())
    assets = {name: folder / f"{BODY}-{name}.scn" for name in runtime["hashes"]}
    row, copies = common["fitted_row"](root / "Viewer", BODY, routes, clips, assets, runtime["hashes"])
    return {str(BODY): row}, copies, verify_native(root, stage, routes, runtime["hashes"]["modern"], read, sha)


def verify_native(root, stage, routes, asset, read, sha):
    folder = root / "work/creatures/native-minotaur-enhanced"
    path = folder / "minotaur-native.json"
    native, engine = read(path), read(folder / "minotaur-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert sha(file) == engine[f"{key}_sha256"].lower()
    assert sha(folder / "NativeMinotaurLive.gd") == native["test_sha256"]
    assert sha(root / FOLDER / "test-minotaur-enhanced.gd") == native["inputs_sha256"]
    assert sha(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["renderers"] == {str(BODY): sha(stage / "Viewer/Presentation" / RENDERER)}
    assert native["checks"] >= 195 and native["records"].keys() == {"minotaur"}
    record = native["records"]["minotaur"]
    assert (record["class"], record["corpse_body"], record["hue"], record["corpse_hue"]) == ("Minotaur", BODY, 0, 0x8035)
    assert record["ai"] == "MeleeAI" and record["stock_weapon"] == "Fists" and record["can_move"] and record["paralyze"]
    assert not record["can_swim"] and max(map(abs, record["step_delta"])) == 1
    assert record["corpse"] >= 0x40000000
    combat = record["combat"]
    assert combat["damage"] > 0 and combat["paralyzed"]
    assert combat["packet"]["protocol"] == "classic" and combat["packet"]["body"] == BODY
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
