# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify Devourer source frames, fitted scenes and the native spell witness."""

import runpy

BODY = 303
MEMBER = "0xc8e38b9bd552d147"
SPRITES = {
    11: ('DevourerFoldIn', 55, '5983b1306962666eca195de8a224fbe20a5886c5814c4d0cbae479638b2498e9'),
    12: ('DevourerRaisedCast', 55, '588b6c53722d6f5bc935a700c9529bd8a0228d71b9eff8cef91e64c4f38a7b5b'),
    15: ('DevourerGuardedBite', 35, '94909a458ad5e7997d03deedfabfa188cb547fbe9e7afa4321fe239e074a33e1'),
    23: ('DevourerWakeUnfold', 55, '0577c77a873f8c3bd6c1c3457a6495bb51d17e6422658903f33fe3e679e18fe5'),
    25: ('DevourerQuietMaw', 55, '18515dde5aab602ca3260c5f9da7128818e6c56fca589db221bbe61dbb9a8a69'),
    26: ('DevourerLowInspection', 55, 'e5b335022cedf8a59ba9e580b06f47a28dffcd317a1461820069d54e56aa18ce'),
    27: ('DevourerMawThreat', 55, '81dfe2a32b0767621730bb5d6c0e610ac960d9cbd13611994f2ef618420a6935'),
    28: ('DevourerWideGuard', 55, '812483dfa9feaae781a5d87d3e6590a7a95bc5751a2fbb63350af6b5c9605988'),
}
TYPES = (2, 5, 8, 11, 14, 15)
RENDERER = "SourceEnhancedDevourerVisual.gd"
PRESENTER = "SourceEnhancedDevourerProjectilePresenter.gd"
FOLDER = "work/creatures/native-form-audit/enhanced-source-gaps/devourer-enhanced"


def prepare_devourer(root, source, common, staged=None):
    read, sha = common["read"], common["sha"]
    stage = staged or root
    folder = root / FOLDER
    packet_groups = {BODY: {group: row for group, row in SPRITES.items() if group != 25}}
    routes = common["source_tables"](root, source, packet_groups, TYPES, member_hashes={BODY: MEMBER})[BODY]
    idle_clip, idle_frames, idle_sha = SPRITES[25]
    idle = source / f"ec-frame-{BODY}-25.bin"
    assert sha(idle) == idle_sha
    decoder = runpy.run_path(str(root / "scripts/uo-enhanced-frames.py"))["read_amou"]
    identity, frames = decoder(idle.read_bytes())
    assert identity == BODY and len(frames) == idle_frames and all(frame.group == 25 for frame in frames)
    inspect = runpy.run_path(str(root / "scripts/uo-human-sequences.py"))["inspect"]
    named, = (row for row in inspect(source / "AnimationSequence.uop", {BODY}) if row["uop_name_hash"] == MEMBER)
    assert named["modes"][1]["movement"][0] == {"action": 0, "one_handed_group": 25, "two_handed_group": 25}
    assert idle_clip == "DevourerQuietMaw"
    clips = [row[0] for row in SPRITES.values()]
    runtime = read(folder / "runtime-receipt.json")
    assert tuple(runtime[key] for key in ("poses", "falls", "routes", "classic", "gaits")) == (3720, 240, 144, 108, 18)
    assert runtime["gap"] >= .0029 and runtime["fall_gap"] >= .0019 and runtime["handoff"] < .002
    render = read(folder / "motion-render-receipt.json")[str(BODY)]
    assert render["clips"] == clips and render["poses"] == 80 and render["minimum_foreground_box_pixels"] > 6000
    assert render["scene_sha256"] == runtime["hashes"]["modern"]
    dense = read(folder / "dense-clearance-receipt.json")
    assert dense["sample_rate"] == 240 and dense["treatments"].keys() == runtime["hashes"].keys()
    for treatment, measured in dense["treatments"].items():
        assert measured["scene_sha256"] == runtime["hashes"][treatment] and measured["clips"].keys() == set(clips)
        assert sum(clip["samples"] for clip in measured["clips"].values()) == 2070
        assert all(clip["crossings"] == 0 and clip["maximum_supported_foot_gap"] < .004
                   for clip in measured["clips"].values())
    assets = {name: folder / f"{BODY}-{name}.scn" for name in runtime["hashes"]}
    row, copies = common["fitted_row"](root / "Viewer", BODY, routes, clips, assets, runtime["hashes"])
    return {str(BODY): row}, copies, verify_native(root, stage, routes, runtime["hashes"]["modern"], read, sha)


def verify_native(root, stage, routes, asset, read, sha):
    folder = root / "work/creatures/native-devourer-enhanced"
    path = folder / "devourer-native.json"
    native, engine = read(path), read(folder / "devourer-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert sha(file) == engine[f"{key}_sha256"].lower()
    assert sha(folder / "NativeDevourerLive.gd") == native["test_sha256"]
    assert sha(root / FOLDER / "test-devourer-enhanced.gd") == native["inputs_sha256"]
    assert sha(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["renderers"] == {"303": sha(stage / "Viewer/Presentation" / RENDERER)}
    assert native["presenter_sha256"] == sha(stage / "Viewer/Presentation" / PRESENTER)
    assert native["checks"] >= 195 and native["records"].keys() == {"devourer"}
    record = native["records"]["devourer"]
    assert (record["class"], record["corpse_body"], record["hue"], record["corpse_hue"]) == ("Devourer", BODY, 0, 0x8035)
    assert record["ai"] == "MageAI" and record["stock_weapon"] == "Fists" and record["can_move"]
    assert record["lethal_poison_immune"] and not record["can_fly"] and not record["can_swim"] and not record["tamable"]
    assert record["corpse"] >= 0x40000000 and max(map(abs, record["step_delta"])) == 1
    combat, loot = record["combat"], record["carved"]
    assert combat["damage"] > 0 and combat["effect"]["graphic"] == 0x36E4 and combat["effect"]["speed"] == 5
    launch = combat["launch"]
    assert launch["clip"] == "DevourerRaisedCast" and launch["origin_error"] < .0001 and .36 <= launch["phase"] <= .69
    assert launch["source"] == combat["effect"]["source"] and launch["target"] == combat["target"]
    assert 24 <= loot["reagents"] <= 45 and loot["gold"] > 0 and loot["meat"] == 3
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
