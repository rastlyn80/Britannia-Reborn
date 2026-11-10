# SPDX-License-Identifier: GPL-3.0-or-later
"""Seal the Scorpion, Deathwatch Beetle, Air Elemental and Slime fits."""

from hashlib import sha256
import runpy


SPRITES = {
    48: {
        4: ("ScorpionScissorStrike", 35, "62fa4a43f7066700dcf1bf6b9cb488291e0c0c0e3ee70a50beea847e605b6750"),
        23: ("ScorpionTailRise", 55, "b59c353b3eea1a1351e325e82de29ea494845f2a70a29da47a0b7df5f343f25b"),
        25: ("ScorpionQuietBrace", 60, "93845c93f5086a91242f2a69998cb8eae3db073e9cbcf5e1440e33220f54b165"),
        26: ("ScorpionClawCheck", 60, "135e2f8e68900d51ec43bde91ad6d6c9a0f29815c0c5b29592d6d6c3a4154c28"),
        27: ("ScorpionRaisedPincers", 35, "39a7abbb557ef87be2e522c6774b514e8d55a69c6576a32d14b601cffa67b42a"),
        28: ("ScorpionClawAlert", 30, "e0c5f92e6daf427a00f782434992f1aee03dc074294c14357ec9406d093db02c"),
    },
    242: {
        1: ("DeathwatchTuckedWatch", 60, "f8527708da66ffcb8772e75cf2bb6e48a97ce6ecae66dc28d2d51ecca672ac27"),
        4: ("DeathwatchCrossShear", 45, "abc2ebb6214249abb7dd12f65995d6d2ead5d9b3cd29e34d09e35e42bd169257"),
        25: ("DeathwatchQuietBreath", 50, "6f71ce30b188f417b88d89f09a8f4723996a3751708bff3a645b208c6e39a6be"),
        26: ("DeathwatchPalpBrush", 55, "34c7683cb47edecd844bc13490277a5d1e6638b2d8645592920fa11ffedf8e8a"),
        27: ("DeathwatchAbdomenCurl", 55, "fe408cfa9be30de62c61385479191eefeb1e861cdd8d00b98ec0a70052976eac"),
        28: ("DeathwatchForelimbAlert", 40, "d4ca6587e6311837e4d68b3f7dbba92d0e695b702ed00083a5dacf90421c57a0"),
    },
    13: {
        23: ("AirVortexFormation", 60, "2e0570d0ad991da2476d1658fd03c98f1e96c9d51cdc9ef4acc871e6f37ae9ec"),
        28: ("AirSpreadAlert", 40, "e6ea97c869eb9604b6adaa65e9aa431122b6088670feca00f8a3930e300365b6"),
    },
    51: {
        4: ("SlimeCrestLash", 30, "4b014fedeb04fa8bf946435b14d8e087863068777243122a2919149a90ddca75"),
        25: ("SlimeQuietPulse", 45, "dfaf02b2830baad3a7415364f1562e05f809aecb09e5cbc06f65a4e33be3f370"),
    },
}
MEMBERS = {48: "0x4110b8da5c2db234", 242: "0x74181c4f6de5db29", 13: "0x17c1e77d58f9cce", 51: "0x81a75974c61586cc"}
FAMILIES = {48: ("scorpion-bimbobushi", "Scorpion"), 242: ("scorpion-bimbobushi", "Deathwatch"),
            13: ("air-slime", "Air"), 51: ("air-slime", "Slime")}
TYPES = {48: (5, 8, 11, 14, 15), 242: (2, 5, 8, 11, 14, 15), 13: (8, 15), 51: (2, 5, 8, 11, 14, 15)}
FORMS = {
    "scorpion": ("Scorpion", 48, (0,), 0x8035), "deathwatch": ("DeathwatchBeetle", 242, (0,), 0x455),
    "hatchling": ("DeathwatchBeetleHatchling", 242, (0,), 0x8035),
    "air": ("AirElemental", 13, (0x4001,), 0x8035), "summoned-air": ("SummonedAirElemental", 13, (0x4001,), 0x455),
    "slime": ("Slime", 51, range(2201, 2225), 0x455), "corrosive-slime": ("CorrosiveSlime", 51, range(2201, 2225), 0x8035),
}
CLASSIC_NEW = {
    48: {5: ("Fidget", "TailCheck"), 8: ("ClawDraw", "ClawDraw"), 14: ("ClawDraw", "ClawDraw")},
    242: {2: ("RightRecoil", "LeftRecoil"), 5: ("RearingFidget", "Fidget"), 8: ("Fidget", "Fidget"), 14: ("Fidget", "Fidget")},
    13: {8: ("Pillage", "Pillage")},
    51: {5: ("Fidget", "CrestRise"), 8: ("Pillage", "Pillage"), 14: ("Pillage", "Pillage")},
}
NATIVE = {
    "scorpion-deathwatch": ("scorpion-bimbobushi", "ScorpionDeathwatch", 396, ("scorpion", "deathwatch", "hatchling")),
    "air-slime": ("air-slime", "AirSlime", 399, ("air", "summoned-air", "slime", "corrosive-slime")),
}


