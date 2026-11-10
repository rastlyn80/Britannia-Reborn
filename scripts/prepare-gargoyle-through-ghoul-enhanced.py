# SPDX-License-Identifier: GPL-3.0-or-later
"""Seal four fitted rigs against exact Enhanced frame and isolated client evidence."""

from hashlib import sha256
import runpy


SPRITES = {
    4: {
        23: ("GargoyleWingRise", 65, "06531e780fbac89162daccc98573b8bbc678e62d009985bdb6e3826728dab548"),
        26: ("GargoyleWingWatch", 60, "6ef54fb03a14478a297a881e41fd49d2779c04d79a1c3beb5a6458a90f8ae8c3"),
        27: ("GargoyleWingFeint", 55, "770f155af1f99fb9b22955b9d6c436c974b3cdf3202d885239cc45a298be1869"),
        28: ("GargoyleWingAlert", 30, "dbce1af3f37860cb2a2fed4c57dd7679477b6235c76cef3674b806222e3f8b05"),
    },
    31: {
        23: ("HeadlessGatherRise", 60, "d8addeb3565096fdac1679b7b7efdd2aa47d68df89c421282e090c8cff9d3b75"),
        28: ("HeadlessCrookedAlert", 35, "ed6f9f0334562ca9a21a06b8db53d474a30ddb0334c56c0038adef546c7098c9"),
    },
    74: {
        12: ("ImpWingFlick", 35, "2f0babd7934e5a42b3ec0e3215d43615bedbb3490be6036ee887779e2884f10b"),
        23: ("ImpUnfurl", 55, "220d7a7913fe554e11068b977b54e835269fcc832ba4dd916de196e09547a6c2"),
        26: ("ImpQuietHover", 45, "f7eea1a155ef06fa43c8eafd26ebda7be480dfef9f68365984fa56a452a4c16b"),
        27: ("ImpGlideFeint", 45, "60531ca63c6993f75b7f6281e5e1122584d8aaded0fbb12d199c909ae36a45a7"),
        28: ("ImpWingAlert", 25, "37b098411eaf7014b3cd7643dd6e84c951ce743d1ba0df13b9e4ed62b959d381"),
    },
    153: {
        23: ("GhoulKneelingRise", 50, "889b884d8c7b6fe305a748ca2fffd55253b7c18d83e81cbd834f1908bc4dcc5a"),
        28: ("GhoulCrookedReach", 45, "623a5cbdf211b4e26f5fb1f91219be4102e757bcbed5e6024d93776c3b06e0bb"),
    },
}
MEMBERS = {4: "0x341d6237ae090ec4", 31: "0xb6595889124764c", 74: "0x7ea43df1b59e7bf1", 153: "0x17cf4334d79a4937"}
FAMILIES = {4: ("gargoyle-headless", "Gargoyle"), 31: ("gargoyle-headless", "Headless"),
            74: ("imp-ghoul", "Imp"), 153: ("imp-ghoul", "Ghoul")}
FORMS = {
    "gargoyle": ("Gargoyle", 4, (0,), 0x8035), "headless": ("HeadlessOne", 31, range(1002, 1059), 0x455),
    "imp": ("Imp", 74, (0,), 0x8035), "ghoul": ("Ghoul", 153, (0,), 0x455), "bogle": ("Bogle", 153, (0,), 0x8035),
}
CLASSIC_NEW = {
    4: {5: ("Fidget", "WingDip"), 8: ("KneelingLunge", "KneelingLunge")}, 31: {8: ("Pillage", "Pillage")},
    74: {5: ("WingTwitch", "Fidget2"), 8: ("WingTwitch", "WingTwitch")}, 153: {},
}
CLASSIC_SWING = {
    4: {4: "RaisedWingRake", 5: "Attack", 6: "ForwardWingPunch"}, 31: {4: "Attack", 5: "Attack2", 6: "Attack3"},
    74: {4: "Attack", 5: "Attack", 6: "Attack"}, 153: {4: "Attack", 5: "Attack2", 6: "Attack3"},
}
NATIVE = {"gargoyle-headless": ("GargoyleHeadless", 201, ("gargoyle", "headless")),
          "imp-ghoul": ("ImpGhoul", 298, ("imp", "ghoul", "bogle"))}


