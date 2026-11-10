# SPDX-License-Identifier: GPL-3.0-or-later
"""Seal the Chicken and Skeletal Mage fits and their native observations."""

import runpy


SPRITES = {
    208: {
        4: ("ChickenQuickPeck", 35, "67d52c09688fc568ec064fe6387e51cef037251bfe7f24ca9b4c89bf1ef523c0"),
        25: ("ChickenSettledWatch", 40, "131893ac2c69c48b91d26d8adfd5be933876c0311b3d94a434a80e204275ea7d"),
        28: ("ChickenLowAlert", 35, "55673b2702c7756a48c557426d3a3325eb859fad387a938cd54cf01b2f2f4fc4"),
    },
    148: {
        12: ("SkeletalMageStaffThrust", 45, "0efeaf875012cd5ef22b13d746a1126b7964e341ba1543ce7a6b3eac328fef1a"),
        23: ("SkeletalMageGroundRise", 40, "54f25c5c3dcebdfe33cf1f64fa19407c044732da3cbbe53b143d03de6868e4d5"),
        26: ("SkeletalMageWatch", 40, "0d550fc45db68eaa62cbd0e9adfb376e72e6dd0f62c47cdf578139dca839a2ea"),
        27: ("SkeletalMageStaffLift", 45, "5fd6c0d5ca0089c432e656dceb599f46db07265ee0ce8c041bdc439a299fe84d"),
        28: ("SkeletalMageStaffWard", 35, "fcb8d1687ad1674b1efbef934ce62d8baac9588480eee47069ceae02ba4aaea9"),
    },
}
MEMBERS = {208: "0x91bfa025b63da91b", 148: "0x476191eff1345b3c"}
TYPES = {208: (8, 11, 15), 148: (5, 8, 11, 15)}
FORMS = {"chicken": ("Chicken", 208, 0x8035), "mage": ("SkeletalMage", 148, 0x455)}