def prepare_scorpion_through_slime(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    stage = staged or root
    viewer = root / "Viewer"
    work = root / "work/creatures"
    gaps = work / "native-form-audit/enhanced-source-gaps"
    name_hash = runpy.run_path(str(root / "scripts/audit-classic-parity.py"))["name_hash"]
    assert MEMBERS == {body: hex(name_hash(f"build/animationsequence/{body:08d}.bin")) for body in SPRITES}
    groups = {}
    for types in dict.fromkeys(TYPES.values()):
        inputs = {body: SPRITES[body] for body in TYPES if TYPES[body] == types}
        groups.update(common["source_tables"](root, source, inputs, types, member_hashes=MEMBERS))

    results = read(gaps / "scorpion-bimbobushi/integration/terrain-receipt.json")
    assert results["script_sha256"] == digest(stage / "scripts/test-scorpion-through-slime-enhanced.gd")
    terrain = results["bodies"]
    assert set(map(int, terrain)) == FAMILIES.keys()
    rows, copies = {}, {}
    for body, (family, _) in FAMILIES.items():
        scenes = gaps / family
        clips = [clip for clip, _, _ in SPRITES[body].values()]
        report = terrain[str(body)]
        render = read(scenes / "motion-render-receipt.json")[str(body)]
        treatments = ("modern",) if body == 13 else ("original", "rounded", "modern")
        types = len(groups[body]["0"])
        assert report["decoded"] == 8 * types * len(treatments) and report["classic"] == 6 * types * len(treatments)
        assert report["poses"] == 155 * len(clips) * len(treatments)
        assert report["falls"] == 10 * len(clips) * len(treatments) and report["hues"] == 3
        assert report["interruption_recoveries"] == (3 if body == 13 else 0)
        assert report["air_falls"] == 0 and report["maximum_death_jump"] < .002
        assert set(clips) == report["terrain"].keys() == set(render["clips"])
        assert all(pose["gap"] > .0019 for pose in report["terrain"].values())
        assert render["poses"] == 8 * len(clips) and render["scene_sha256"] == report["hashes"]["modern"]
        if body == 13:
            assert 0 < render["first_formation_box"] < render["minimum_foreground_box_pixels"]
            formation = report["terrain"]["AirVortexFormation"]
            assert formation["minimum"] < .10 and formation["maximum"] > 1.45
        assets = {name: scenes / f"{body}-{name}.scn" for name in treatments}
        rows[str(body)], local = common["fitted_row"](viewer, body, groups[body], [] if body == 13 else clips, assets, report["hashes"])
        copies.update(local)
    proof = [verify_native(root, stage, gaps, work, key, groups, terrain, common) for key in NATIVE]
    return rows, copies, sha256("".join(proof).encode("ascii")).hexdigest()


def verify_native(root, stage, gaps, work, key, groups, terrain, common):
    read, digest = common["read"], common["sha"]
    family, script, checks, forms = NATIVE[key]
    folder = work / f"native-{key}-enhanced"
    path = folder / f"{key}-native.json"
    native = read(path)
    receipt = read(folder / f"{key}-native-runtime.json")
    assert digest(path) == receipt["report_sha256"].lower()
    assert digest(root / "Server/runtime/Server.dll") == receipt["server_sha256"].lower()
    assert digest(root / "Server/runtime/Assemblies/UOContent.dll") == receipt["content_sha256"].lower()
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    assert digest(fixture) == receipt["fixture_sha256"].lower()
    assert digest(folder / f"Native{script}Live.gd") == native["test_sha256"]
    assert digest(gaps / family / f"test-{key}-enhanced.gd") == native["inputs_sha256"]
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
    summoned = form == "summoned-air"
    assert record.get("summoned", False) == summoned
    assert (record["corpse"] == 0) if summoned else (record["corpse"] >= 0x40000000)
    if body in (48, 242):
        assert record["tamable"] == (form != "hatchling")
    if form == "deathwatch":
        venom = record["venom"]
        assert venom["poison_level"] == 1 and 1 <= venom["attempts"] <= 100
        effect = venom["effect"]
        assert (effect["graphic"], effect["hue"], effect["kind"]) == (0x36D4, 0x3F, "moving")
        assert effect["source"] == record["serial"] and effect["target"] != effect["source"]
    phase, = record["phases"]
    assert phase["body"] == body and phase["asset_sha256"] == terrain[str(body)]["hashes"]["modern"]
    table = groups[body]
    expected = {(flag, kind, variant) for flag in (0, 64) for kind in TYPES[body] for variant in (0, 1, 255)}
    assert len(phase["cases"]) == len(expected)
    assert {(case["flags"], case["type"], case["variation"]) for case in phase["cases"]} == expected
    for case in phase["cases"]:
        action, variant, flags = case["type"], case["variation"], case["flags"]
        mode = "0" if flags else "1"
        choices = table[mode].get(str(action), table["0"][str(action)])
        classic = CLASSIC_NEW[body].get(action, ("", ""))[variant & 1]
        assert case["classic"] == classic
        assert case["enhanced"] == (choices[variant % len(choices)] if variant <= 127 else classic)
    swing = record["swing"]
    packet = swing["packet"]
    assert packet["protocol"] == "classic" and packet["body"] == body and packet["serial"] == record["serial"]
    expected = ("Attack", "Attack2", "ClawSnap" if body == 48 else "Attack3")
    assert packet["action"] in (4, 5, 6) and swing["clip"] == expected[packet["action"] - 4]
