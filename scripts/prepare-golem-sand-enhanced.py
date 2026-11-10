# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the Golem and Sand Vortex animation fit and native witnesses."""

MEMBERS = {752: '0x1fbc6e3e0832ff86', 790: '0x9a4c9b9804aa53eb'}
SPRITES = {
    752: {
        12: ('IronGolemPistonSweep', 45, 'cd39c7f7322ee4ae1205065af75b7ad3449fc833a0f874b97a959ec4b3328e16'),
        23: ('IronGolemWindUp', 50, 'b1c4ddf721724745b17edaccbadf91aab395e351aaf9cb925798fe0f915477d8'),
        26: ('IronGolemValveCheck', 55, '3984646d44ded9393f0ce53a4510c4c3508ab8a05e85601ba673f54990639e32'),
        27: ('IronGolemHammerLift', 45, 'c3f910971c634138fe5a425480d8c9ebe8f478c5836db8406eea3ff3fa87ea5f'),
        28: ('IronGolemTurnAlert', 45, 'd2c7ced1df15e735e07e13e6ab982d14439e0128438afc7bdd56963781329415'),
    },
    790: {
        4: ('SandVortexTwinSweep', 50, 'b9716da239db1b4545dafc47fb7f55e9499e2cfa3bdce995deaddc0f94f47407'),
        15: ('SandVortexCoilRecoil', 35, '3df0bc279abffdd926b308b971ff48f358dfa5d8717f500add55ddc8e077b812'),
        23: ('SandVortexDustRise', 60, 'c74996c0d7f37b1d0632b0f02311ae488e3a86604bd93deed365a1221ef27a09'),
        25: ('SandVortexQuietSpiral', 55, 'f06e86828a7caecd50a8d2456795aa74cfcb9ba8dd23b82990ee9eef1390a6d8'),
        26: ('SandVortexGather', 50, '6c472db3e8d0c27766a519178d5b6a1f41df3c1b73b4c05439518b44f48d96bb'),
        27: ('SandVortexCurl', 50, '88d55f3972ee055b5b6fd18aefa0c99e7cc9bca0b56ce39cdce323e3cab49c69'),
        28: ('SandVortexReachAlert', 50, '60a8d6eda1b4acf6c74d89f4dfd09a1f8f4875001b7603367612e556dd104606'),
    },
}

TYPES = {752: (5, 8, 11, 15), 790: (2, 5, 8, 11, 14, 15)}
FORMS = {"golem": ("Golem", 752, 0x8035), "sand": ("SandVortex", 790, 0x455)}
RENDERERS = {752: "SourceEnhancedIronGolemVisual.gd", 790: "SourceEnhancedSandVortexVisual.gd"}
RUNTIME_COUNTS = {752: (2325, 150, 96, 72, 0), 790: (1085, 70, 48, 36, 5)}


def prepare_golem_sand(root, source, common, staged=None):
    read, sha = common["read"], common["sha"]
    stage = staged or root
    folder = root / "work/creatures/native-form-audit/enhanced-source-gaps/golem-sand-vortex"
    runtime = read(folder / "runtime-receipt.json")
    gpu = read(folder / "motion-render-receipt.json")
    dense = read(folder / "dense-clearance-receipt.json")
    assert dense["sample_rate"] == 240 and dense["bodies"].keys() == runtime.keys()
    assert runtime.keys() == gpu.keys() == {str(body) for body in SPRITES}
    assert sha(root / "Viewer/Art/Creatures/Air/air-elemental.scn") == (
        "97e035049306954884bda58055433a6f11a48c708b06a548d488633ea265559c"
    )
    rows, copies, tables = {}, {}, {}
    for body, groups in SPRITES.items():
        table = common["source_tables"](root, source, {body: groups}, TYPES[body], member_hashes=MEMBERS)[body]
        tables[body] = table
        key = str(body)
        metrics, render = runtime[key], gpu[key]
        fields = ("poses", "falls", "routes", "classic", "interruptions")
        assert tuple(metrics[field] for field in fields) == RUNTIME_COUNTS[body]
        assert metrics["gap"] >= .0029 and metrics["jump"] < .002
        clips = [row[0] for row in groups.values()]
        assert render["poses"] == 10 * len(clips) and set(render["clips"]) == set(clips)
        assert render["minimum_foreground_box_pixels"] > (9000 if body == 752 else 1000)
        assert metrics["hashes"]["modern"] == render["scene_sha256"]
        for treatment, measured in dense["bodies"][key].items():
            assert measured["scene_sha256"] == metrics["hashes"][treatment] and measured["core_triangles"] > 0
            assert measured["clips"].keys() == set(clips)
            assert all(clip["crossings"] == 0 and clip["floor_minimum"] > .0037 for clip in measured["clips"].values())
        assets = {name: folder / f"{body}-{name if body == 752 else 'modern'}.scn"
                  for name in sorted(metrics["hashes"])}
        rows[key], files = common["fitted_row"](root / "Viewer", body, table, clips, assets, metrics["hashes"])
        copies.update(files)
    return rows, copies, verify_native(root, stage, tables, runtime, read, sha)


