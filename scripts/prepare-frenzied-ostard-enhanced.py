# SPDX-License-Identifier: GPL-3.0-or-later
"""Validate the Frenzied Ostard's loose and mounted Enhanced fits."""

from itertools import product
import runpy


BODY = 218
MEMBER = "0x9009e0d47c5e15ec"
FOLDER = "work/creatures/native-form-audit/enhanced-source-gaps/frenzied-ostard-enhanced"
PREFIX = "FrenziedOstard"
FRAMES = {
    4: ("Snap", 40, "2b280f7d0e374d99d648291f2576c458b0e59fb3f2c08c0d95ce8c056580096b"),
    15: ("Coil", 30, "a5127b032e475a2f959cac2353300462e052758e48e2a0f57845e0af8ab9db5a"),
    23: ("Rise", 50, "ba24d876dac5779499fa897c3b584d3feb9e0c4a3d543a64c93fa313071ce955"),
    25: ("QuietIdle", 50, "991b29f26d98e048a3d9d55c31d0fabb8a0d64b2b34dccc65d04c6f358b54171"),
    26: ("TailCheck", 60, "1e2d0304f288cb73a0d6190ba15190f6f16410eda7b200d489467e6662ce8175"),
    27: ("HighAlert", 50, "c1fc37066d54c5df13c26d9395b343c64c07750686472e80a91ba8481a38d43e"),
    28: ("Ready", 35, "afd14970475924a29d8b918d8178064a26a952df5446445326c4c1f51bca1e38"),
    31: ("SeatedIdle", 50, "99a4471ebe240832a7e01ecf1b923a6f17ed3775df772bb80408540b9eb305ae"),
    22: ("PeaceWalk", 50, "d088471cd04726847a1f924670945bbba308177ba995c810af95742860e541d8"),
    29: ("SeatedWalk", 50, "fb7d4c3cf2ce763b905a46ff7110de49810afbc53c1657d1fbedbf79442c68d3"),
    30: ("SeatedRun", 50, "aa83f359fc4d24ffe33d96bbb6f38d7adcd6b2e8bb8111b692e6f205953dbd9b"),
}
BASE = {
    "original": "8d2ea61df556f7b5f7abfa0b9fc68e892f9ced58dba89d78fd4e647eb0478f1d",
    "rounded": "8e28694e56709e96f3dcff0b22f9226b739e357c9238202a9bc62c67e68b44f0",
    "modern": "bfeb58e4ed3d910bf11ce1e1a982576c90025e4189cb6da666df220f1a0307e7",
}
PROVENANCE = "12937478b9c3afcf33ff8a080e9f38197edea26b8400addb00a59979e3061c82"
ACTIONS = {0: {2: [15, 15], 5: [26, 27], 8: [28], 11: [4, 4, 4], 14: [25], 15: [23]},
           1: {5: [26]}, 2: {5: [31]}}
MOVEMENT = {0: [1, 0, 24], 1: [25, 22, 24], 2: [31, 29, 30]}
RENDERER = "SourceEnhancedFrenziedOstardVisual.gd"


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
        assert mode["fallback_mode"] == (-1 if number in (0, 2) else 0)
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


def prepare_frenzied_ostard(root, source, common, staged=None):
    verify_source(root, source, common)
    read, sha = common["read"], common["sha"]
    stage = staged or root
    folder, viewer = root / FOLDER, root / "Viewer"
    base = viewer / "local-art/ostards"
    assert sha(base / "frenzied-provenance.json") == PROVENANCE
    assert all(sha(base / f"frenzied-{name}.gltf") == digest for name, digest in BASE.items())
    clips = {group: PREFIX + name for group, (name, _, _) in FRAMES.items()}
    routes = {str(mode): {str(kind): [clips[group] for group in groups] for kind, groups in ACTIONS[mode].items()}
              for mode in (0, 1)}
    runtime = read(folder / "runtime-receipt.json")
    assert tuple(runtime[key] for key in ("poses", "falls", "routes", "classic", "loose_gaits", "mounted")) == (
        2625, 210, 144, 108, 18, 360)
    assert runtime["gap"] >= .0029 and runtime["fall_gap"] >= .0019 and runtime["mounted_gap"] >= .0019
    assert all(0 <= runtime[key] < .000002 for key in ("handoff", "seat_error", "foot_error"))
    assert runtime["hashes"].keys() == BASE.keys()
    render = read(folder / "motion-render-receipt.json")[str(BODY)]
    assert render["clips"] == list(clips.values()) and render["poses"] == 110
    assert render["scene_sha256"] == runtime["hashes"]["modern"] and render["minimum_foreground_box_pixels"] > 6400
    dense = read(folder / "dense-clearance-receipt.json")
    assert dense["sample_rate"] == 240 and dense["treatments"].keys() == BASE.keys()
    for treatment, measured in dense["treatments"].items():
        assert measured["scene_sha256"] == runtime["hashes"][treatment] and measured["clips"].keys() == set(clips.values())
        assert sum(clip["samples"] for clip in measured["clips"].values()) == 2431
        assert all(clip["crossings"] == 0 for clip in measured["clips"].values())
    assets, copies = {}, {}
    for treatment, digest in runtime["hashes"].items():
        path = f"local-art/creatures/enhanced-creature-actions/{BODY}-{treatment}.scn"
        scene = folder / f"{BODY}-{treatment}.scn"
        assert sha(scene) == digest
        assets[treatment] = {"path": "res://" + path, "sha256": digest}
        copies[viewer / path] = scene
    grounded = [clips[group] for group in (4, 15, 23, 25, 26, 27, 28, 31)]
    row = {"kind": "frenzied", "base_sha256": BASE, "groups": routes, "grounded": grounded, "assets": assets}
    return {str(BODY): row}, copies, verify_native(root, stage, routes, clips, runtime["hashes"]["modern"], read, sha)


def verify_native(root, stage, routes, clips, asset, read, sha):
    folder = root / "work/creatures/native-frenzied-ostard-enhanced"
    path = folder / "frenzied-ostard-native.json"
    native, engine = read(path), read(folder / "frenzied-ostard-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert sha(file) == engine[f"{key}_sha256"].lower()
    assert sha(folder / "NativeFrenziedOstardLive.gd") == native["test_sha256"]
    assert sha(stage / "Viewer/Presentation" / RENDERER) == native["renderer_sha256"]
    assert native["asset_sha256"] == asset and native["checks"] == 281
    cases = native["cases"]
    assert len(cases) == 2 and {case["female"] for case in cases} == {False, True}
    expected = set(product((0, 64), ACTIONS[0], (0, 1, 255)))
    for case in cases:
        assert (case["body"], case["mount_item"], case["dyes"]) == (BODY, 0x3EA4, [53, 0x8035])
        assert case["corpse"] >= 0x40000000 and case["initial_hue"] & 0x8000
        assert case["gaits"] == [clips[group] for group in MOVEMENT[2]]
        actions = case["actions"]
        assert len(actions) == len(expected)
        assert {(action["flags"], action["type"], action["variation"]) for action in actions} == expected
        for action in actions:
            mode, kind, variant = ("0" if action["flags"] else "1"), str(action["type"]), action["variation"]
            choices = routes[mode].get(kind, routes["0"][kind])
            assert action["clip"] == (choices[variant % len(choices)] if variant < 128 else "")
    return sha(path)
