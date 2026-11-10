# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify fitted scenes against the official frames and isolated ModernUO witnesses."""

MEMBERS = {147: "0xef8c3adcc94babf", 158: "0xd90284e91dd49ef9", 128: "0x766239ac0fe09db6", 55: "0xd606c5aa34ef0f9d"}
SPRITES = {
    147: {
        23: ("SkeletalKnightShieldRise", 45, "e62847437d65438f473f28ce52fd6b261a66117d8d002fbb76f1797fd95b3f45"),
        28: ("SkeletalKnightSwordAlert", 25, "516046a20ab7694633f09b860a566c2d57895947ede70463f352daa34d64a035"),
    },
    158: {
        23: ("AcidElementalCondense", 40, "c9a65636bc48234cdd0b88f5a5ad2d26cb305a94bce51eeae9a6635b1808f236"),
        28: ("AcidElementalSpatterGuard", 30, "c268c36418e36265de59e21654f1ae1f45eb3ae9c27434e3d601fe6eb2b02a6f"),
    },
    128: {
        23: ("PixieLightRise", 50, "67b808becb41535ec03b1592fbca45a94388b23f85ab04768164e5d72b2301f9"),
        26: ("PixieHoverWatch", 55, "b865da8fea2639245c5ddaaf22a128d1b0cdebe0fa0223de6ccd4ff5bad3466e"),
        27: ("PixieBankedHover", 45, "4310cda8daedddb58e6b578882ad347066e4eaa2411f62e3514b8fbd10f45539"),
        28: ("PixieWingAlert", 35, "b342a123c922736132392337798c571ee28896659ab255120f3a6defbd493f13"),
    },
    55: {
        12: ("FrostTrollOpenPalm", 45, "6c63713124ce8982dd703ca859b4e9fd0cc9b7d67cb5bb200f30a40d9a728f1e"),
        23: ("FrostTrollCrouchedRise", 50, "55391c220b8c3f5cd6b8d40ac612e84064a6de7e076f4efa09072a78963e297a"),
        26: ("FrostTrollKnuckleLook", 70, "3c3b393430ee2962661f6c7d7a37190107584343aaa3f163db3e3f38bd233b4f"),
        27: ("FrostTrollStaggerGuard", 50, "5b9ece5051da52c56312b5cce6bfd7add6ebef2999cce6a274fa5a29254657ff"),
        28: ("FrostTrollWideAlert", 35, "b31e053592d79b6c7c02c3d21289448154d7d1c29e1de5d88fbf0f46f823bb60"),
    },
}
TYPES = {147: (8, 15), 158: (8, 15), 128: (5, 8, 15), 55: (5, 8, 11, 15)}
TREATMENTS = ("original", "rounded", "modern")
FORMS = {
    "knight": ("SkeletalKnight", 147, 0x8035, "SourceEnhancedSkeletalMageVisual.gd", {"shield": True, "sword": True}),
    "acid": ("AcidElemental", 158, 0x455, "SourceEnhancedAcidElementalVisual.gd", {"shield": False, "sword": False}),
    "pixie": ("Pixie", 128, 0x8035, "SourceEnhancedPixieVisual.gd", {"ribs": 1, "spined_hides": 6, "axe": False}),
    "troll": ("FrostTroll", 55, 0x455, "SourceEnhancedFrostTrollVisual.gd", {"ribs": 2, "spined_hides": 0, "axe": True}),
}


