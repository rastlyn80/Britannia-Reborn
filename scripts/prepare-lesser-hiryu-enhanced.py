# SPDX-License-Identifier: GPL-3.0-or-later
"""Validate the Hiryu's loose and mounted Enhanced fits."""

from itertools import product
import runpy


BODY = 243
MEMBER = "0x350b9aa48ccc2efd"
FOLDER = "work/creatures/native-form-audit/enhanced-source-gaps/lesser-hiryu-enhanced"
PREFIX = "Hiryu"
FRAMES = {
    11: ("WingFeint", 50, "dd55865e0119745ab9fde78065391dc2d22109ef948c373fc5237d8eb4792c4c"),
    12: ("TailFlourish", 50, "7a66814b753e5adfd0d7280a6efac68e0c9abd93c07bd31030eaec6cb040b602"),
    15: ("Mantle", 20, "11b499268d902e1d35a4c71bbfc90aa83a2ea62580f82f923178f962289df89e"),
    25: ("QuietWatch", 50, "0c0d3c366ed09b7bb5df55bb1f52dafee02b3ba1d0281fc08e170b67cd18aa90"),
    26: ("LowInspection", 45, "637737ff909889a65a13107540a698d595899b4463f1b3ad8a2b09c68e4ce2b1"),
    27: ("Curl", 30, "900cb4b4031f6aa2df559eb177cf8b791aba527d255640e4569da66fea44e8e3"),
    28: ("HighAlert", 30, "0ae9d5e4b9e237ea90e3e67b7aa2608bcdecba7260bc987e3409bce35e640a38"),
    22: ("PeaceWalk", 50, "d45ac1b68e3a819c8fed29d58281936312c9556ec11ee310abc45bfda878c650"),
    31: ("SeatedIdle", 50, "35dd38ee69d8e967fb8af3f5bc77b3f9859d851b9f5f7efdd423653547f06c04"),
    29: ("SeatedWalk", 50, "1061de8f6779532578af9f38f2277ee3a91c345bf7aa86412fb01ab19eecb09f"),
    30: ("SeatedRun", 50, "ae38260f698a0c1bc81241eb144dbfda257859476e107f7406e5acf984f99b55"),
}
ACTIONS = {0: {2: [15], 5: [27], 8: [28], 11: [12], 14: [11], 15: [29]},
           1: {5: [26]}, 2: {5: [31]}}
HUES = {
    "Hiryu": {0, 0x85C, 0x490, 0x030, 0x037, 0x295, 0x123, 0x482, 0x487, 0x8A5, 0x979, 0x495, 0x48D, 0x47F},
    "LesserHiryu": {0, 0x258, 0x8AB, 0x7D4, 0x163, 0x295},
}
MOVEMENT = {0: [1, 0, 24], 1: [25, 22, 24], 2: [31, 29, 30]}
RENDERER = "SourceEnhancedHiryuVisual.gd"


def verify_source(root, source, common):
    sha = common["sha"]
    scripts = root / "scripts"
    sequence = source / "AnimationSequence.uop"
    assert sha(sequence) == common["SEQUENCE_SHA256"]
    inspect = runpy.run_path(str(scripts / "uo-human-sequences.py"))["inspect"]
    named, = (row for row in inspect(sequence, {BODY}) if row["uop_name_hash"] == MEMBER)
    assert not named.get("unparsed_bytes")
    assert [mode["mode"] for mode in named["modes"]] == [0, 1, 2]
    for mode in named["modes"]:
        number = mode["mode"]
        assert mode["fallback_mode"] == number - 1
        assert mode["movement"] == [
            {"action": action, "one_handed_group": group, "two_handed_group": group}
            for action, group in enumerate(MOVEMENT[number])
        ]
        actions = {}
        for action in mode["new_protocol_actions"]:
            kind = action["type"]
            if kind in ACTIONS[0]:
                assert action["subaction"] == -1 and kind not in actions
                actions[kind] = action["groups"]
        assert actions == ACTIONS[number]
    decode = runpy.run_path(str(scripts / "uo-enhanced-frames.py"))["read_amou"]
    for group, (_, count, digest) in FRAMES.items():
        path = source / f"ec-frame-{BODY}-{group}.bin"
        assert sha(path) == digest
        identity, frames = decode(path.read_bytes())
        assert identity == BODY and len(frames) == count and all(frame.group == group for frame in frames)


