# SPDX-License-Identifier: GPL-3.0-or-later
"""Validate the Zombie and Wraith fits against registered frames and local trials."""

import runpy
from pathlib import Path

SPRITES = {
    3: {
        4: ("ZombieLurchSwipe", 45, "849d44ba7345560706e1989c7a8463c53ce03f623ee69f987175983d5d12db17"),
        23: ("ZombieGraveRise", 70, "f30f394ac04482f920c4099f8376c25153aa477ba275fc8540d5620cec68e2d7"),
        25: ("ZombieQuietSway", 60, "29d5b1c52624a253367444a5fee6dd12a1a8319e4536b121fba7e8fb6c50c6f2"),
        26: ("ZombieSlumpedWatch", 45, "37fb9d7af23fae2ef613a6b66110ab2fe058735f19daa0d0c6ef011e7957fe07"),
        27: ("ZombieTwistedGuard", 50, "52fc3ef96e908b60e8a752f0295e212890fcd1765893d56a337215a0116b974b"),
        28: ("ZombieArmsUp", 50, "b524b74825ecb63ed9274a8d0ff496b1466e630b0c6d1825ff3ebc84a6625b0c"),
    },
    26: {
        12: ("WraithSurge", 45, "b7fbd066318e7e6038792265caeafd65136f777302c52d27c48f72842faace23"),
        23: ("WraithReconstitute", 60, "1c87221e9aab200633b69a2eb4047676cedffb113dc5ea7c3c6df73a4fca8b32"),
        26: ("WraithVeilInspect", 60, "0e3adbe0a5167c3b274615227a2ab08ee23f8711ad16e13b9311119d680fa23b"),
        27: ("WraithVeilDive", 50, "3c98e5dde33a39a2f9e0694fe9a53a1be9d9cd43533eda905ccd9d165cf1ac16"),
        28: ("WraithWindborneReach", 30, "d03dc4d30f8bc0a217e72f5a82b1b94fe55fd9390355420ea3cfdcf606983f77"),
    },
}
TYPES = {3: (5, 8, 11, 14, 15), 26: (5, 8, 11, 15)}
FORMS = {
    "zombie": ("Zombie", 3, (0,), 0x8035),
    "wraith": ("Wraith", 26, (0x4001,), 0x4001),
    "shade": ("Shade", 26, (0x4001,), 0x8035),
    "spectre": ("Spectre", 26, (0x4001,), 0x455),
    "spellbinder": ("Spellbinder", 26, (0,), 0x4001),
}
CLASSIC_NEW = {3: {5: ("Fidget", "LookUp"), 8: ("ArmsRaise", "ArmsRaise"), 14: ("ArmsRaise", "ArmsRaise")},
               26: {5: ("Fidget", "SpectralClutch"), 8: ("GhostSway", "GhostSway")}}
CLASSIC_SWING = {3: {4: "BackhandReach", 5: "Attack", 6: "OverheadClaw"},
                 26: {4: "Attack", 5: "Attack2", 6: "OverheadRake"}}


