# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the Minotaur Scout's official references and local fitted presentation."""

import runpy


BODY = 281
MEMBER = "0xd0a9f670a911fb7f"
SPRITES = {
    4: ("ScoutDownwardClaw", 45, "1f0b56591f73161dc8daca24105d9d813da1b755901f37c016b9cbb50518a94e"),
    5: ("ScoutTurningHook", 45, "0f630af347afffe1349db3cb6090760902ec154509bb214f110ad03fa28113f2"),
    11: ("ScoutHornDip", 50, "fbec64fa6e0df783849caf6e0aee873ac96a37fa79ec939e24f88392803c4afd"),
    15: ("ScoutRaisedGuard", 40, "a227827d4ce02468e5b9cbbf55fb477b59869dfce05d76d27a08cbd395284c4f"),
    23: ("ScoutCrouchingRise", 60, "349756f8b2cf9924fe1861e28193d0b13dfb9146401e45093eeb92f189aa7fea"),
    25: ("ScoutQuietStand", 60, "d50c0706f1baee8498be6a8aae6f27767c98810b847738333da255c0446c7483"),
    26: ("ScoutLookDown", 55, "a1d8582b4e02489efdbe645c2802e2a0abafbc76290bf282c6b8ce45cb5c6704"),
    27: ("ScoutOpenChallenge", 50, "02061a68a5184c0fddce9b2def04973b4e8c38e396752da4cb6007cdc0f12bc1"),
    28: ("ScoutLowCombatStance", 50, "4457e499fa500f1235bfba165f409ba229f15afaefeae7a365cfb557f4099d78"),
}
TYPES = (2, 5, 8, 11, 14, 15)
ATTACK_SUBACTIONS = (0, 1, 2, 9, 37, 0xFFFF, 0x101, 0x1FF)
ATTACK_DISPATCHER = "Viewer/Presentation/EnhancedCreatureAttackActions.gd"
RENDERER = "SourceEnhancedMinotaurScoutVisual.gd"
FOLDER = "work/creatures/native-form-audit/enhanced-source-gaps/minotaur-scout-enhanced"


def prepare_minotaur_scout(root, source, common, staged=None):
    read, sha = common["read"], common["sha"]
    stage = staged or root
    folder = root / FOLDER
    routed = {group: entry for group, entry in SPRITES.items() if group not in (5, 25)}
    routes = common["source_tables"](root, source, {BODY: routed}, TYPES, member_hashes={BODY: MEMBER})[BODY]
    decode = runpy.run_path(str(root / "scripts/uo-enhanced-frames.py"))["read_amou"]
    for group in (5, 25):
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
    clips = [row[0] for row in SPRITES.values()]
    runtime = read(folder / "runtime-receipt.json")
    assert tuple(runtime[key] for key in ("poses", "falls", "routes", "classic", "gaits")) == (4185, 270, 144, 108, 18)
    assert (runtime["attack_routes"], runtime["attack_fallbacks"]) == (336, 192)
    assert runtime["gap"] >= .0029 and runtime["fall_gap"] >= .0019 and runtime["handoff"] < .002
    render = read(folder / "motion-render-receipt.json")[str(BODY)]
    assert render["clips"] == clips and render["poses"] == 90 and render["minimum_foreground_box_pixels"] > 7800
    assert render["scene_sha256"] == runtime["hashes"]["modern"]
    dense = read(folder / "dense-clearance-receipt.json")
    assert dense["sample_rate"] == 240 and dense["treatments"].keys() == runtime["hashes"].keys()
    for treatment, measured in dense["treatments"].items():
        assert measured["scene_sha256"] == runtime["hashes"][treatment] and measured["clips"].keys() == set(clips)
        assert sum(clip["samples"] for clip in measured["clips"].values()) == 2036
        assert all(clip["crossings"] == 0 and clip["maximum_supported_foot_gap"] < .004
                   for clip in measured["clips"].values())
    assets = {name: folder / f"{BODY}-{name}.scn" for name in runtime["hashes"]}
    row, copies = common["fitted_row"](root / "Viewer", BODY, routes, clips, assets, runtime["hashes"])
    row["attack_subactions"] = attacks
    return {str(BODY): row}, copies, verify_native(root, stage, routes, attacks, runtime["hashes"]["modern"], read, sha)


def verify_native(root, stage, routes, attacks, asset, read, sha):
    folder = root / "work/creatures/native-minotaur-scout-enhanced"
    path = folder / "minotaur-scout-native.json"
    native, engine = read(path), read(folder / "minotaur-scout-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert sha(file) == engine[f"{key}_sha256"].lower()
    assert sha(folder / "NativeMinotaurScoutLive.gd") == native["test_sha256"]
    assert sha(root / FOLDER / "test-minotaur-scout-enhanced.gd") == native["inputs_sha256"]
    assert sha(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert sha(stage / ATTACK_DISPATCHER) == native["attack_dispatcher_sha256"]
    assert native["renderers"] == {str(BODY): sha(stage / "Viewer/Presentation" / RENDERER)}
    assert native["checks"] >= 380 and native["records"].keys() == {"minotaur-scout"}
    record = native["records"]["minotaur-scout"]
    assert (record["class"], record["corpse_body"], record["hue"], record["corpse_hue"]) == ("MinotaurScout", BODY, 0, 0x8035)
    assert record["ai"] == "MeleeAI" and record["stock_weapon"] == "Fists" and record["can_move"]
    assert not record["can_swim"] and max(map(abs, record["step_delta"])) == 1
    assert record["corpse"] >= 0x40000000 and record["paralyzing_blow"]
    combat = record["combat"]
    assert combat["damage"] > 0 and combat["packet"]["protocol"] == "classic" and combat["packet"]["body"] == BODY
    assert combat["paralyzed"]
    assert record["carved"]["gold"] > 0
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
    return sha(path)