def prepare_chicken_skeletal_mage(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    stage = staged or root
    work = root / "work/creatures"
    scenes = work / "native-form-audit/enhanced-source-gaps/chicken-skeletal-mage"
    name_hash = runpy.run_path(str(root / "scripts/audit-classic-parity.py"))["name_hash"]
    assert MEMBERS == {body: hex(name_hash(f"build/animationsequence/{body:08d}.bin")) for body in SPRITES}
    groups = {}
    for body, clips in SPRITES.items():
        groups.update(common["source_tables"](root, source, {body: clips}, TYPES[body], member_hashes=MEMBERS))
    results = read(scenes / "terrain-receipt.json")
    assert results["script_sha256"] == digest(stage / "scripts/test-chicken-skeletal-mage-enhanced.gd")
    terrain = results["bodies"]
    rendered = read(scenes / "motion-render-receipt.json")
    assert set(map(int, terrain)) == set(map(int, rendered)) == SPRITES.keys()
    rows, copies = {}, {}
    for body, source_groups in SPRITES.items():
        clips = [clip for clip, _, _ in source_groups.values()]
        result = terrain[str(body)]
        render = rendered[str(body)]
        chicken = body == 208
        treatments = ("modern",) if chicken else ("original", "rounded", "modern")
        count = len(treatments)
        assert result["decoded"] == 8 * len(TYPES[body]) * count
        assert result["classic"] == 6 * len(TYPES[body]) * count and result["hues"] == 3
        assert result["poses"] == 155 * len(clips) * count and result["falls"] == 10 * len(clips) * count
        assert result["maximum_death_jump"] < .002
        assert set(clips) == result["terrain"].keys() == set(render["clips"])
        assert all(pose["gap"] >= (.0024 if chicken else .0019) for pose in result["terrain"].values())
        assert render["poses"] == 8 * len(clips) and render["scene_sha256"] == result["hashes"]["modern"]
        assert render["minimum_foreground_box_pixels"] >= 1000
        if chicken:
            peck = result["terrain"]["ChickenQuickPeck"]
            assert peck["head_maximum"] - peck["head_minimum"] >= .030
        else:
            rise = result["terrain"]["SkeletalMageGroundRise"]
            assert rise["head_maximum"] - rise["head_minimum"] >= .75 and rise["staff_excursion"] >= .60
        assets = {name: scenes / f"{body}-{name}.scn" for name in treatments}
        rows[str(body)], local = common["fitted_row"](
            root / "Viewer", body, groups[body], clips, assets, result["hashes"]
        )
        copies.update(local)
    return rows, copies, verify_native(root, stage, scenes, work, groups, terrain, common)


def verify_native(root, stage, scenes, work, groups, terrain, common):
    read, digest = common["read"], common["sha"]
    folder = work / "native-chicken-skeletal-mage-enhanced"
    path = folder / "chicken-skeletal-mage-native.json"
    native = read(path)
    runtime = read(folder / "chicken-skeletal-mage-native-runtime.json")
    assert digest(path) == runtime["report_sha256"].lower()
    assert digest(root / "Server/runtime/Server.dll") == runtime["server_sha256"].lower()
    assert digest(root / "Server/runtime/Assemblies/UOContent.dll") == runtime["content_sha256"].lower()
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    assert digest(fixture) == runtime["fixture_sha256"].lower()
    assert digest(folder / "NativeChickenSkeletalMageLive.gd") == native["test_sha256"]
    assert digest(scenes / "test-chicken-skeletal-mage-enhanced.gd") == native["inputs_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["checks"] == 193 and native["records"].keys() == FORMS.keys()
    for form, record in native["records"].items():
        name, body, hue = FORMS[form]
        chicken = body == 208
        filename = f"SourceEnhanced{name}Visual.gd"
        trial = scenes / filename
        assert trial.read_text(encoding="utf-8") == (stage / "Viewer/Presentation" / filename).read_text(encoding="utf-8")
        assert digest(trial) == native["renderers"][form]
        assert record["class"] == name and record["hue"] == 0 and record["stock_weapon"] == "Fists"
        assert record["can_move"] and not record["can_swim"] and record["tamable"] == chicken
        assert len(record["step_delta"]) == 2 and max(map(abs, record["step_delta"])) == 1
        assert record["can_fly"] == chicken and record["bleed_immune"] == (not chicken)
        expected_loot = {"feathers": 25, "raw_bird": 1, "bone": False} if chicken else {
            "feathers": 0, "raw_bird": 0, "bone": True}
        assert record["loot"] == expected_loot
        assert record["corpse_body"] == body and record["corpse_hue"] == hue and record["corpse"] >= 0x40000000
        phase, = record["phases"]
        assert phase["body"] == body and phase["asset_sha256"] == terrain[str(body)]["hashes"]["modern"]
        verify_cases(body, phase["cases"], groups[body])
        packet = record["swing"]["packet"]
        assert (packet["protocol"], packet["body"], packet["serial"]) == ("classic", body, record["serial"])
        if chicken:
            assert packet["action"] == 5 and record["swing"]["clip"] == "Attack"
        else:
            assert packet["action"] in (4, 5, 6)
            assert record["swing"]["clip"] == ("Attack", "StaffPush", "StaffSlash")[packet["action"] - 4]
    return digest(path)


def verify_cases(body, cases, groups):
    expected = {(flags, kind, variant) for flags in (0, 64) for kind in TYPES[body] for variant in (0, 1, 255)}
    assert len(cases) == len(expected)
    assert {(case["flags"], case["type"], case["variation"]) for case in cases} == expected
    for case in cases:
        action, variation, flags = str(case["type"]), case["variation"], case["flags"]
        mode = "0" if flags else "1"
        choices = groups[mode].get(action, groups["0"][action])
        classic = ""
        if body == 148:
            if action == "5":
                classic = "StaffRaise" if variation % 2 else "Fidget"
            elif action == "8":
                classic = "MageStaffCheck"
        assert case["classic"] == classic
        assert case["enhanced"] == (choices[variation % len(choices)] if variation <= 127 else classic)
