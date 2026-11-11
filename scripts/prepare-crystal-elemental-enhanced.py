# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the Crystal Elemental's official references and local fitted presentation."""

import runpy


BODY = 300
MEMBER = "0x2ce160161cfccd80"
SPRITES = {
    11: ("CrystalCrestFlick", 45, "45a41f0f94cfa816b4ec3ab820f0853861986d8e9650be36cee24a9fd9d8a838"),
    12: ("CrystalShardCast", 40, "2dd8e46e9fe0c3ed9cfe212fd1ec372e207b21197f7a0f5f8bb04b8c5b549786"),
    15: ("CrystalSpineFan", 40, "313d1b8a2de57d66d4c30270b4de3adcce0854752cec862483a967fac211f60d"),
    23: ("CrystalShardAssembly", 45, "deeb7a3d5de96f97d1ffd21138cf8bdf63c70d84b05a0460ef9cda935fcdd2f1"),
    25: ("CrystalQuietStill", 50, "de3e85ff7b15e2adc31ce59f0f28dc11fea42f5d4d79acb2e1b30b274f36e554"),
    26: ("CrystalLowInspection", 45, "b8ace51f440ba477acee89dba3ce56a0376342f27565fdfb715332942db99fcb"),
    27: ("CrystalRaisedSpines", 60, "314f3109d5408b3e82b59488d07e0e3acea1ec1e0503813431e8cef4f3658514"),
    28: ("CrystalLowGuard", 30, "fcf6d56ffb110ffc2ab27d924f37fa31591dbfbff2e1e507bf1de6c7cca8994e"),
}
TYPES = (2, 5, 8, 11, 14, 15)
RENDERER = "SourceEnhancedCrystalElementalVisual.gd"
FOLDER = "work/creatures/native-form-audit/enhanced-source-gaps/crystal-elemental-enhanced"


def prepare_crystal_elemental(root, source, common, staged=None):
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
    assert render["clips"] == clips and render["poses"] == 80 and render["minimum_foreground_box_pixels"] > 2700
    assert render["scene_sha256"] == runtime["hashes"]["modern"]
    assert runtime["fragment_samples"] == 345 and runtime["fragment_falls"] == 30
    assert runtime["minimum_fragment_travel"] > 3.5
    dense = read(folder / "dense-shard-receipt.json")
    assert dense["sample_rate"] == 240 and dense["treatments"].keys() == runtime["hashes"].keys()
    for treatment, measured in dense["treatments"].items():
        assert measured["scene_sha256"] == runtime["hashes"][treatment]
        assert measured["samples"] == 1860 and measured["split_samples"] == 253
        assert measured["gap"] >= .0029 and measured["join_error"] < .0002
        assert measured["source_triangles"] == (1021 if treatment == "original" else 4084)
    assets = {name: folder / f"{BODY}-{name}.scn" for name in runtime["hashes"]}
    row, copies = common["fitted_row"](root / "Viewer", BODY, routes, clips, assets, runtime["hashes"])
    return {str(BODY): row}, copies, verify_native(root, stage, routes, runtime["hashes"]["modern"], read, sha)


def verify_native(root, stage, routes, asset, read, sha):
    folder = root / "work/creatures/native-crystal-elemental-enhanced"
    path = folder / "crystal-elemental-native.json"
    native, engine = read(path), read(folder / "crystal-elemental-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert sha(file) == engine[f"{key}_sha256"].lower()
    assert sha(folder / "NativeCrystalElementalLive.gd") == native["test_sha256"]
    assert sha(root / FOLDER / "test-crystal-elemental-enhanced.gd") == native["inputs_sha256"]
    assert sha(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["renderers"] == {str(BODY): sha(stage / "Viewer/Presentation" / RENDERER)}
    assert native["checks"] >= 185 and native["records"].keys() == {"crystal-elemental"}
    record = native["records"]["crystal-elemental"]
    assert (record["class"], record["corpse_body"], record["hue"], record["corpse_hue"]) == ("CrystalElemental", BODY, 0, 0x8035)
    assert record["ai"] == "MageAI" and record["stock_weapon"] == "Fists" and record["can_move"]
    assert record["lethal_poison_immune"] and record["bleed_immune"] and record["bleed"]
    assert not record["can_swim"] and max(map(abs, record["step_delta"])) == 1
    assert record["corpse"] >= 0x40000000
    combat = record["combat"]
    assert combat["damage"] > 0 and combat["bleeding"]
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
