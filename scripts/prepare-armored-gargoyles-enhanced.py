# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the exact Enhanced armored gargoyle sources and local fitted scenes."""

import runpy

FOLDERS = {755: "gargoyle-destroyer-enhanced", 754: "gargoyle-enforcer-enhanced"}
MEMBERS = {755: "0xeb16abd2efa90f38", 754: "0x7c84bf0bf87ed6b1"}
CLIPS = {2: "Death", 3: "Death2", 4: "GargoyleWingRake", 5: "GargoyleDrivingPalms", 10: "Hit",
         11: "GargoyleLowSearch", 15: "GargoyleShieldingWings", 22: "GargoylePeaceWalk",
         23: "GargoyleGroundRise", 25: "GargoyleQuietHover", 26: "GargoyleNearGlance",
         27: "GargoyleWingThreat", 28: "GargoyleGuardCrouch"}
EXTRA = {755: "DestroyerHatchetCounter", 754: "EnforcerTurningSweep"}
GROUPS = {0: {-1: [4, 5, 4, 4, 4, 4], 0: [4, 5, 4], 1: [4], 2: [4], 9: [4]},
          2: {-1: [15, 15]}, 3: {-1: [2, 3]}, 4: {-1: [10]}, 5: {-1: [26, 27]},
          8: {-1: [28]}, 11: {-1: [4, 4, 4]}, 14: {-1: [11]}, 15: {-1: [23]}}
RENDERER = "SourceEnhancedArmoredGargoyleVisual.gd"
PRESENTER = "SourceEnhancedArmoredGargoyleProjectilePresenter.gd"

SPRITES = {754: {0: (45, 'fc537b95cb560e1c460ea9f93a6e08c64232cbf33be57d474c11864072bfb420'),
       1: (55, '155736ae95d8407a583215a15a9746a5a9169f4ede8ba7de9a210800dea3e97c'),
       2: (60, '0007b1c2377da847b026d3079444131843e431eb2e27aadb82e00b4cdf0f225d'),
       3: (50, '42842692e5872f1ba50ed051448e3e5eb2518ec7b6a7c9079503888d2ef7d4e2'),
       4: (35, '1e0b35e216d45f06c85264b37603af8cf2e82e07d901a3e135c9675c7f47d143'),
       5: (35, 'b945f508c70ad3d9f97acde0862aa2b87fd6eccc4dd6675dc24d4ec58b1cfd0e'),
       10: (25, 'f0b76c48c507a699c1d37c33d35f1f98b18b44556499247cedf415433b291779'),
       11: (65, 'bd95921463b7f316a875cdd8d13c5af0fee08af4ec02e8a55ec6d66f8084d47d'),
       15: (30, '50581d3826acc7f2774e8196385d8a4bfe06fdcdfc55a00ede8893aebcf18ef0'),
       19: (50, 'cad61fb5f2a2e73f8d74680d0a9536ed940acb9bcb22ac6fe57f874ea1e164fa'),
       22: (50, '8336e59101de0be087bb58fd72afe30112fe776cbf7acc669f2ec77f3bb47722'),
       23: (60, 'fa731834d3bd9ad367d4000776f1299f1f55b39d28a9c060d91147a29e637ce5'),
       24: (35, 'e213bebc65cfaa667b26a9727d3af8dbce834f419aa224e4f0595ccb2b4a80d4'),
       25: (55, '3dd8f9e9e4588952dddc22a20a1f0c732134180c4bb27be38c92f7d8829f0834'),
       26: (60, 'b9a28fc89d413829288c4f274ee69ad8bb0a9d7d66f4d0a874efd8b1b4f9e35e'),
       27: (55, '98d87d1c40b3d865db07876c53966ff781f577da4ea94c4f89738b2ba1da86ec'),
       28: (30, '8208a49c28f01e31d1731f1825cf884faa301f0ea6d443977504b3e168ed18dc')},
 755: {0: (50, '9249e90f45c97b49bd7d469713a35823d528311bb8e775f1bcadcba61b424c0e'),
       1: (50, '7c6fdc5cf11fa4e05324d65a46e3fde08c7fa0ffe94b810fda9b496b7cee4238'),
       2: (60, 'd44f5a1c2dbf412436238fc6ec3c9e1f2cce8f1dbb767bacba6cd9167029d6cf'),
       3: (50, '551f399fa1a2b1e661207c3ce88cd15126f7a9ea302f6af4f0ac21412c81ad9b'),
       4: (35, 'ef5318a419d626436de843123d2a0e7765917c0d3be12a77a7fcfd8d83295e41'),
       5: (35, 'befef93701cb3ef86bcf731a520feee0c58f2a9e98f71c6d979642dd74e456ce'),
       10: (25, '1e721d5fd558bc53d7b040beaeaa959c3952194aeea0c251e24605ac81ca7665'),
       11: (65, '01f77ca3f388a10cd9ba1bbaa30cc8cfc34f900d624d52ca85634edbd0e0fabc'),
       15: (30, '16c90511c45422ce02014d7db0cb631c221e1623c385d7a4f15f2fb9eb24045d'),
       19: (50, 'd7583396bcbc279f70cf554aac2893e7f9d25f291c98559b0a39b5bfcf791063'),
       22: (50, 'a400586cccb1723c6dceee85abb726c7a8794174279784c09f08a74455f04aab'),
       23: (60, '352f8ac19a97c4c1d27cd0b86f2c3681c84e6fd8d94035cdccda7ca91ac7f2e2'),
       24: (35, '5606201528d4a9535d0c20dae4a030ff454fd3ba8163ad09f1d9f8c8a65b4227'),
       25: (55, 'bd980e51b95c5777a53b90c287a11ee8767208fa486517409f0b1f486443b142'),
       26: (60, '41ccdea8d35c689520b5a4d372c08be9bba6d2166e0e3912ed4f677c3f2c6977'),
       27: (55, 'f7c3d732671f5d497811a13b3dd2003be9ad7fffc9861d1846320ab118110322'),
       28: (30, 'b0dd752f776f4c0a21d37a5bf2cdc990d2680269aa3f77a480d064e6f9c08888')}}


