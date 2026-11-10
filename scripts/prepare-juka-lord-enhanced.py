# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the fitted Juka Lord motions and its independent native bow."""

BODY = 766
SPRITES = {
    BODY: {
        23: ("JukaLordStandFromCrouch", 45, "a4f51f97846d3d7a907358acd42cd6b2d2f4651c500227f330033b74b6435a0d"),
        26: ("JukaLordHandSignal", 60, "15fe8c3524e0d76453e8c3438ee9aa2151f8b906e332c382885caff3db4d2454"),
        27: ("JukaLordForwardWatch", 50, "343bdc83276a3013351fe4b292c42a7ce63eb38a870b0087bddc2addcfcab148"),
        28: ("JukaLordStepAlert", 30, "16345f82bef7cd5dc97520ea31e788d23dad5408568ab43d172b947117917c20"),
    },
}
TYPES = (5, 8, 15)
RENDERER = "SourceEnhancedJukaLordVisual.gd"
PRESENTER = "SourceEnhancedCreatureProjectilePresenter.gd"
FOLDER = "work/creatures/native-form-audit/enhanced-source-gaps/golem-sand-vortex/juka-review"


def prepare_juka_lord(root, source, common, staged=None):
    read, sha = common["read"], common["sha"]
    stage = staged or root
    folder = root / FOLDER
    routes = common["source_tables"](root, source, SPRITES, TYPES,
                                     member_hashes={BODY: "0xd40c20122c0dd09b"})[BODY]
    clips = [row[0] for row in SPRITES[BODY].values()]
    runtime = read(folder / "runtime-receipt.json")
    assert tuple(runtime[key] for key in ("poses", "falls", "routes", "classic")) == (1860, 120, 72, 54)
    assert runtime["body_gap"] >= .0029 and runtime["bow_gap"] > .06 and runtime["fall_bow_gap"] >= .0029
    assert runtime["handoff"] < .002 and runtime["grip"] < .0005
    render = read(folder / "motion-render-receipt.json")[str(BODY)]
    assert render["clips"] == clips and render["poses"] == 40 and render["minimum_foreground_box_pixels"] > 5000
    assert render["scene_sha256"] == runtime["hashes"]["modern"]
    dense = read(folder / "bow-clearance-receipt.json")
    assert dense["sample_rate"] == 240 and dense["treatments"].keys() == runtime["hashes"].keys()
    for treatment, measured in dense["treatments"].items():
        assert measured["scene_sha256"] == runtime["hashes"][treatment] and measured["clips"].keys() == set(clips)
        assert sum(clip["samples"] for clip in measured["clips"].values()) == 877
        assert all(clip["crossings"] == 0 and clip["maximum_grip_error"] < .0005
                   for clip in measured["clips"].values())
    assets = {name: folder / f"{BODY}-{name}.scn" for name in runtime["hashes"]}
    row, copies = common["fitted_row"](root / "Viewer", BODY, routes, clips, assets, runtime["hashes"])
    proof = verify_native(root, stage, routes, runtime["hashes"]["modern"], read, sha)
    return {str(BODY): row}, copies, proof


def verify_native(root, stage, routes, asset, read, sha):
    folder = root / "work/creatures/native-juka-lord-enhanced"
    path = folder / "juka-lord-native.json"
    native, engine = read(path), read(folder / "juka-lord-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert sha(file) == engine[f"{key}_sha256"].lower()
    assert sha(folder / "NativeJukaLordLive.gd") == native["test_sha256"]
    for name, key in ((RENDERER, "renderer"), (PRESENTER, "presenter")):
        assert sha(stage / "Viewer/Presentation" / name) == native[f"{key}_sha256"]
    assert native["checks"] >= 86 and native["native_class"] == "JukaLord" and native["ai"] == "ArcherAI"
    assert native["body"] == BODY and native["asset_sha256"] == asset
    phases = native["phases"]
    expected = {(flags, kind, variant) for flags in (0, 64) for kind in TYPES for variant in (0, 1, 255)}
    assert len(phases) == len(expected)
    assert {(row["flags"], row["type"], row["variation"]) for row in phases} == expected
    for case in phases:
        mode, kind, variant = ("0" if case["flags"] else "1"), str(case["type"]), case["variation"]
        choices = routes[mode].get(kind, routes["0"][kind])
        assert case["enhanced"] == (choices[variant % len(choices)] if variant <= 127 else case["classic"])
    combat, corpse = native["combat"], native["corpse"]
    assert combat["damage"] > 0 and combat["effect"]["graphic"] == 0x0F42 and combat["effect"]["speed"] == 18
    assert combat["presentation"]["origin_error"] < .0001 and .35 <= combat["presentation"]["phase"] <= .75
    assert corpse["serial"] >= 0x40000000 and corpse["bow"] >= 0x40000000
    assert (corpse["body_hue"], corpse["bow_hue"], corpse["arcane_gems"]) == (0x8035, 0x453, 1)
    assert corpse["arrows"] > 0 and corpse["bandages"] >= 5
    return sha(path)
