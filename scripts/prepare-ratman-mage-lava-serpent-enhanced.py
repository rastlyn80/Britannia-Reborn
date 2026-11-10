# SPDX-License-Identifier: GPL-3.0-or-later
"""Seal source-backed Ratman Mage and Lava Serpent animations."""

MEMBERS = {143: "0x33b1a1128465d22d", 90: "0x635c54b33a09dbc2"}
SPRITES = {
    143: {
        11: ("RatmanMageLowClawBrace", 45, "5c26580baabf038e3507b99f988987fcb53e5d652dee401f16c0381b8f2d8de1"),
        12: ("RatmanMageCrookCast", 55, "7f71a7d906f93e5900c8fcc996691978f9635dd69af9465783fcbfc39c9d4200"),
        15: ("RatmanMageGuardRecoil", 35, "b0c9dc78273a9dc4087729ce246b49835820e2cbdd1db75d8c1f4fd213791144"),
        23: ("RatmanMageHoodedRise", 45, "16ad9282e4e38a0021c71dc523b871cc19a010cc654fa1f2e54d954d2a58a3ce"),
        26: ("RatmanMageCrookWatch", 50, "9062d88d63d4b2f6cacdb04fd87f24e430f019d7c3ad54df38c5320c8d76a899"),
        27: ("RatmanMageCrookSweep", 35, "711b357b8c2b9f62d48154fa8e0859fb51af2b9aadd7f8fbc286cfe452c7f9f1"),
        28: ("RatmanMageHighAlert", 40, "1e6c342f115a62ceadec67c291c3216ccb635eee71439d7827ddf3d2e68f0708"),
    },
    90: {
        4: ("LavaSerpentCoilLash", 45, "a3ad17783933210597cc339ef01602b7e669620150f08c4af533c2cc8feca1cf"),
        23: ("LavaSerpentThreadEmergence", 55, "0622d81e7d7d7f22d7bb7b6e48745e23ce3b020ba86cb315576159a19ba9b7b8"),
        28: ("LavaSerpentCoiledAlert", 35, "40299d86fcd897420cd48eb29b7eaac7b8f34f9582b0fefcbb891349cd2724da"),
    },
}
TYPES = {143: (2, 5, 8, 11, 14, 15), 90: (8, 11, 15)}
TREATMENTS = {"original", "rounded", "modern"}
TEST = "test-ratman-mage-lava-serpent-enhanced.gd"
FORMS = {
    "mage": ("RatmanMage", 143, 0x455, "MageAI", "SourceEnhancedRatmanMageVisual.gd"),
    "serpent": ("LavaSerpent", 90, 0x8035, "MeleeAI", "SourceEnhancedLavaSerpentVisual.gd"),
}
CROOK_SHA256 = "5131e465e8d292f7552767796b1c465ec38c4989da4ef636f968710177ba8e47"
ATLAS_SHA256 = "6b6db69ff83ce1950113b4c10965a42e730eb4887fab16e11ccfb064f661f720"


def prepare_ratman_mage_lava_serpent(root, source, common, staged=None):
    read, digest = common["read"], common["sha"]
    stage = staged or root
    work = root / "work/creatures"
    scenes = work / "native-form-audit/enhanced-source-gaps/ratman-mage-lava-serpent"
    receipt = read(scenes / "terrain-receipt.json")
    assert digest(stage / "scripts" / TEST) == digest(scenes / TEST) == receipt["test_sha256"]
    terrain, renders = receipt["bodies"], read(scenes / "motion-render-receipt.json")
    assert terrain.keys() == renders.keys() == {str(body) for body in SPRITES}
    groups, rows, copies = {}, {}, {}
    for body, source_groups in SPRITES.items():
        groups.update(common["source_tables"](root, source, {body: source_groups}, TYPES[body], member_hashes=MEMBERS))
        clips = [clip for clip, _, _ in source_groups.values()]
        motion, render = terrain[str(body)], renders[str(body)]
        assert (motion["poses"], motion["falls"], motion["interrupted"]) == (465 * len(clips), 30 * len(clips), 15)
        assert (motion["routes"], motion["classic"]) == (24 * len(TYPES[body]), 18 * len(TYPES[body]))
        assert min(motion["gap"], motion["fall_gap"]) >= .0018 and motion["jump"] < .002
        assert motion["hashes"].keys() == TREATMENTS and motion["retained"] == (54 if body == 143 else 45)
        if body == 90:
            assert (motion["breath_poses"], motion["breath_falls"]) == (465, 30) and motion["rise"] > 1.5
        assert render["scene_sha256"] == motion["hashes"]["modern"]
        assert render["poses"] == 10 * (len(clips) + 1)
        assert set(render["clips"]) == {*clips, "Death" if body == 143 else "LavaSerpentFireBreath"}
        assert render["minimum_foreground_box_pixels"] >= 1000
        assets = {name: scenes / f"{body}-{name}.scn" for name in sorted(TREATMENTS)}
        rows[str(body)], local = common["fitted_row"](root / "Viewer", body, groups[body], clips, assets, motion["hashes"])
        copies.update(local)
    verify_crook(scenes, terrain["143"], read, digest)
    return rows, copies, verify_native(root, stage, work, scenes, groups, terrain, common)