def prepare_lesser_hiryu(root, source, common, staged=None):
    verify_source(root, source, common)
    read, sha = common["read"], common["sha"]
    stage = staged or root
    folder, viewer = root / FOLDER, root / "Viewer"
    clips = {group: PREFIX + name for group, (name, _, _) in FRAMES.items()}
    routes = {str(mode): {str(kind): [clips[group] for group in groups] for kind, groups in ACTIONS[mode].items()}
              for mode in (0, 1)}
    runtime = read(folder / "runtime-receipt.json")
    assert tuple(runtime[key] for key in ("poses", "falls", "routes", "classic", "loose_gaits", "mounted")) == (
        2625, 210, 144, 108, 18, 360)
    assert runtime["gap"] >= .0029 and runtime["fall_gap"] >= .0019 and runtime["mounted_gap"] >= .0019
    assert all(0 <= runtime[key] < .000002 for key in ("handoff", "seat_error", "foot_error"))
    render = read(folder / "motion-render-receipt.json")[str(BODY)]
    assert render["clips"] == list(clips.values()) and render["poses"] == 110
    assert render["scene_sha256"] == runtime["hashes"]["modern"] and render["minimum_foreground_box_pixels"] > 3600
    dense = read(folder / "dense-clearance-receipt.json")
    assert dense["sample_rate"] == 240 and dense["treatments"].keys() == runtime["hashes"].keys()
    for treatment, measured in dense["treatments"].items():
        assert measured["scene_sha256"] == runtime["hashes"][treatment] and measured["clips"].keys() == set(clips.values())
        assert sum(clip["samples"] for clip in measured["clips"].values()) == 2325
        assert all(clip["crossings"] == 0 for clip in measured["clips"].values())
    assets = {name: folder / f"{BODY}-{name}.scn" for name in runtime["hashes"]}
    grounded = [clips[group] for group in (11, 12, 15, 25, 26, 27, 28)]
    row, copies = common["fitted_row"](viewer, BODY, routes, grounded, assets, runtime["hashes"])
    return {str(BODY): row}, copies, verify_native(root, stage, routes, clips, runtime["hashes"]["modern"], read, sha)


def verify_native(root, stage, routes, clips, asset, read, sha):
    folder = root / "work/creatures/native-lesser-hiryu-enhanced"
    path = folder / "lesser-hiryu-native.json"
    native, engine = read(path), read(folder / "lesser-hiryu-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert sha(file) == engine[f"{key}_sha256"].lower()
    assert sha(folder / "NativeHiryuLive.gd") == native["test_sha256"]
    assert sha(stage / "Viewer/Presentation" / RENDERER) == native["renderer_sha256"]
    assert native["asset_sha256"] == asset and native["checks"] == 563
    cases = native["cases"]
    assert len(cases) == 4 and {(case["class"], case["female"]) for case in cases} == set(product(HUES, (False, True)))
    expected = set(product((0, 64), ACTIONS[0], (0, 1, 255)))
    for case in cases:
        assert (case["body"], case["mount_item"], case["dyes"]) == (BODY, 0x3E94, [53, 0x8035])
        assert case["corpse"] >= 0x40000000 and case["initial_hue"] & 0x8000
        assert (case["initial_hue"] & 0x7FFF) in HUES[case["class"]]
        assert case["gaits"] == [clips[group] for group in MOVEMENT[2]]
        actions = case["actions"]
        assert len(actions) == len(expected)
        assert {(action["flags"], action["type"], action["variation"]) for action in actions} == expected
        for action in actions:
            mode, kind, variant = ("0" if action["flags"] else "1"), str(action["type"]), action["variation"]
            choices = routes[mode].get(kind, routes["0"][kind])
            assert action["clip"] == (choices[variant % len(choices)] if variant < 128 else "")
    return sha(path)
