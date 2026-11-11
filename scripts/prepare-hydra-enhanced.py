# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the Hydra's official references and local fitted presentation."""

import runpy


BODY = 265
MEMBER = "0x1e91857b69064898"
SPRITES = {
    4: ("HydraBlueHeadSnap", 55, "a3e481181711b37acbcea8436263878a57b154dedd55413ece630b14ccf58483"),
    5: ("HydraCascadeLash", 55, "f6a31efcb94d345f54c71597d2e05c42f0373e26984daba14deb9a4549709364"),
    11: ("HydraTailBrace", 50, "e05d892d111aa14f69f93537be38ed98d5fcc09b7df51b425de85737d95f1dbf"),
    12: ("HydraCentralThrust", 55, "2a270ecb34f935f421bb67ecf0b186e7cdd117c3db0e71ef8ce5c98b38a30322"),
    15: ("HydraFiveHeadCoil", 40, "69a02ffd26839a30880450ccaad7476925e6893ad2e999801908391257bfa8dc"),
    23: ("HydraUnfurl", 60, "a1bc4d58740097a021c6a9a0d518a6a9ae215a56c0fb15c214e4e3cb3a0d7873"),
    25: ("HydraQuietCoil", 50, "786c86fdddc1b9e815c30d844e781742a6bd6b294e7694224b609aaf8ef2bc25"),
    26: ("HydraWatchfulHeads", 55, "11afd745c24cc54fd151883fbb3cf32109856dfbfce189cb2a8ed187db3e0b16"),
    27: ("HydraSpreadThreat", 50, "5a67f6dccf5c84dd1812823dc2878c93e0033631c342a3ddce67436e1e58c01f"),
    28: ("HydraLowGuard", 35, "81c731131c6aa069fa70d2fa9dcd15a386c35ec6ce7ce8aa6e0195a68d2a2bd6"),
}
TYPES = (2, 5, 8, 11, 14, 15)
ATTACK_SUBACTIONS = (0, 1, 2, 9, 37, 0xFFFF, 0x101, 0x1FF)
ATTACK_DISPATCHER = "Viewer/Presentation/EnhancedCreatureAttackActions.gd"
RENDERER = "SourceEnhancedHydraVisual.gd"
FOLDER = "work/creatures/native-form-audit/enhanced-source-gaps/hydra-enhanced"


def prepare_hydra(root, source, common, staged=None):
    read, sha = common["read"], common["sha"]
    stage = staged or root
    folder = root / FOLDER
    separately_routed = (4, 5, 25)
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
    clips = [row[0] for row in SPRITES.values()] + ["HydraFireBreath"]
    runtime = read(folder / "runtime-receipt.json")
    assert tuple(runtime[key] for key in ("poses", "falls", "routes", "classic", "gaits")) == (5115, 330, 144, 108, 18)
    assert (runtime["attack_routes"], runtime["attack_fallbacks"]) == (336, 192)
    assert runtime["gap"] >= .0029 and runtime["fall_gap"] >= .0019 and runtime["handoff"] < .002
    render = read(folder / "motion-render-receipt.json")[str(BODY)]
    assert render["clips"] == clips and render["poses"] == 110 and render["minimum_foreground_box_pixels"] > 4700
    assert render["scene_sha256"] == runtime["hashes"]["modern"]
    hues = read(folder / "hue-render-receipt.json")
    assert hues["scene_sha256"] == runtime["hashes"]["modern"]
    assert hues["shader_sha256"] == sha(stage / "Viewer/Presentation/HydraScaleSurface.gdshader")
    assert hues["hues"].keys() == {"0000", "08fd", "0455", "8035"}
    assert all(0 <= case["freeze_difference"] < .02 for case in hues["hues"].values())
    assert hues["hues"]["08fd"]["difference_from_neutral"] > .03
    assert hues["hues"]["0455"]["difference_from_neutral"] > .03
    assert .001 < hues["hues"]["8035"]["difference_from_neutral"] < .15
    dense = read(folder / "dense-clearance-receipt.json")
    assert dense["sample_rate"] == 240 and dense["treatments"].keys() == runtime["hashes"].keys()
    for treatment, measured in dense["treatments"].items():
        assert measured["scene_sha256"] == runtime["hashes"][treatment] and measured["clips"].keys() == set(clips)
        assert sum(clip["samples"] for clip in measured["clips"].values()) == 2722
        assert all(clip["minimum_head_separation"] > .95 and clip["minimum_floor_gap"] > .0039
                   and clip["maximum_trunk_or_tail_gap"] < .004
                   for clip in measured["clips"].values())
    assets = {name: folder / f"{BODY}-{name}.scn" for name in runtime["hashes"]}
    row, copies = common["fitted_row"](root / "Viewer", BODY, routes, clips, assets, runtime["hashes"])
    row["attack_subactions"] = attacks
    return {str(BODY): row}, copies, verify_native(root, stage, routes, attacks, runtime["hashes"]["modern"], read, sha)