def verify_crook(scenes, motion, read, digest):
    folder = scenes / "staff-reference"
    source = read(folder / "crook-source.json")["crook"]
    assert source["source"] == "Others/weapon_crook_lod2.grn" and source["sha256"] == CROOK_SHA256
    assert (source["vertices"], source["triangles"]) == (48, 92)
    assert source["textures"] == {"weapons_512.tga": ATLAS_SHA256}
    assert digest(folder / "crook.json") == "86193bb035a8a0f8e4998901b571b44bd4b1f04c341bb988ede318abe1f234b2"
    assert digest(folder / "weapons_512.png") == "52f14344eeadc7b0d1472eaa76e4eb1bec1f2293684873059132521762674166"
    proof = read(scenes / "crook-clearance.json")
    assert not proof["failed"] and proof["inspection_rate"] == 720 and proof["treatments"].keys() == TREATMENTS
    clips = {clip for clip, _, _ in SPRITES[143].values()} | {"Death"}
    for name, treatment in proof["treatments"].items():
        assert treatment["scene_sha256"] == motion["hashes"][name] and treatment["clips"].keys() == clips
        assert sum(clip["samples"] for clip in treatment["clips"].values()) == 6300
        for clip in treatment["clips"].values():
            assert clip["crossings"] == 0 and clip["floor"] >= .010 and clip["grip"] <= .00001
            assert clip["tip_step"] < .065


def verify_native(root, stage, work, scenes, groups, terrain, common):
    read, digest = common["read"], common["sha"]
    folder = work / "native-ratman-mage-lava-serpent-enhanced"
    prefix = "ratman-mage-lava-serpent-native"
    path = folder / f"{prefix}.json"
    native, runtime = read(path), read(folder / f"{prefix}-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert digest(file) == runtime[f"{key}_sha256"].lower()
    assert digest(folder / "NativeRatmanMageLavaSerpentLive.gd") == native["test_sha256"]
    assert digest(scenes / TEST) == native["inputs_sha256"]
    assert digest(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert digest(stage / "Viewer/Presentation/CreatureProjectilePresenter.gd") == native["projectile_sha256"]
    assert native["records"].keys() == FORMS.keys() and native["checks"] >= 255
    for form, record in native["records"].items():
        name, body, hue, ai, renderer = FORMS[form]
        assert digest(stage / "Viewer/Presentation" / renderer) == native["renderers"][str(body)]
        assert (record["class"], record["hue"], record["stock_weapon"], record["ai"]) == (name, 0, "Fists", ai)
        assert record["can_move"] and not any(record[field] for field in ("can_swim", "can_fly", "tamable"))
        assert len(record["step_delta"]) == 2 and max(map(abs, record["step_delta"])) == 1
        assert record["corpse"] >= 0x40000000 and (record["corpse_body"], record["corpse_hue"]) == (body, hue)
        loot, breath, combat = record["carved"], record["breath"], record["combat"]
        if body == 90:
            assert loot["hides"] >= 15 and loot["ash"] >= 3 and loot["bone"]
            assert breath["damage"] > 0 and breath["target"] > 0 and len(breath["launch_ms"]) == 2
            assert all(1050 <= elapsed <= 1800 for elapsed in breath["launch_ms"])
            packet = combat["packet"]
            assert (packet["protocol"], packet["body"], packet["serial"]) == ("classic", body, record["serial"])
            assert packet["action"] in (4, 5, 6) and combat["clip"]
        else:
            assert loot["hides"] >= 8 and loot["reagents"] >= 6 and not breath
            assert combat["damage"] > 0 and combat["target"] > 0
        phase, = record["phases"]
        assert phase["body"] == body and phase["asset_sha256"] == terrain[str(body)]["hashes"]["modern"]
        cases = phase["cases"]
        expected = {(flag, kind, variation) for flag in (0, 64) for kind in TYPES[body] for variation in (0, 1, 255)}
        assert len(cases) == len(expected) and {(c["flags"], c["type"], c["variation"]) for c in cases} == expected
        for case in cases:
            mode = "0" if case["flags"] & 64 else "1"
            kind, variation = str(case["type"]), case["variation"]
            choices = groups[body][mode].get(kind, groups[body]["0"][kind])
            assert case["enhanced"] == (choices[variation % len(choices)] if variation <= 127 else case["classic"])
    return digest(path)
