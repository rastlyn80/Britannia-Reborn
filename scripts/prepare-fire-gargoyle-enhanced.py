# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the Fire Gargoyle's official references and local fitted presentation."""

import runpy


BODY = 130
MEMBER = "0xd83f64ba26d623e2"
SPRITES = {
    4: ("FireGargoyleOverheadRake", 30, "98a3d816677a4c0996c0dfdcef30ac0b031f251513705b2a7321229b8fe38114"),
    5: ("FireGargoyleSwoopingClaw", 35, "1420b04b0147de4418a39be518f5a19c58d868541124d8a6f006b2c1759f42ce"),
    11: ("FireGargoyleAshSearch", 55, "44b652c2766ff72264d2d82470c7710dac475616945e9aa2391e18496bf5498f"),
    15: ("FireGargoyleGuard", 30, "bd374045025117ca85d29408e9cb7b0472ece69693fd103494224a16ded58b6b"),
    23: ("FireGargoyleRise", 55, "6f80efc03309de7caac2715179d8fb7a4441618eba0af2d79efd2434b0627b9c"),
    25: ("ReadyStance", 50, "dd6158723d9f44890e1d6671a928514ad128f1c7998881c6b15e96a98e831e51"),
    26: ("FireGargoyleRest", 40, "5626aaf475bddf28ed263a9fccf552d9d062bc418998f2b1f0f99e2ea1211568"),
    27: ("FireGargoyleFlare", 55, "1c257e335bfad4274209d8f25e03a25f4f3dcb8fa02751a2bbd76f0f8632003f"),
    28: ("FireGargoyleRecoil", 30, "ffb451524b41ea73523493fd3e9e39ee99ecf6320582d1134c9f180d1917c26d"),
}
TYPES = (2, 5, 8, 11, 14, 15)
ATTACK_SUBACTIONS = (0, 1, 2, 9, 37, 0xFFFF, 0x101, 0x1FF)
ATTACK_DISPATCHER = "Viewer/Presentation/EnhancedCreatureAttackActions.gd"
RENDERER = "SourceEnhancedFireGargoyleVisual.gd"
FOLDER = "work/creatures/native-form-audit/enhanced-source-gaps/fire-gargoyle-enhanced"


def prepare_fire_gargoyle(root, source, common, staged=None):
    read, sha = common["read"], common["sha"]
    stage = staged or root
    folder = root / FOLDER
    separately_routed = (5, 25)
    routed = {group: entry for group, entry in SPRITES.items() if group not in separately_routed}
    routes = common["source_tables"](root, source, {BODY: routed}, TYPES, member_hashes={BODY: MEMBER})[BODY]
    decode = runpy.run_path(str(root / "scripts/uo-enhanced-frames.py"))["read_amou"]
    for group in separately_routed:
        _, count, digest = SPRITES[group]
        payload = source / f"ec-frame-{BODY}-{group}.bin"
        assert sha(payload) == digest
        identity, frames = decode(payload.read_bytes())
        assert identity == BODY and len(frames) == count and all(frame.group == group for frame in frames)
    inspect = runpy.run_path(str(root / "scripts/uo-human-sequences.py"))["inspect"]
    named, = (row for row in inspect(source / "AnimationSequence.uop", {BODY}) if row["uop_name_hash"] == MEMBER)
    combat, peace = named["modes"]
    assert combat["mode"] == 0 and peace["mode"] == 1 and peace["fallback_mode"] == 0
    assert peace["movement"][0] == {"action": 0, "one_handed_group": 25, "two_handed_group": 25}
    assert not any(row["type"] == 0 for row in peace["new_protocol_actions"])
    subactions = {row["subaction"]: row["groups"] for row in combat["new_protocol_actions"] if row["type"] == 0}
    assert subactions == {-1: [4, 5, 4, 4, 4, 4], 0: [4, 5, 4], 1: [4], 2: [4], 9: [4]}
    attacks = {str(key & 255): [SPRITES[group][0] for group in values] for key, values in subactions.items()}
    clips = [SPRITES[group][0] for group in (4, 5, 11)] + ["FireGargoyleFireBreath"]
    runtime = read(folder / "runtime-receipt.json")
    assert tuple(runtime[key] for key in ("routing", "poses", "falls", "fall_poses")) == (561, 1860, 120, 1320)
    assert runtime["gap"] >= .0016 and runtime["fall_gap"] >= .0016 and runtime["jump"] < .002
    render = read(folder / "motion-render-receipt.json")[str(BODY)]
    assert render["clips"] == clips and render["poses"] == 40 and render["minimum_foreground_box_pixels"] > 5400
    assert render["scene_sha256"] == runtime["hashes"]["modern"]
    dense = read(folder / "dense-clearance-receipt.json")
    assert dense["sample_rate"] == 240 and dense["treatments"].keys() == runtime["hashes"].keys()
    for treatment, measured in dense["treatments"].items():
        assert measured["scene_sha256"] == runtime["hashes"][treatment] and measured["clips"].keys() == set(clips)
        assert sum(clip["samples"] for clip in measured["clips"].values()) == 1107
        assert all(clip["crossings"] == 0 and clip["maximum_supported_foot_gap"] < .004
                   for clip in measured["clips"].values())
    assets = {name: folder / f"{BODY}-{name}.scn" for name in runtime["hashes"]}
    row, copies = common["fitted_row"](root / "Viewer", BODY, routes, clips, assets, runtime["hashes"])
    row["attack_subactions"] = attacks
    return {str(BODY): row}, copies, verify_native(root, stage, routes, attacks, runtime["hashes"]["modern"], read, sha)