def prepare_gargoyle_through_ghoul(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    stage = staged or root
    viewer = root / "Viewer"
    work = root / "work/creatures"
    gaps = work / "native-form-audit/enhanced-source-gaps"
    name_hash = runpy.run_path(str(root / "scripts/audit-classic-parity.py"))["name_hash"]
    assert MEMBERS == {body: hex(name_hash(f"build/animationsequence/{body:08d}.bin")) for body in SPRITES}
    verify_source = common["source_tables"]
    groups = verify_source(root, source, {4: SPRITES[4]}, (5, 8, 15), flight_fallback=True,
                           member_hashes=MEMBERS, flight_mode_fallback=1)
    groups.update(verify_source(root, source, {74: SPRITES[74]}, (5, 8, 11, 15), member_hashes=MEMBERS))
    groups.update(verify_source(root, source, {31: SPRITES[31], 153: SPRITES[153]}, (8, 15), member_hashes=MEMBERS))

    results = read(gaps / "gargoyle-headless/integration/terrain-receipt.json")
    assert results["script_sha256"] == digest(stage / "scripts/test-gargoyle-through-ghoul-enhanced.gd")
    terrain = results["bodies"]
    assert set(map(int, terrain)) == FAMILIES.keys()
    rows, copies = {}, {}
    for body, (family, _) in FAMILIES.items():
        scenes = gaps / family
        clips = [clip for clip, _, _ in SPRITES[body].values()]
        report = terrain[str(body)]
        render = read(scenes / "motion-render-receipt.json")[str(body)]
        types = len(groups[body]["0"])
        assert report["decoded"] == 24 * types + (36 if body == 4 else 0)
        assert report["classic"] == 18 * types and report["poses"] == 465 * len(clips)
        assert report["falls"] == 30 * len(clips) and report["hues"] == 3
        assert report["air_falls"] == (15 if body == 4 else 0) and report["maximum_death_jump"] < .002
        assert set(clips) == report["terrain"].keys() == set(render["clips"])
        assert all(pose["gap"] > .0019 for pose in report["terrain"].values())
        assert render["poses"] == 8 * len(clips) and render["minimum_foreground_box_pixels"] > 1800
        assert render["scene_sha256"] == report["hashes"]["modern"]
        assets = {name: scenes / f"{body}-{name}.scn" for name in ("original", "rounded", "modern")}
        rows[str(body)], scene_copies = common["fitted_row"](viewer, body, groups[body], clips, assets, report["hashes"])
        copies.update(scene_copies)
    proof = [verify_native(root, stage, gaps, work, family, groups, terrain, common) for family in NATIVE]
    return rows, copies, sha256("".join(proof).encode("ascii")).hexdigest()


def verify_native(root, stage, gaps, work, family, groups, terrain, common):
    read, digest = common["read"], common["sha"]
    script, checks, forms = NATIVE[family]
    folder = work / f"native-{family}-enhanced"
    path = folder / f"{family}-native.json"
    native = read(path)
    receipt = read(folder / f"{family}-native-runtime.json")
    assert digest(path) == receipt["report_sha256"].lower()
    assert digest(root / "Server/runtime/Server.dll") == receipt["server_sha256"].lower()
    assert digest(root / "Server/runtime/Assemblies/UOContent.dll") == receipt["content_sha256"].lower()
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    assert digest(fixture) == receipt["fixture_sha256"].lower()
    assert digest(folder / f"Native{script}Live.gd") == native["test_sha256"]
    assert digest(gaps / family / f"test-{family}-enhanced.gd") == native["inputs_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    renderers = {}
    for name, renderer in FAMILIES.values():
        if name == family:
            filename = f"SourceEnhanced{renderer}Visual.gd"
            trial = gaps / family / filename
            assert trial.read_text(encoding="utf-8") == (stage / "Viewer/Presentation" / filename).read_text(encoding="utf-8")
            renderers[renderer.lower()] = digest(trial)
    assert renderers == native["renderers"]
    assert native["checks"] == checks and native["records"].keys() == set(forms)
    for form, record in native["records"].items():
        verify_form(form, record, groups, terrain)
    return digest(path)


def verify_form(form, record, groups, terrain):
    name, body, hues, dye = FORMS[form]
    assert record["class"] == name and record["hue"] in hues and record["stock_weapon"] == "Fists"
    assert record["can_move"] and record["corpse_body"] == body and record["corpse_hue"] == dye
    assert record["corpse"] >= 0x40000000
    phase, = record["phases"]
    assert phase["body"] == body and phase["asset_sha256"] == terrain[str(body)]["hashes"]["modern"]
    table = groups[body]
    flags = (0, 4, 64, 68) if body in (4, 74) else (0, 64)
    expected = {(flag, int(kind), variant) for flag in flags for kind in table["0"] for variant in (0, 1, 255)}
    assert len(phase["cases"]) == len(expected)
    assert {(case["flags"], case["type"], case["variation"]) for case in phase["cases"]} == expected
    for case in phase["cases"]:
        action, variant, flags = case["type"], case["variation"], case["flags"]
        mode = "0" if flags & 64 and (body != 4 or not flags & 4) else "1"
        choices = table[mode].get(str(action), table["0"][str(action)])
        classic = CLASSIC_NEW[body].get(action, ("", ""))[variant & 1]
        assert case["classic"] == classic
        assert case["enhanced"] == (choices[variant % len(choices)] if variant <= 127 else classic)
    swing = record["swing"]
    packet = swing["packet"]
    assert packet["protocol"] == "classic" and packet["body"] == body and packet["serial"] == record["serial"]
    assert swing["clip"] == CLASSIC_SWING[body][packet["action"]]
