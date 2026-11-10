# SPDX-License-Identifier: GPL-3.0-or-later
"""Seal the Crane and Fire Elemental fits and their native observations."""

import runpy


SPRITES = {
    254: {
        4: ("CraneWingThrust", 30, "82a2e6f262ceeb917dc8c885c480127a430504a5c147fc40c9ceecd69afc4a74"),
        15: ("CraneFanWarning", 35, "7db83744840a3aa802fc319324ff436f425a71059874534dc5420a86730596d2"),
        25: ("CraneQuietStand", 45, "8b48a4aff5adc6b536114e412f55bcbaddaceec25e696b8d310511715b248109"),
        26: ("CraneBeakSweep", 65, "93031e6416e195fdce7e0b129c52459a7649cbc63267c6966aa200fdf42a8497"),
        27: ("CraneWingBeat", 50, "566ba140cd1a0529b299d523bf598c62b883e59d11793104319fd85860969107"),
        28: ("CraneUnfurl", 30, "debb5098179d901a413e4fab61747bb926a9276e857d4c6a317ad173a4fa99ca"),
    },
    15: {
        23: ("FireKindleAndRise", 35, "2d341a8cb43e475107d2a89f4522d5f2164163ad6e43288d5fd364bd7e44e262"),
        28: ("FireCrownAlert", 30, "724b06723e97ea91b790e599cb743c1b0e2f4dc525d2d7213062f3cd5e7756e4"),
    },
}
MEMBERS = {254: "0xd505f472c597b28b", 15: "0x8c212cb4405a4c35"}
TYPES = {254: (2, 5, 8, 11, 14, 15), 15: (8, 15)}
FORMS = {
    "crane": ("Crane", 254, 0x8035),
    "fire": ("FireElemental", 15, 0x455),
    "summoned-fire": ("SummonedFireElemental", 15, 0x8035),
}


def prepare_crane_fire(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    stage = staged or root
    work = root / "work/creatures"
    scenes = work / "native-form-audit/enhanced-source-gaps/crane-fire"
    name_hash = runpy.run_path(str(root / "scripts/audit-classic-parity.py"))["name_hash"]
    assert MEMBERS == {body: hex(name_hash(f"build/animationsequence/{body:08d}.bin")) for body in SPRITES}
    groups = {}
    for body, clips in SPRITES.items():
        groups.update(common["source_tables"](root, source, {body: clips}, TYPES[body], member_hashes=MEMBERS))
    results = read(scenes / "terrain-receipt.json")
    assert results["script_sha256"] == digest(stage / "scripts/test-crane-fire-enhanced.gd")
    terrain = results["bodies"]
    rendered = read(scenes / "motion-render-receipt.json")
    assert set(map(int, terrain)) == set(map(int, rendered)) == SPRITES.keys()
    rows, copies = {}, {}
    for body, source_groups in SPRITES.items():
        clips = [clip for clip, _, _ in source_groups.values()]
        result = terrain[str(body)]
        render = rendered[str(body)]
        crane = body == 254
        treatments = ("original", "rounded", "modern") if crane else ("modern",)
        count = len(treatments)
        assert result["decoded"] == 8 * len(TYPES[body]) * count
        assert result["classic"] == 6 * len(TYPES[body]) * count and result["hues"] == 3
        assert result["poses"] == 155 * len(clips) * count and result["falls"] == 10 * len(clips) * count
        assert result["maximum_death_jump"] < .002 and result["interruptions"] == (0 if crane else 3)
        assert set(clips) == result["terrain"].keys() == set(render["clips"])
        assert all(pose["gap"] >= .0019 for pose in result["terrain"].values())
        assert render["poses"] == 8 * len(clips) and render["scene_sha256"] == result["hashes"]["modern"]
        if not crane:
            ignition = result["terrain"]["FireKindleAndRise"]
            assert ignition["minimum"] < .45 and ignition["maximum"] > 1.4
        assets = {name: scenes / f"{body}-{name}.scn" for name in treatments}
        rows[str(body)], local = common["fitted_row"](
            root / "Viewer", body, groups[body], clips if crane else [], assets, result["hashes"]
        )
        copies.update(local)
    return rows, copies, verify_native(root, stage, scenes, work, groups, terrain, common)


def verify_native(root, stage, scenes, work, groups, terrain, common):
    read, digest = common["read"], common["sha"]
    folder = work / "native-crane-fire-enhanced"
    path = folder / "crane-fire-native.json"
    native = read(path)
    runtime = read(folder / "crane-fire-native-runtime.json")
    assert digest(path) == runtime["report_sha256"].lower()
    assert digest(root / "Server/runtime/Server.dll") == runtime["server_sha256"].lower()
    assert digest(root / "Server/runtime/Assemblies/UOContent.dll") == runtime["content_sha256"].lower()
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    assert digest(fixture) == runtime["fixture_sha256"].lower()
    assert digest(folder / "NativeCraneFireLive.gd") == native["test_sha256"]
    assert digest(scenes / "test-crane-fire-enhanced.gd") == native["inputs_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["checks"] == 271 and native["records"].keys() == FORMS.keys()
    for renderer in ("Crane", "Fire"):
        filename = f"SourceEnhanced{renderer}Visual.gd"
        trial = scenes / filename
        assert trial.read_text(encoding="utf-8") == (stage / "Viewer/Presentation" / filename).read_text(encoding="utf-8")
        assert digest(trial) == native["renderers"][renderer.lower()]
    for form, record in native["records"].items():
        name, body, hue = FORMS[form]
        crane = body == 254
        summoned = form == "summoned-fire"
        assert record["class"] == name and record["hue"] == 0 and record["stock_weapon"] == "Fists"
        assert record["can_move"] and record["summoned"] == summoned
        assert record["feathers"] == (25 if crane else 0) and record["light_source"] == (not crane)
        assert record["corpse_body"] == body and record["corpse_hue"] == hue
        wire = record["death_packet_corpse"]
        assert wire >= 0x40000000 and record["corpse"] == (0 if summoned else wire)
        phase, = record["phases"]
        assert phase["body"] == body and phase["asset_sha256"] == terrain[str(body)]["hashes"]["modern"]
        verify_cases(body, phase["cases"], groups[body])
        packet = record["swing"]["packet"]
        assert (packet["protocol"], packet["body"], packet["serial"]) == ("classic", body, record["serial"])
        assert packet["action"] == (5 if crane else 6) and record["swing"]["clip"] == ("Attack" if crane else "Attack3")
    return digest(path)


def verify_cases(body, cases, groups):
    expected = {(flags, kind, variant) for flags in (0, 64) for kind in TYPES[body] for variant in (0, 1, 255)}
    assert len(cases) == len(expected)
    assert {(case["flags"], case["type"], case["variation"]) for case in cases} == expected
    for case in cases:
        action, variation, flags = str(case["type"]), case["variation"], case["flags"]
        mode = "0" if flags else "1"
        choices = groups[mode].get(action, groups["0"][action])
        classic = "Pillage" if body == 15 and action == "8" else ""
        assert case["classic"] == classic
        assert case["enhanced"] == (choices[variation % len(choices)] if variation <= 127 else classic)