def verify_native(root, stage, routes, attacks, asset, read, sha):
    folder = root / "work/creatures/native-fire-gargoyle-enhanced"
    path = folder / "fire-gargoyle-native.json"
    native, engine = read(path), read(folder / "fire-gargoyle-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert sha(file) == engine[f"{key}_sha256"].lower()
    assert sha(folder / "NativeFireGargoyleLive.gd") == native["test_sha256"]
    assert sha(root / FOLDER / "test-fire-gargoyle-enhanced.gd") == native["inputs_sha256"]
    assert sha(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert sha(stage / ATTACK_DISPATCHER) == native["attack_dispatcher_sha256"]
    assert native["renderers"] == {str(BODY): sha(stage / "Viewer/Presentation" / RENDERER)}
    presentation = stage / "Viewer/Presentation"
    assert native["presenter_sha256"] == sha(presentation / "SourceEnhancedFireBreathProjectilePresenter.gd")
    assert native["shader_sha256"] == sha(presentation / "FireGargoyleEmberSurface.gdshader")
    assert native["checks"] >= 390 and native["records"].keys() == {"fire-gargoyle"}
    verify_form(native["records"]["fire-gargoyle"], asset, routes, attacks)
    return sha(path)


def verify_form(record, asset, routes, attacks):
    assert (record["class"], record["corpse_body"], record["hue"], record["corpse_hue"]) == (
        "FireGargoyle", BODY, 0, 0x8035)
    assert record["ai"] == "MageAI" and record["stock_weapon"] == "Fists" and record["can_move"]
    assert record["can_fly"] and not record["can_swim"] and max(map(abs, record["step_delta"])) == 1
    assert record["corpse"] >= 0x40000000 and record["breath_ability"]
    combat = record["combat"]
    windup, effect = combat["windup"], combat["effect"]
    assert windup["serial"] == effect["source"] == record["serial"] and windup["body"] == BODY
    assert (windup["protocol"], windup["action"], windup["frames"], windup["repeat_count"], windup["reverse"],
            windup["repeat"], windup["delay"]) == ("classic", 12, 5, 1, False, False, 0)
    assert (effect["graphic"], effect["kind"], effect["target"]) == (0x36D4, "moving", combat["target"])
    assert combat["damage"] > 0 and combat["clip"] == "FireGargoyleFireBreath"
    assert len(combat["delays_ms"]) == 2 and all(1180 <= delay < 1550 for delay in combat["delays_ms"])
    spell = combat["spell"]
    assert spell["cast"].endswith("Spell") and spell["range_at_damage"] > 1 and spell["damage_during_combat"] > 0
    assert record["carved"]["gold"] > 0 and record["carved"]["name"] == "a charred corpse"
    phase, = record["phases"]
    assert phase["asset_sha256"] == asset
    expected = {(flags, kind, 0, variant) for flags in (0, 64) for kind in TYPES for variant in (0, 1, 2, 255)}
    expected |= {(flags, 0, subaction, variant) for flags in (0, 64) for subaction in ATTACK_SUBACTIONS
                 for variant in (0, 1, 2, 255)}
    cases = phase["cases"]
    assert len(cases) == len(expected)
    assert {(row["flags"], row["type"], row["subaction"], row["variation"]) for row in cases} == expected
    for case in cases:
        mode, kind, variant = ("0" if case["flags"] else "1"), str(case["type"]), case["variation"]
        if kind == "0":
            choices = attacks.get(str(case["subaction"] & 0xFF), attacks["255"])
        else:
            choices = routes[mode].get(kind, routes["0"][kind])
        assert case["enhanced"] == (choices[variant % len(choices)] if variant <= 127 else case["classic"])