def verify_native(root, stage, tables, terrain, read, sha):
    folder = root / "work/creatures/native-golem-sand-enhanced"
    path = folder / "golem-sand-native.json"
    native, runtime = read(path), read(folder / "golem-sand-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert sha(file) == runtime[f"{key}_sha256"].lower()
    assert sha(folder / "NativeGolemSandLive.gd") == native["test_sha256"]
    test = root / "work/creatures/native-form-audit/enhanced-source-gaps/golem-sand-vortex/test-golem-sand-enhanced.gd"
    assert sha(test) == native["inputs_sha256"]
    canonical_test = test.read_text(encoding="utf-8")
    for name in RENDERERS.values():
        canonical_test = canonical_test.replace(f'preload("{name}")', f'preload("res://Presentation/{name}")')
    assert (stage / "scripts/test-golem-sand-enhanced.gd").read_text(encoding="utf-8") == canonical_test
    assert sha(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["checks"] >= 270 and native["records"].keys() == FORMS.keys()
    assert native["renderers"] == {str(body): sha(stage / "Viewer/Presentation" / name)
                                   for body, name in RENDERERS.items()}
    for form, (name, body, dye) in FORMS.items():
        witness = native["records"][form]
        assert (witness["class"], witness["hue"], witness["corpse_body"], witness["corpse_hue"]) == (name, 0, body, dye)
        assert witness["stock_weapon"] == "Fists" and witness["ai"] == "MeleeAI"
        assert witness["can_move"] and not any(witness[key] for key in ("tamable", "can_swim", "can_fly"))
        assert witness["corpse"] >= 0x40000000 and max(map(abs, witness["step_delta"])) == 1
        combat, loot = witness["combat"], witness["carved"]
        assert combat["target"] > 0 and combat["before"] > 0
        if body == 752:
            assert 13 <= loot["iron"] <= 21 and 4200 < combat["elapsed_ms"] < 7600
        else:
            assert loot["gold"] > 0 and loot["bones"] >= 1
            assert 750 < combat["elapsed_ms"] < 3600 and combat["damage"] > 0 and combat["after"] < combat["before"]
        phase, = witness["phases"]
        assert phase["asset_sha256"] == terrain[str(body)]["hashes"]["modern"]
        expected = {(flag, kind, var) for flag in (0, 64) for kind in TYPES[body] for var in (0, 1, 2, 255)}
        cases = phase["cases"]
        assert len(cases) == len(expected) and {(case["flags"], case["type"], case["variation"]) for case in cases} == expected
        for case in cases:
            mode, kind, variant = ("0" if case["flags"] else "1"), str(case["type"]), case["variation"]
            choices = tables[body][mode].get(kind, tables[body]["0"][kind])
            assert case["enhanced"] == (choices[variant % len(choices)] if variant <= 127 else case["classic"])
    return sha(path)