def prepare_zombie_wraith(root, source, common, staged=None):
    sha, read = common["sha"], common["read"]
    viewer = root / "Viewer"
    work = root / "work/creatures"
    scenes = work / "native-form-audit/enhanced-source-gaps/zombie-wraith"
    code_root = staged or root
    groups = {}
    for body, sprites in SPRITES.items():
        groups.update(common["source_tables"](root, source, {body: sprites}, TYPES[body]))
    candidate = read(scenes / "terrain-receipt.json")
    render = read(scenes / "motion-render-receipt.json")
    assert candidate["test_sha256"] == sha(code_root / "scripts/test-zombie-wraith-enhanced.gd")
    assert candidate["bodies"].keys() == {"3", "26"}
    assert render.keys() == {"3:0000", "26:0000", "26:4001"}
    rows, copies = {}, {}
    for body, table in groups.items():
        result = candidate["bodies"][str(body)]
        clips = [clip for clip, _, _ in SPRITES[body].values()]
        expected = (120, 90, 2790, 3, 60) if body == 3 else (96, 72, 2325, 4, 75)
        assert (result["selections"], result["classic"], result["poses"], result["hues"], len(result["falls"])) == expected
        assert all(fall["jump"] < .002 and fall["gap"] > .0019 for fall in result["falls"])
        assert result["poses_by_clip"].keys() == set(clips)
        for hue in ((0,) if body == 3 else (0, 0x4001)):
            fitted = render[f"{body}:{hue:04x}"]
            assert fitted["scene_sha256"] == result["hashes"]["modern"] and set(fitted["clips"]) == set(clips)
            assert fitted["poses"] == len(clips) * 8 and fitted["minimum_foreground_box_pixels"] > 1000
        if body == 3:
            rise = result["poses_by_clip"]["ZombieGraveRise"]
            assert rise["gap"] < -2.0 and .03 < rise["first_top"] < .07 and rise["final_gap"] > .0039
            assert not result["joins"] and not any(fall["scattered"] for fall in result["falls"])
        else:
            assert len(result["joins"]) == 15 and max(result["joins"]) < .0001
            gathering = result["poses_by_clip"]["WraithReconstitute"]
            assert gathering["first_pieces"] == 5 and gathering["maximum_pieces"] == 6
            scattered = [fall["pieces"] for fall in result["falls"] if fall["scattered"]]
            assert len(scattered) == 45 and set(scattered) == {5, 6}
            assert all(pose["gap"] > .0019 for pose in result["poses_by_clip"].values())
        stem = "3" if body == 3 else "26-reconstitute"
        assets = {name: scenes / f"{stem}-{name}.scn" for name in ("original", "rounded", "modern")}
        row, body_copies = common["fitted_row"](viewer, body, table, clips if body == 3 else [], assets, result["hashes"])
        rows[str(body)] = row
        copies.update(body_copies)
    for profile in ("classic", "enhanced"):
        report = read(scenes / f"world-{profile}.json")
        assert report.keys() == {"0", "1", "2", "3"}
        for key, replay in report.items():
            assembled = key == "1" and profile == "enhanced"
            assert replay["body"] == (3 if key == "0" else 26)
            assert replay["clip"] == ("WraithScatterFall" if assembled else "Death")
            assert replay["parts"] == (6 if assembled else 1) and replay["jump"] < .002
            assert replay["corpse"] >= 0x40000000 and replay["hue"] == (0x8035 if key == "0" else 0x4001)
    native = work / "native-zombie-wraith-enhanced/zombie-wraith-native.json"
    verify_native(root, code_root, scenes, native, candidate, groups, common)
    return rows, copies, sha(native)


def verify_native(root, code_root, scenes, path, candidate, groups, common):
    sha, read = common["sha"], common["read"]
    native = read(path)
    receipt = read(path.with_name("zombie-wraith-native-runtime.json"))
    assert sha(path) == receipt["report_sha256"].lower()
    assert sha(root / "Server/runtime/Server.dll") == receipt["server_sha256"].lower()
    assert sha(root / "Server/runtime/Assemblies/UOContent.dll") == receipt["content_sha256"].lower()
    fixture = path.parent / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    assert sha(fixture) == receipt["fixture_sha256"].lower()
    assert native["test_sha256"] == sha(path.with_name("NativeZombieWraithLive.gd"))
    assert native["inputs_sha256"] == candidate["test_sha256"]
    assert native["dispatcher_sha256"] == sha(root / "Viewer/Presentation/EnhancedCreatureActions.gd")
    renderers = {}
    for name in ("zombie", "wraith"):
        filename = f"SourceEnhanced{name.title()}Visual.gd"
        shadow = scenes / filename
        runtime = code_root / "Viewer/Presentation" / filename
        assert shadow.read_text(encoding="utf-8") == runtime.read_text(encoding="utf-8")
        renderers[name] = sha(shadow)
    assert native["renderers"] == renderers and native["checks"] == 512 and native["records"].keys() == FORMS.keys()
    verify_cases = runpy.run_path(str(root / "scripts/enhanced-creature-proof.py"))["verify_native_cases"]
    for body, types in TYPES.items():
        forms = {name: form for name, form in FORMS.items() if form[1] == body}
        evidence = dict(native, records={name: native["records"][name] for name in forms})
        verify_cases(evidence, 512, forms, types, groups, candidate["bodies"], CLASSIC_NEW, CLASSIC_SWING)