def validate_sequence(record):
    assert not record.get("unparsed_bytes")
    combat, peace, flight = record["modes"]
    assert [(mode["mode"], mode["fallback_mode"]) for mode in record["modes"]] == [(0, -1), (1, 0), (3, 1)]
    assert combat["transitions"] == [{"target_mode": 3, "group": 19}]
    for mode, groups in zip(record["modes"], ((1, 0, 24), (25, 22, 24), (19, 19, 19)), strict=True):
        assert mode["movement"] == [{"action": index, "one_handed_group": group, "two_handed_group": group}
                                    for index, group in enumerate(groups)]
    selectors = {(row["type"], row["subaction"]): row["groups"] for row in combat["new_protocol_actions"]}
    assert selectors == {(kind, subaction): groups for kind, choices in GROUPS.items()
                         for subaction, groups in choices.items()}
    assert peace["new_protocol_actions"] == [{"type": 5, "subaction": -1, "groups": [26]}]
    assert flight["new_protocol_actions"] == []


def prepare_armored_gargoyles(root, source, common, staged=None):
    read, sha = common["read"], common["sha"]
    stage = staged or root
    sequence = source / "AnimationSequence.uop"
    assert sha(sequence) == common["SEQUENCE_SHA256"]
    inspect = runpy.run_path(str(root / "scripts/uo-human-sequences.py"))["inspect"]
    decode = runpy.run_path(str(stage / "scripts/uo-enhanced-frames.py"))["read_amou"]
    records = {record["animation_ref"]: record for record in inspect(sequence, set(MEMBERS))
               if record["uop_name_hash"] == MEMBERS.get(record["animation_ref"])}
    assert records.keys() == MEMBERS.keys()
    folders = root / "work/creatures/native-form-audit/enhanced-source-gaps"
    runtime = read(folders / FOLDERS[755] / "runtime-receipt.json")
    assert runtime["checks"] == 2034
    presentation = stage / "Viewer/Presentation"
    assert runtime["renderer_sha256"] == sha(presentation / RENDERER)
    assert runtime["presenter_sha256"] == sha(presentation / PRESENTER)
    modes = {"0": {str(kind): [CLIPS[group] for group in choices[-1]] for kind, choices in GROUPS.items()
                   if kind != 0}, "1": {"5": [CLIPS[26]]}}
    attacks = {str(subaction & 255): [CLIPS[group] for group in groups] for subaction, groups in GROUPS[0].items()}
    rows, copies = {}, {}
    for body, folder_name in FOLDERS.items():
        validate_sequence(records[body])
        folder = folders / folder_name
        for group, (count, digest) in SPRITES[body].items():
            payload = source / f"ec-frame-{body}-{group}.bin"
            if not payload.is_file():
                payload = folder / payload.name
            assert sha(payload) == digest
            identity, frames = decode(payload.read_bytes())
            assert identity == body and len(frames) == count and all(frame.group == group for frame in frames)
        hashes = runtime["scenes"][str(body)]
        clips = [CLIPS[group] for group in (3, 4, 5, 11, 15, 23, 25, 26, 27, 28)] + [EXTRA[body], CLIPS[22]]
        render = read(folder / "motion-render-receipt.json")[str(body)]
        assert render["clips"] == clips and render["poses"] == 120
        assert render["minimum_foreground_box_pixels"] > 3500 and render["scene_sha256"] == hashes["modern"]
        dense = read(folder / "dense-clearance-receipt.json")
        assert dense["sample_rate"] == 240 and dense["treatments"].keys() == hashes.keys()
        for treatment, measured in dense["treatments"].items():
            assert measured["scene_sha256"] == hashes[treatment] and measured["clips"].keys() == set(clips)
            assert sum(clip["samples"] for clip in measured["clips"].values()) >= 2500
            assert all(clip["crossings"] == 0 for clip in measured["clips"].values())
            assert all(clip["maximum_supported_foot_gap"] < .02 for name, clip in measured["clips"].items()
                       if name != "Death2")
        assets = {treatment: folder / f"{body}-{treatment}.scn" for treatment in hashes}
        row, additions = common["fitted_row"](root / "Viewer", body, modes, clips, assets, hashes)
        row["attack_subactions"] = attacks
        rows[str(body)] = row
        copies.update(additions)
    return rows, copies, verify_native(root, runtime, read, sha)


