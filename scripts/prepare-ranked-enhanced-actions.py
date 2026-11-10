# SPDX-License-Identifier: GPL-3.0-or-later
"""Seal the ranked Enhanced add-on against exact official sprite and local trial inputs."""

import hashlib
import json
from pathlib import Path
import runpy


SEQUENCE_SHA256 = "d474b11e3f7e68d3651e3feea1d063ab8f20b77fa0c92fec1fa1eb473a14c7d6"
SPRITES = {
    16: {
        23: ("WaterEmerge", 40, "d528751b98f5d98dd68a3dabe351250864fcc34b8e2c76199a23e3f67acaf9d4"),
        28: ("WaterAlert", 25, "ea93e916f1132d6359a49700575fb7233dbf514114161c327e99a6852dd79c5a"),
    },
    17: {
        23: ("OrcRise", 40, "8c612f19c45aef94a4a0efe44e63eb9eb4cc07244e45b7fe605ce7d72ef4f6f5"),
        28: ("OrcAlert", 40, "c9676e34d256aea630cba2d1d7f01b5119335584255ab3616334a8e00d2bb9b0"),
    },
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def source_tables(root, source, sprites, types, flight_fallback=False, member_hashes=None, flight_mode_fallback=0):
    scripts = root / "scripts"
    sequence = source / "AnimationSequence.uop"
    assert sha(sequence) == SEQUENCE_SHA256
    inspect = runpy.run_path(str(scripts / "uo-human-sequences.py"))["inspect"]
    decode = runpy.run_path(str(scripts / "uo-enhanced-frames.py"))["read_amou"]
    tables = {}
    for record in inspect(sequence, set(sprites)):
        body = record["animation_ref"]
        member = (member_hashes or {}).get(body)
        if member is not None and record["uop_name_hash"] != member:
            continue
        assert not record.get("unparsed_bytes")
        table = {}
        seen = set()
        flight_mode = False
        for mode in record["modes"]:
            number = mode["mode"]
            if number == 3 and flight_fallback:
                assert not flight_mode and mode["fallback_mode"] == flight_mode_fallback
                assert not any(row["type"] in types for row in mode["new_protocol_actions"])
                flight_mode = True
                continue
            assert number in (0, 1) and str(number) not in table
            assert mode["fallback_mode"] == (-1 if number == 0 else 0)
            actions = {}
            for row in mode["new_protocol_actions"]:
                action = str(row["type"])
                if row["type"] not in types:
                    continue
                assert row["subaction"] == -1 and action not in actions
                actions[action] = [sprites[body][group][0] for group in row["groups"]]
                seen.update(row["groups"])
            table[str(number)] = actions
        assert flight_mode == flight_fallback and table.keys() == {"0", "1"} and seen == sprites[body].keys()
        for group, (_, count, digest) in sprites[body].items():
            payload = source / f"ec-frame-{body}-{group}.bin"
            assert sha(payload) == digest
            identity, frames = decode(payload.read_bytes())
            assert identity == body and len(frames) == count and all(frame.group == group for frame in frames)
        tables[body] = table
    assert tables.keys() == sprites.keys()
    return tables


def base_rows(viewer):
    rows = {}
    for index in (viewer / "Art/Creatures/index.json", viewer / "local-art/creatures/accepted-index.json"):
        for row in read(index)["entries"]:
            if row["status"] == "validated":
                for identity in row["bodies"]:
                    rows[identity["body"]] = row
    return rows


def fitted_row(viewer, body, groups, grounded, scenes, candidate_hashes):
    base = base_rows(viewer)[body]
    base_assets = base.get("assets") or {
        treatment: f"res://local-art/creatures/{base['kind']}-{treatment}.gltf"
        for treatment in base.get("asset_sha256", {})
    }
    digests = {treatment: sha(viewer / asset.removeprefix("res://")) for treatment, asset in base_assets.items()}
    assert digests == base.get("asset_sha256", digests)
    assert digests.keys() == candidate_hashes.keys() == scenes.keys() and "modern" in digests
    row = {"kind": base["kind"], "base_sha256": digests, "groups": groups, "grounded": grounded, "assets": {}}
    copies = {}
    for treatment, scene in scenes.items():
        digest = sha(scene)
        assert digest == candidate_hashes[treatment]
        target = f"local-art/creatures/enhanced-creature-actions/{body}-{treatment}.scn"
        row["assets"][treatment] = {"path": "res://" + target, "sha256": digest}
        copies[viewer / target] = scene
    return row, copies


def prepare_ranked(root, source):
    scripts, viewer = root / "scripts", root / "Viewer"
    work = root / "work/creatures"
    scenes = work / "native-form-audit/enhanced-source-gaps/amou"
    tables = source_tables(root, source, SPRITES, (8, 15))
    candidate = read(scenes / "ranked-enhanced-candidate.json")
    assert candidate["test_sha256"] == sha(scripts / "test-ranked-enhanced.gd")
    assert (candidate["routes"], candidate["classic_compatibility"], candidate["corpse_hues"],
            candidate["orc_terrain_poses"]) == (48, 48, 6, 558)
    assert candidate["orc_terrain_minimum"] > .0004
    assert candidate["motion"]["water_morph"]["minimum_flat_clearance"] >= .002
    assert candidate["motion"]["water_morph"]["interrupted_transitions"] == 3

    native_folder = work / "native-ranked-actions"
    native_path = native_folder / "ranked-actions-native.json"
    native = read(native_path)
    receipt = read(native_folder / "ranked-actions-native-runtime.json")
    assert sha(native_path) == receipt["report_sha256"].lower()
    assert sha(root / "Server/runtime/Server.dll") == receipt["server_sha256"].lower()
    assert sha(root / "Server/runtime/Assemblies/UOContent.dll") == receipt["content_sha256"].lower()
    assert native["test_sha256"] == sha(native_folder / "NativeRankedActionsLive.gd")
    assert native["checks"] == 79 and native["records"].keys() == {"orc", "water"}

    baseline = base_rows(viewer)
    rows = {}
    copies = {}
    for body, name in ((16, "water"), (17, "orc")):
        base = baseline[body]
        table = tables[body]
        report = native["records"][name]
        assert report["body"] == body and len(report["cases"]) == 10
        assert {(case["type"], case["variation"]) for case in report["cases"]} == {
            (action, variant) for action in (8, 15) for variant in (0, 1, 127, 128, 255)
        }
        for case in report["cases"]:
            variant = case["variation"]
            action = str(case["type"])
            mode = "0" if case["flags"] & 0x40 else "1"
            options = table[mode].get(action, table["0"][action])
            assert case["default"] == ("Pillage" if action == "8" else "")
            assert case["enhanced"] == (options[variant % len(options)] if variant <= 127 else case["default"])
        digests = {treatment: sha(viewer / asset.removeprefix("res://"))
                   for treatment, asset in base["assets"].items()}
        assert digests == base.get("asset_sha256", digests)
        assert candidate["scene_sha256"][str(body)].keys() == digests.keys()
        row = {"kind": base["kind"], "base_sha256": digests, "groups": table,
               "grounded": ["OrcRise", "OrcAlert"] if body == 17 else [], "assets": {}}
        for treatment in digests:
            scene = scenes / f"{name}-{treatment}.scn"
            digest = sha(scene)
            assert digest == candidate["scene_sha256"][str(body)][treatment]
            if treatment == "modern":
                assert digest == report["asset_sha256"]
            target = f"local-art/creatures/enhanced-creature-actions/{body}-{treatment}.scn"
            row["assets"][treatment] = {"path": "res://" + target, "sha256": digest}
            copies[viewer / target] = scene
        rows[str(body)] = row
    return rows, copies, sha(native_path)
