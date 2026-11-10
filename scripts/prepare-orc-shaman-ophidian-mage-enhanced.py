# SPDX-License-Identifier: GPL-3.0-or-later
"""Check the staff fits, their archive references and disposable server witnesses."""

import runpy


FAMILY = "orc-shaman-ophidian-mage"
TEST = "test-staff-routes.gd"
PROJECT_TEST = f"test-{FAMILY}-enhanced.gd"
MEMBERS = {140: "0x818ef23997573375", 85: "0xf979311eca97bfb0"}
SPRITES = {
    140: {
        23: ("OrcShamanStaffRise", 55, "0c02823f718dc7d5d47b4589774f6a2c56b5735f5864f13ac7d6e7c85b295ec9"),
        28: ("OrcShamanStaffBrace", 30, "385cc6ece2f5bf17d2b9779d19df6e3b45696ea9a80b73b77bad094ab4356c5e"),
    },
    85: {
        23: ("OphidianMageCoilUnwind", 60, "3eb40ab9e0c8b3abfa343faa6241c70b35e43a9f4860dea96ceb81c849aa00f7"),
        26: ("OphidianMageStaffWatch", 50, "94b34a883f6f98244f8bd7f0321e0b90436808529bee58bb68f75ff2a449919c"),
        27: ("OphidianMageHighWard", 45, "5a2ce4e4f81211f11aad5c21e91f6e6eaa2e258baded91a32627e333e23a8bcb"),
        28: ("OphidianMageTailSignal", 55, "8d5979f1e156d634742dc9ca8e824e7b52a2aa5b127bdc16c31d063e7246e126"),
    },
}
TYPES = {140: (8, 15), 85: (5, 8, 15)}
FORMS = {
    "orc": ("OrcishMage", 140, 0x455),
    "mage": ("OphidianMage", 85, 0x8035),
    "archmage": ("OphidianArchmage", 85, 0x455),
}


def prepare_orc_shaman_ophidian_mage(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    work = root / "work/creatures"
    scenes = work / "native-form-audit/enhanced-source-gaps" / FAMILY
    name_hash = runpy.run_path(str(root / "scripts/audit-classic-parity.py"))["name_hash"]
    assert MEMBERS == {body: hex(name_hash(f"build/animationsequence/{body:08d}.bin")) for body in SPRITES}
    evidence = read(scenes / "terrain-receipt.json")
    assert evidence["test_sha256"] == digest(scenes / TEST)
    assert evidence["test_sha256"] == digest((staged or root) / "scripts" / PROJECT_TEST)
    terrain = evidence["bodies"]
    rendered = read(scenes / "motion-render-receipt.json")
    raw = read(scenes / "staff-first-pose-receipt.json")
    assert raw["failures"] == 0 and set(map(int, terrain)) == set(map(int, rendered)) == set(map(int, raw["bodies"])) == SPRITES.keys()
    groups, rows, copies = {}, {}, {}
    treatments = ("original", "rounded", "modern")
    for body, sprites in SPRITES.items():
        groups.update(common["source_tables"](root, source, {body: sprites}, TYPES[body], member_hashes=MEMBERS))
        result, render = terrain[str(body)], rendered[str(body)]
        clips = [clip for clip, _, _ in sprites.values()]
        assert result["poses"] == 465 * len(clips) and result["falls"] == 30 * len(clips)
        assert (result["routes"], result["classic"], result["hues"]) == (24 * len(TYPES[body]), 18 * len(TYPES[body]), 3)
        assert min(result["minimum"], result["fall_minimum"]) >= .0018 and result["maximum_jump"] < .002
        assert result["hashes"].keys() == raw["bodies"][str(body)].keys() == set(treatments)
        assert render["scene_sha256"] == result["hashes"]["modern"] and render["poses"] == len(clips) * 10
        assert set(render["clips"]) == set(clips) and render["minimum_foreground_box_pixels"] > 1000
        for name, proof in raw["bodies"][str(body)].items():
            assert proof["scene_sha256"] == result["hashes"][name] and proof["clips"].keys() == set(clips)
            for motion in proof["clips"].values():
                assert motion["samples"] == 241 and motion["crossings"] == 0 and motion["grip_error"] < .00001
                assert motion["staff_floor"] >= .004 and motion["max_step_deg"] <= 3.0
        assets = {name: scenes / f"{body}-{name}.scn" for name in treatments}
        rows[str(body)], local = common["fitted_row"](root / "Viewer", body, groups[body], clips, assets, result["hashes"])
        copies.update(local)
    return rows, copies, verify_native(root, work, scenes, groups, terrain, common)


def verify_native(root, work, scenes, groups, terrain, common):
    read, digest = common["read"], common["sha"]
    folder = work / f"native-{FAMILY}-enhanced"
    path = folder / f"{FAMILY}-native.json"
    native = read(path)
    runtime = read(folder / f"{FAMILY}-native-runtime.json")
    assert digest(path) == runtime["report_sha256"].lower()
    assert digest(root / "Server/runtime/Server.dll") == runtime["server_sha256"].lower()
    assert digest(root / "Server/runtime/Assemblies/UOContent.dll") == runtime["content_sha256"].lower()
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    assert digest(fixture) == runtime["fixture_sha256"].lower()
    assert digest(folder / "NativeOrcShamanOphidianMageLive.gd") == native["test_sha256"]
    assert digest(scenes / TEST) == native["inputs_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["renderers"] == {
        "mage": digest(root / "Viewer/Presentation/SourceEnhancedSkeletalMageVisual.gd"),
        "beast": digest(scenes / "SourceEnhancedOphidianMageVisual.gd"),
    }
    assert native["checks"] >= 230 and native["records"].keys() == FORMS.keys()
    for name, record in native["records"].items():
        creature, body, hue = FORMS[name]
        assert record["class"] == creature and record["stock_weapon"] == "Fists" and record["hue"] == 0
        assert record["rummaging"] == record["orcish"] == (body == 140)
        assert record["can_move"] and not record["can_swim"] and not record["tamable"]
        assert max(map(abs, record["step_delta"])) == 1
        assert record["loot"] == {"ribs": 1, "regular_hides": 0}
        assert record["corpse_body"] == body and record["corpse_hue"] == hue and record["corpse"] >= 0x40000000
        swing = record["swing"]
        assert swing["spell_damage"] > 0 and swing["native_cast_actions"] == 0
        phase, = record["phases"]
        assert phase["body"] == body and phase["asset_sha256"] == terrain[str(body)]["hashes"]["modern"]
        cases = phase["cases"]
        expected = {(flags, kind, variation) for flags in (0, 64) for kind in TYPES[body] for variation in (0, 1, 255)}
        assert len(cases) == len(expected) and {(c["flags"], c["type"], c["variation"]) for c in cases} == expected
        for case in cases:
            mode = "0" if case["flags"] else "1"
            kind, variation = str(case["type"]), case["variation"]
            choices = groups[body][mode].get(kind, groups[body]["0"][kind])
            assert case["enhanced"] == (choices[variation % len(choices)] if variation <= 127 else case["classic"])
    return digest(path)