def verify_native(root, runtime, read, sha):
    folder = root / "work/creatures/native-armored-gargoyles-enhanced"
    path = folder / "armored-gargoyles-native.json"
    native, engine = read(path), read(folder / "armored-gargoyles-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert sha(file) == engine[f"{key}_sha256"].lower()
    assert sha(folder / "NativeArmoredGargoylesLive.gd") == native["test_sha256"]
    assert sha(folder / "fixtures/ArmoredGargoyleFixtures.cs") == native["fixture_sha256"]
    assert all(native[key] == runtime[key] for key in ("renderer_sha256", "presenter_sha256"))
    assert native["checks"] == 94
    for body, name in ((755, "GargoyleDestroyer"), (754, "GargoyleEnforcer")):
        record = native["records"][str(body)]
        assert (record["body"], record["class"], record["hue"], record["corpse_hue"], record["stock_weapon"]) == (
            body, name, 0, 0x8035, "Fists")
        assert record["ai"] == "MageAI" and record["can_fly"] and max(map(abs, record["step"])) == 1
        assert record["corpse_gold"] > 0 and record["corpse"] >= 0x40000000
        assert record["scene_sha256"] == runtime["scenes"][str(body)]["modern"]
        ability = record["ability"]
        expected = (0xF43, "moving", 0) if body == 755 else (0x3728, "fixed_mobile", 15)
        assert len(ability["observations"]) == 2
        for event in ability["observations"]:
            assert (event["graphic"], event["kind"], event["duration"]) == expected
            assert event["source"] == record["serial"] and event["speed"] == 10 and event["clip"] == EXTRA[body]
        if body == 755:
            assert min(ability[key] for key in ("unarmed_damage", "bow_damage", "counter_damage")) > 0
            assert all(0 <= event["grip_error"] < .00001 and event["target"] > 0 for event in ability["observations"])
        else:
            assert ability["primary_damage"] > 0 and ability["secondary_damage"] > 0 and ability["mana"] >= 15
            assert all(event["target"] == 0 for event in ability["observations"])
    return sha(path)
