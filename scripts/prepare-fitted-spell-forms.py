# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify and install the two source-fitted player spell models from an isolated viewer."""

import argparse
import hashlib
import json
from pathlib import Path
import runpy
import shutil


ROOT = Path(__file__).resolve().parents[1]
TRIAL = ROOT / "work/creatures/native-form-audit"
ISOLATED = TRIAL / "isolated-client"
VIEWER = ROOT / "Viewer"
REL_INDEX = Path("local-art/creatures/accepted-index.json")
EVIDENCE = TRIAL / "next-original-forms"
RECEIPT = EVIDENCE / "accepted-fitted-forms.json"
SEALED = EVIDENCE / "accepted-proof"
BODIES = {285: (301, "spell_form_reaper", "ReaperFormSpell"),
          705: (14, "spell_form_stone", "StoneFormSpell")}
TREATMENTS = {"original", "rounded", "modern"}


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def write(path, value):
    pending = path.with_suffix(path.suffix + ".pending")
    pending.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
    pending.replace(path)


def rows_for(manifest):
    return [row for row in manifest["entries"] if row.get("fitted_spell_form_source")]


def source_frames(data):
    ledger = runpy.run_path(str(ROOT / "scripts/build-creature-actions.py"))
    uop = runpy.run_path(str(ROOT / "scripts/uo-human-sequences.py"))
    mul, _, _ = ledger["original_mul_groups"](data, {285})
    stone, _ = ledger["original_frame_groups"](
        data, {705}, type("Reader", (), {"payloads": staticmethod(uop["payloads"])})
    )
    assert {row["group"] for row in mul} == {0, 1, 2, 3, 4, 5, 6, 10, 11, 15, 16, 17, 18}
    assert {row["group"] for row in stone} == {0, 1, 2, 3, 4, 5, 10, 11, 12, 15, 22, 23, 24, 25, 26, 27, 28}
    assert all(len(row["directions"]) == 5 and row["archive"] == "anim5.mul" for row in mul)
    return {285: mul, 705: stone}


def validate_rows(rows, manifest, art_viewer, data):
    frames = source_frames(data)
    by_body = {int(identity["body"]): row for row in manifest["entries"] for identity in row["bodies"]}
    assert [row["bodies"][0]["body"] for row in rows] == list(BODIES)
    for row in rows:
        identity, = row["bodies"]
        body = identity["body"]
        donor, kind, _ = BODIES[body]
        evidence = row["fitted_spell_form_source"]
        assert row["status"] == "validated" and row["kind"] == kind
        assert row["presentation_script"] == "res://Presentation/FittedSpellFormVisual.gd"
        assert row["presentation_script_sha256"] == sha(VIEWER / "Presentation/FittedSpellFormVisual.gd")
        assert evidence["donor_body"] == donor and evidence["source_frame_groups"] == frames[body]
        assert evidence["donor_asset_sha256"] == {
            treatment: sha(VIEWER / path.removeprefix("res://"))
            for treatment, path in by_body[donor]["assets"].items()
        }
        native, = identity["native_sources"]
        assert sha(ROOT / "Server/ModernUO" / native["path"]) == native["sha256"]
        assert set(row["assets"]) == TREATMENTS
        for treatment, path in row["assets"].items():
            assert path == f"res://local-art/creatures/next-spell-forms/{body}-{treatment}.scn"
            assert sha(art_viewer / path.removeprefix("res://")) == row["asset_sha256"][treatment]


def trial_files():
    return {
        "index.json": ISOLATED / REL_INDEX,
        "original-forms.json": TRIAL / "original-forms.json",
        "original-forms-runtime.json": TRIAL / "original-forms-runtime.json",
        "pose-evidence.json": EVIDENCE / "pose-evidence.json",
        "NativeOriginalFormsLive.gd": ISOLATED / "Network/NativeOriginalFormsLive.gd",
    }


def validate_proof(files, check_client):
    live_path = files["original-forms.json"]
    prepared = files["index.json"]
    terrain_path = files["pose-evidence.json"]
    runtime_path = files["original-forms-runtime.json"]
    live = read(live_path)
    terrain = read(terrain_path)
    assert live["index_sha256"] == terrain["index_sha256"] == sha(prepared)
    assert live["checks"] == 53 and [record["body"] for record in live["records"]] == list(BODIES)
    assert live["test_sha256"] == sha(files["NativeOriginalFormsLive.gd"])
    assert live["renderer_sha256"] == sha(VIEWER / "Presentation/FittedSpellFormVisual.gd")
    if check_client:
        assert live["game_sha256"] == sha(VIEWER / "Network/GameSession.gd")
    for record in live["records"]:
        body = record["body"]
        _, kind, spell = BODIES[body]
        assert (record["kind"], record["spell"]) == (kind, spell)
        assert record["native_state"] == ["UCFORM", "state", str(body), "0", spell]
        assert record["movement"][0] != record["movement"][1] and record["corpse"] > 0
    assert terrain["native_action_decodes"] == 207 and terrain["finite_ground_poses"] == 5175
    assert terrain["corpse_hues"] == 6 and terrain["minimum_ground_gap"] >= -0.004
    runtime = read(runtime_path)
    assert runtime["report_sha256"].lower() == sha(live_path)
    assert runtime["server_sha256"].lower() == sha(ROOT / "Server/runtime/Server.dll")
    assert runtime["content_sha256"].lower() == sha(ROOT / "Server/runtime/Assemblies/UOContent.dll")
    return {"trial": sha(live_path), "terrain": sha(terrain_path),
            "runtime": sha(runtime_path), "prepared": sha(prepared)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--activate", action="store_true")
    mode.add_argument("--check-active", action="store_true")
    parser.add_argument("--data", type=Path)
    args = parser.parse_args()
    data = args.data or Path(read(ROOT / "Server/runtime/Configuration/modernuo.json")["dataDirectories"][0])
    index = VIEWER / REL_INDEX
    active = read(index)
    files = trial_files()
    if args.check_active:
        files = {name: SEALED / name for name in files}
    candidate = read(files["index.json"])
    fitted = rows_for(candidate)
    if args.check_active:
        assert [row.get("stone_mode_predecessor", row) for row in rows_for(active)] == fitted
        validate_rows(fitted, active, VIEWER, data)
        assert validate_proof(files, False) == read(RECEIPT)
    else:
        assert not rows_for(active), "The two spell forms are already active"
        assert [row for row in candidate["entries"] if not row.get("fitted_spell_form_source")] == active["entries"]
        validate_rows(fitted, active, ISOLATED, data)
        proof = validate_proof(files, True)
        for row in fitted:
            for path in row["assets"].values():
                relative = path.removeprefix("res://")
                destination = VIEWER / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                pending = destination.with_suffix(".scn.pending")
                shutil.copyfile(ISOLATED / relative, pending)
                pending.replace(destination)
        backup = EVIDENCE / "accepted-index-before-fitted-forms.json"
        if not backup.exists():
            shutil.copyfile(index, backup)
        SEALED.mkdir(parents=True, exist_ok=True)
        for name, path in files.items():
            shutil.copyfile(path, SEALED / name)
        write(RECEIPT, proof)
        write(index, dict(active, entries=active["entries"] + fitted))
    print("FITTED SPELL FORMS: both native bodies, isolated gameplay and terrain/corpse evidence")


if __name__ == "__main__":
    main()
