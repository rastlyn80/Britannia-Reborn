# SPDX-License-Identifier: GPL-3.0-or-later
"""Validate the source-backed Giant Serpent and Harpy profile additions."""

import runpy
from pathlib import Path

SPRITES = {
    21: {
        4: ("SerpentUncoilStrike", 35, "659d312e5e6817fb9e3f7034c73702fdd8297abae0f2f624249646a27a6b60bf"),
        23: ("SerpentSurface", 55, "2f025413cb83e4fd61ced90d4b1696b02c02507dbb7a868f83c33d516817b5a1"),
        26: ("SerpentLowWatch", 75, "8f91560e6df9a421b58fe71ba84e8d136bbcedab10f44d8c17b9956322c51657"),
        27: ("SerpentRaisedCoil", 65, "e19516a96f4cff4b6756a0342e5567ee50bf266c4adc578aeeaf4dbaeccc17bc"),
        28: ("SerpentCoilAlert", 35, "e17417cf1705093d67933e890b63a2f7fe5121de27b469a0844b6391fb574a0c"),
    },
    30: {
        12: ("HarpyDoubleWingbeat", 50, "abe9079abd239a617c3c181f560d5c351bbc62ff1c75ad368b528f071146a209"),
        23: ("HarpyGlideSettle", 55, "6ec915a30c21c19a7c99d9ec865f7397a016ddfb67bbc15d97b085e47ad43f97"),
        26: ("HarpyFoldedGlance", 55, "40d004ae9938ca14444cb42d1c72a6c965da115909bb20f61e1464dbb2379444"),
        27: ("HarpyBank", 55, "413cfe7671de04c0b450b20d3e47f68cd5f8eeaf7460905c2bbd5ad90241b10f"),
        28: ("HarpySpreadAlert", 35, "14e4f4592d039a2c595949957a05a8a04beb54722b25ab6960c9b7aaa4bb054c"),
    },
}
TYPES = (5, 8, 11, 15)
FORMS = {
    "serpent": ("GiantSerpent", 21, range(2001, 2019), 0x8035),
    "harpy": ("Harpy", 30, (0,), 0x455),
    "plague-serpent": ("PlagueSpawn", 21, range(0x11, 0x20), 0x455),
}
CLASSIC_NEW = {21: {5: ("Fidget", "TailRipple"), 8: ("Pillage", "Pillage")},
               30: {5: ("Fidget", "FeatherFlick"), 8: ("Wingbeat", "Wingbeat")}}
CLASSIC_SWING = {21: {4: "CoilSnap", 5: "Attack", 6: "LongStrike"},
                 30: {4: "Attack", 5: "RaisedWingKick", 6: "WingRush"}}