def prepare_knight_acid_pixie_frost(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    stage = staged or root
    work = root / "work/creatures"
    gaps = work / "native-form-audit/enhanced-source-gaps"
    knight = gaps / "bone-knight-acid-elemental"
    fey = gaps / "pixie-frost-troll"
    fey_terrain = read(fey / "terrain-receipt.json")
    terrain = {147: read(knight / "skeletal-knight-runtime-receipt.json"),
               158: read(knight / "acid-runtime-receipt.json"),
               **{int(body): evidence for body, evidence in fey_terrain["bodies"].items()}}
    tests = {"skeletal-knight": terrain[147], "acid-elemental": terrain[158], "pixie-frost-troll": fey_terrain}
    for family, evidence in tests.items():
        assert digest(stage / "scripts" / f"test-{family}-enhanced.gd") == evidence["test_sha256"]

    groups, rows, copies = {}, {}, {}
    for body, sprites in SPRITES.items():
        groups.update(common["source_tables"](root, source, {body: sprites}, TYPES[body], member_hashes=MEMBERS))
        folder = knight if body in (147, 158) else fey
        clips = [clip for clip, _, _ in sprites.values()]
        result = terrain[body]
        render = read(folder / "motion-render-receipt.json")[str(body)]
        verify_motion(body, clips, result, render)
        assets = {name: folder / f"{body}-{name}.scn" for name in TREATMENTS}
        rows[str(body)], local = common["fitted_row"](root / "Viewer", body, groups[body], clips, assets, result["hashes"])
        copies.update(local)

    verify_props(read(knight / "skeletal-knight-prop-receipt.json"), terrain[147]["hashes"])
    verify_fluid(read(knight / "acid-first-pose-receipt.json"), terrain[158]["hashes"])
    first = verify_native(root, stage, work, knight, "skeletal-knight-acid-elemental", "NativeSkeletalKnightAcidElementalLive.gd",
                          "candidate-routes.gd", ("knight", "acid"), 140, groups, terrain, common)
    second = verify_native(root, stage, work, fey, "pixie-frost-troll", "NativePixieFrostTrollLive.gd",
                           "test-pixie-frost-troll-enhanced.gd", ("pixie", "troll"), 190, groups, terrain, common)
    return rows, copies, {"skeletal_knight_acid_elemental": first, "pixie_frost_troll": second}


def verify_motion(body, clips, result, render):
    if body == 147:
        poses, falls, gap, jump = (result[key] for key in ("terrain", "falls", "minimum_gap", "maximum_jump"))
    elif body == 158:
        poses, falls, gap, jump = (result[key] for key in ("terrain_poses", "interrupted_falls", "minimum_gap", "largest_jump"))
        assert result["size_recoveries"] == 30
    else:
        poses, falls, gap, jump = (result[key] for key in ("poses", "falls", "min_gap", "max_jump"))
        assert result["clip_ranges"].keys() == set(clips)
    assert (poses, falls) == (465 * len(clips), 30 * len(clips)) and gap >= .0018 and jump < .002
    assert (result["routes"], result["classic"]) == (24 * len(TYPES[body]), 18 * len(TYPES[body]))
    assert result["hashes"].keys() == set(TREATMENTS)
    rendered_clips = set(clips) | ({"Death"} if body == 147 else set())
    assert render["scene_sha256"] == result["hashes"]["modern"] and set(render["clips"]) == rendered_clips
    assert render["poses"] == 10 * len(rendered_clips) and render["minimum_foreground_box_pixels"] >= (8 if body == 158 else 1000)


def verify_props(receipt, hashes):
    assert receipt["failures"] == 0 and receipt["treatments"].keys() == hashes.keys()
    expected = {"SkeletalKnightShieldRise": 601, "SkeletalKnightSwordAlert": 313, "Death": 922}
    for name, proof in receipt["treatments"].items():
        assert proof["sha256"] == hashes[name] and proof["clips"].keys() == expected.keys()
        for clip, props in proof["clips"].items():
            assert props.keys() == {"Scimitar", "WoodenShield"}
            for prop, stats in props.items():
                assert stats["crossings"] == 0 and stats["samples"] == expected[clip]
                assert stats["floor"] >= .0115 and stats["largest_step"] < .035
                if clip != "Death" or prop == "Scimitar":
                    assert stats["grip_error"] < .00001


def verify_fluid(receipt, hashes):
    assert receipt.keys() == hashes.keys()
    for name, proof in receipt.items():
        assert proof["asset_sha256"] == hashes[name]
        assert proof["clips"].keys() == {row[0] for row in SPRITES[158].values()}
        rise = proof["clips"]["AcidElementalCondense"]
        assert .07 < rise["height_begin"] < .09 and 2.19 < rise["height_end"] < 2.20
        assert all(clip["samples"] == 161 and clip["minimum_floor"] >= .004 for clip in proof["clips"].values())


def verify_native(root, stage, work, scenes, family, test, inputs, forms, minimum, groups, terrain, common):
    read, digest = common["read"], common["sha"]
    folder = work / f"native-{family}-enhanced"
    path = folder / f"{family}-native.json"
    native = read(path)
    runtime = read(folder / f"{family}-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert digest(file) == runtime[f"{key}_sha256"].lower()
    assert digest(folder / test) == native["test_sha256"] and digest(scenes / inputs) == native["inputs_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert native["records"].keys() == set(forms) == native["renderers"].keys() and native["checks"] >= minimum
    for form, record in native["records"].items():
        name, body, hue, renderer, loot = FORMS[form]
        renderer_root = root if form == "knight" else stage
        assert digest(renderer_root / "Viewer/Presentation" / renderer) == native["renderers"][form]
        assert (record["class"], record["stock_weapon"], record["hue"]) == (name, "Fists", 0)
        assert record["can_move"] and not record["can_swim"] and not record["tamable"]
        assert len(record["step_delta"]) == 2 and max(map(abs, record["step_delta"])) == 1
        assert record["loot"] == loot and record["corpse"] >= 0x40000000
        assert (record["corpse_body"], record["corpse_hue"]) == (body, hue)
        verify_combat(form, body, record)
        phase, = record["phases"]
        assert phase["body"] == body and phase["asset_sha256"] == terrain[body]["hashes"]["modern"]
        cases = phase["cases"]
        expected = {(flags, kind, variation) for flags in (0, 64) for kind in TYPES[body] for variation in (0, 1, 255)}
        assert len(cases) == len(expected) and {(c["flags"], c["type"], c["variation"]) for c in cases} == expected
        for case in cases:
            mode = "0" if case["flags"] else "1"
            kind, variant = str(case["type"]), case["variation"]
            choices = groups[body][mode].get(kind, groups[body]["0"][kind])
            assert case["enhanced"] == (choices[variant % len(choices)] if variant <= 127 else case["classic"])
    return digest(path)


def verify_combat(form, body, record):
    swing = record["swing"]
    if form == "pixie":
        assert record["innocent"] and swing["spell_damage"] > 0 and swing["native_cast_actions"] == 0
        return
    packet = swing["packet"]
    assert (packet["protocol"], packet["body"], packet["serial"]) == ("classic", body, record["serial"])
    assert packet["action"] in (4, 5, 6) and swing["clip"]
    if form == "acid":
        poison = record["native_melee_poison"]
        assert poison["lethal"] and poison["damage"] > 0 and poison["target"] == swing["target"]
    if form == "troll":
        assert record["cold_damage_share"] == 25