def verify_native(root, stage, routes, attacks, asset, read, sha):
    folder = root / "work/creatures/native-hydra-enhanced"
    path = folder / "hydra-native.json"
    native, engine = read(path), read(folder / "hydra-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert sha(file) == engine[f"{key}_sha256"].lower()
    assert sha(folder / "NativeHydraLive.gd") == native["test_sha256"]
    assert sha(root / FOLDER / "test-hydra-enhanced.gd") == native["inputs_sha256"]
    assert sha(root / "Viewer/Presentation/EnhancedCreatureActions.gd") == native["dispatcher_sha256"]
    assert sha(stage / ATTACK_DISPATCHER) == native["attack_dispatcher_sha256"]
    assert native["renderers"] == {str(BODY): sha(stage / "Viewer/Presentation" / RENDERER)}
    presentation = stage / "Viewer/Presentation"
    assert native["presenter_sha256"] == sha(presentation / "SourceEnhancedHydraProjectilePresenter.gd")
    assert native["material_sha256"] == sha(presentation / "HydraHeadMaterial.gd")
    assert native["shader_sha256"] == sha(presentation / "HydraScaleSurface.gdshader")
    assert native["checks"] >= 750 and native["records"].keys() == {"hydra", "abscess"}
    for name, native_class, native_hue, corpse_hue in (("hydra", "Hydra", 0, 0x8035), ("abscess", "Abscess", 0x8FD, 0x455)):
        verify_form(native["records"][name], native_class, native_hue, corpse_hue, asset, routes, attacks)
    return sha(path)


def verify_form(record, native_class, native_hue, corpse_hue, asset, routes, attacks):
    is_abscess = native_class == "Abscess"
    assert (record["class"], record["corpse_body"], record["hue"], record["corpse_hue"]) == (
        native_class, BODY, native_hue, corpse_hue)
    assert record["ai"] == "MeleeAI" and record["stock_weapon"] == "Fists" and record["can_move"]
    assert not record["can_swim"] and max(map(abs, record["step_delta"])) == 1
    assert record["corpse"] >= 0x40000000 and record["paragon"] == is_abscess
    combat = record["combat"]
    windup, effect = combat["windup"], combat["effect"]
    assert windup["serial"] == effect["source"] == record["serial"] and windup["body"] == BODY
    assert (windup["protocol"], windup["action"], windup["frames"], windup["repeat_count"], windup["reverse"],
            windup["repeat"], windup["delay"]) == ("classic", 12, 5, 1, False, False, 0)
    assert (effect["graphic"], effect["kind"], effect["target"]) == (0x36D4, "moving", combat["target"])
    assert combat["damage"] > 0 and combat["clip"] == "HydraFireBreath"
    assert len(combat["delays_ms"]) == 2 and all(1180 <= delay < 1550 for delay in combat["delays_ms"])
    assert record["carved"]["gold"] > 0 and record["carved"]["hydra_scale"]
    assert record["carved"]["abscess_tail"] == is_abscess
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