def prepare_serpent_harpy(root, source, common, staged=None):
    sha, read = common["sha"], common["read"]
    viewer = root / "Viewer"
    work = root / "work/creatures"
    scenes = work / "native-form-audit/enhanced-source-gaps/serpent-harpy"
    integration = scenes / "integration"
    code_root = staged or root
    groups = common["source_tables"](root, source, {21: SPRITES[21]}, TYPES)
    groups.update(common["source_tables"](root, source, {30: SPRITES[30]}, TYPES, flight_fallback=True))
    candidate = read(integration / "terrain-receipt.json")
    render = read(scenes / "motion-render-receipt.json")
    assert candidate["test_sha256"] == sha(code_root / "scripts/test-serpent-harpy-enhanced.gd")
    assert candidate["bodies"].keys() == render.keys() == {"21", "30"}
    world = read(integration / "world-enhanced.json")
    assert world.keys() == candidate["bodies"].keys()
    rows, copies = {}, {}
    for body, table in groups.items():
        result = candidate["bodies"][str(body)]
        fitted = render[str(body)]
        clips = [clip for clip, _, _ in SPRITES[body].values()]
        grounded = clips if body == 21 else ["HarpyFoldedGlance", "HarpySpreadAlert"]
        assert (result["selection"], result["classic"], result["poses"]) == (96, 72, 2325)
        assert result["flight_flag_checks"] == (9 if body == 30 else 0)
        assert set(fitted["clips"]) == result["gaps"].keys() == set(clips)
        assert fitted["poses"] == 30 and fitted["minimum_foreground_box_pixels"] > 2000
        assert fitted["scene_sha256"] == result["hashes"]["modern"]
        assert all(gap >= .0019 for clip, gap in result["gaps"].items() if clip != "SerpentSurface")
        assert len(result["handoffs"]) == (60 if body == 21 else 30)
        assert all(row["jump"] < .002 and row["gap"] >= .0019 for row in result["handoffs"])
        if body == 21:
            surfacing = result["geometry"]["SerpentSurface"]
            assert surfacing["start_top"] < -.2 and surfacing["end_top"] > .5 and surfacing["end_gap"] > .0039
            assert result["geometry"]["SerpentUncoilStrike"]["reach"] > .30
            assert sum(case["start_gap"] < -.3 for case in result["handoffs"]) == 30
        else:
            stroke = result["geometry"]["HarpyDoubleWingbeat"]
            assert stroke["lift"] > 1.60 and stroke["spread"] > 2.70
        replay = world[str(body)]
        assert replay.keys() == {"settled", "turning"}
        for case in replay.values():
            assert case["clip"] == ("AirDeath" if body == 30 else "Death") and case["head_jump"] < .002
            assert case["corpse"] >= 0x40000000 and case["native_hue"] == (0x8035 if body == 21 else 0x455)
        assets = {name: scenes / f"{body}-{name}.scn" for name in ("original", "rounded", "modern")}
        row, body_copies = common["fitted_row"](viewer, body, table, grounded, assets, result["hashes"])
        if body == 30:
            row["flight_falls_back_to_combat"] = True
        rows[str(body)] = row
        copies.update(body_copies)
    native = work / "native-serpent-harpy-enhanced/serpent-harpy-native.json"
    verify_native(root, code_root, integration, native, candidate, groups, common)
    return rows, copies, sha(native)


def verify_native(root, code_root, integration, path, candidate, groups, common):
    sha, read = common["sha"], common["read"]
    native = read(path)
    receipt = read(path.with_name("serpent-harpy-native-runtime.json"))
    assert sha(path) == receipt["report_sha256"].lower()
    assert sha(root / "Server/runtime/Server.dll") == receipt["server_sha256"].lower()
    assert sha(root / "Server/runtime/Assemblies/UOContent.dll") == receipt["content_sha256"].lower()
    assert native["test_sha256"] == sha(path.with_name("NativeSerpentHarpyLive.gd"))
    assert native["inputs_sha256"] == candidate["test_sha256"]
    viewer = root / "Viewer/Presentation"
    runtime = code_root / "Viewer/Presentation"
    assert native["dispatcher_sha256"] == sha(viewer / "EnhancedCreatureActions.gd")
    fall_name = "SourceSpaceDisplayedFallPlayback.gd"
    fall = integration / fall_name
    assert fall.read_text(encoding="utf-8") == (runtime / fall_name).read_text(encoding="utf-8")
    shadow_ref = "res://../" + fall.relative_to(root).as_posix()
    renderers = {"source_space_fall": sha(fall), "displayed_fall": sha(viewer / "DisplayedCreatureFallPlayback.gd"),
                 "base_fall": sha(viewer / "CreatureFallPlayback.gd")}
    for kind in ("serpent", "harpy"):
        filename = f"SourceEnhanced{kind.title()}Visual.gd"
        shadow = integration / filename
        code = shadow.read_text(encoding="utf-8")
        assert code.count(shadow_ref) == 1
        assert code.replace(shadow_ref, "res://Presentation/" + fall_name) == (runtime / filename).read_text(encoding="utf-8")
        renderers[kind] = sha(shadow)
    assert native["renderers"] == renderers
    verify_cases = runpy.run_path(str(Path(__file__).with_name("enhanced-creature-proof.py")))["verify_native_cases"]
    verify_cases(native, 298, FORMS, TYPES, groups, candidate["bodies"], CLASSIC_NEW, CLASSIC_SWING)
