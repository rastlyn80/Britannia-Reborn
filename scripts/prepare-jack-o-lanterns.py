# SPDX-License-Identifier: GPL-3.0-or-later
"""Check the Jack O' Lantern source and isolated proofs before local activation."""
import argparse
import hashlib
import json
from pathlib import Path
import runpy
import shutil

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / "work/creatures/native-form-audit"
ISOLATED = WORK / "isolated-client"
EVIDENCE = WORK / "jack-o-lanterns"
SEALED = EVIDENCE / "accepted-proof"
VIEWER = ROOT / "Viewer"
INDEX = Path("local-art/creatures/accepted-index.json")
RECEIPT = EVIDENCE / "accepted-jack-o-lanterns.json"
REGISTRY_KEY = "jack_o_lantern_source"
RENDERER = "Presentation/JackOLanternVisual.gd"
FLAME = "Presentation/JackOLanternFlame.gdshader"
SCAN = Path("Art/Objaverse/pumpkin/pumpkin.glb")
BODIES = {1246, 1247}


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".pending")
    temp.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    temp.replace(path)


def rows_in(index):
    return [row for row in index["entries"] if row.get(REGISTRY_KEY)]


def proof_paths():
    return {
        "index.json": ISOLATED / INDEX,
        "jack-visuals.json": WORK / "jack-visuals.json",
        "jack-visuals-runtime.json": WORK / "jack-visuals-runtime.json",
        "NativeJackVisuals.gd": ISOLATED / "Network/NativeJackVisuals.gd",
        "presentation.json": EVIDENCE / "presentation.json",
        "TestJackOLanterns.gd": EVIDENCE / "TestJackOLanterns.gd",
        "jack-o-lanterns.json": WORK / "jack-o-lanterns.json",
        "jack-o-lanterns-runtime.json": WORK / "jack-o-lanterns-runtime.json",
    }


def verify_source(rows, viewer, data):
    ledger = runpy.run_path(str(ROOT / "scripts/build-creature-actions.py"))
    reader = runpy.run_path(str(ROOT / "scripts/uo-human-sequences.py"))
    frames, _ = ledger["original_frame_groups"](
        data, BODIES, type("Reader", (), {"payloads": staticmethod(reader["payloads"])})
    )
    sequences = {entry["animation_ref"]: entry for entry in reader["inspect"](data / "AnimationSequence.uop", BODIES)}
    assert {row["bodies"][0]["body"] for row in rows} == BODIES and len(rows) == 2
    for row in rows:
        body, = row["bodies"]
        native, = body["native_sources"]
        assert body["native_class"] == "PumpkinHead"
        assert digest(ROOT / "Server/ModernUO" / native["path"]) == native["sha256"]
        original = row[REGISTRY_KEY]
        assert original["frame_groups"] == [group for group in frames if group["body"] == body["body"]]
        assert len(original["frame_groups"]) == 9
        assert {group["archive"] for group in original["frame_groups"]} == {"AnimationFrame2.uop"}
        assert original["sequence"] == sequences[body["body"]]
        assert row["status"] == "validated" and row["presentation_script"] == "res://" + RENDERER
        assert digest(VIEWER / RENDERER) == row["presentation_script_sha256"]
        assert digest(VIEWER / FLAME) == original["flame_sha256"]
        assert digest(VIEWER / SCAN) == original["licensed_scan_sha256"]
        notice, = [item for item in read(VIEWER / "Art/Objaverse/manifest.json")["assets"] if item["id"] == "pumpkin"]
        assert original["licensed_scan"] == notice
        assets = row["assets"]
        assert set(assets) == {"original", "rounded", "modern"}
        for treatment, path in assets.items():
            assert path == f"res://local-art/creatures/jack-o-lanterns/{body['body']}.scn"
            assert digest(viewer / path.removeprefix("res://")) == row["asset_sha256"][treatment]


def verify_proof(paths):
    native = read(paths["jack-visuals.json"])
    lift = read(paths["jack-o-lanterns.json"])
    offline = read(paths["presentation.json"])
    assert native["index_sha256"] == offline["index_sha256"] == digest(paths["index.json"])
    assert native["test_sha256"] == digest(paths["NativeJackVisuals.gd"])
    assert offline["test_sha256"] == digest(paths["TestJackOLanterns.gd"])
    assert native["checks"] >= 36 and {entry["body"] for entry in native["records"]} == BODIES
    assert len(native["records"]) == 2
    for entry in native["records"]:
        assert entry["movement"][0] != entry["movement"][1] and entry["corpse"] > 0
        assert any(action["clip"] in {"Attack", "Cast"} for action in entry["actions"])
        assert 0.2 < entry["snapshot_height"] < 0.7
    assert lift["lift_observation"] == ["UCPUMPKIN", "ordinary", "True", "A Jack-O-Lantern", "A Jack-O-Lantern"]
    assert {entry["body"] for entry in lift["records"]} == BODIES
    assert offline["decoded_routes"] == 74 and offline["terrain_poses"] == 1350 and offline["corpse_hues"] == 6
    assert 0.0 < offline["minimum_plane_gap"] < 0.004
    for prefix in ("jack-visuals", "jack-o-lanterns"):
        runtime = read(paths[prefix + "-runtime.json"])
        assert runtime["report_sha256"].lower() == digest(paths[prefix + ".json"])
        assert runtime["server_sha256"].lower() == digest(ROOT / "Server/runtime/Server.dll")
        assert runtime["content_sha256"].lower() == digest(ROOT / "Server/runtime/Assemblies/UOContent.dll")
    return {
        "proof_sha256": {name: digest(path) for name, path in paths.items()},
        "shared_scan_sha256": {str(path.relative_to(VIEWER)): digest(path)
                               for path in sorted((VIEWER / SCAN).parent.glob("*.jpg"))},
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--activate", action="store_true")
    mode.add_argument("--check-active", action="store_true")
    parser.add_argument("--data", type=Path)
    args = parser.parse_args()
    data = args.data or Path(read(ROOT / "Server/runtime/Configuration/modernuo.json")["dataDirectories"][0])
    active_path = VIEWER / INDEX
    active = read(active_path)
    paths = proof_paths()
    if args.check_active:
        paths = {name: SEALED / name for name in paths}
    candidate = read(paths["index.json"])
    fitted = rows_in(candidate)
    if args.check_active:
        assert rows_in(active) == fitted
        verify_source(fitted, VIEWER, data)
        assert verify_proof(paths) == read(RECEIPT)
    else:
        assert not rows_in(active)
        assert [row for row in candidate["entries"] if not row.get(REGISTRY_KEY)] == active["entries"]
        assert all(identity["body"] not in BODIES for row in active["entries"] for identity in row["bodies"])
        verify_source(fitted, ISOLATED, data)
        result = verify_proof(paths)
        for row in fitted:
            relative = row["assets"]["modern"].removeprefix("res://")
            target = VIEWER / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            temporary = target.with_suffix(".scn.pending")
            shutil.copyfile(ISOLATED / relative, temporary)
            temporary.replace(target)
        SEALED.mkdir(parents=True, exist_ok=True)
        for name, path in paths.items():
            shutil.copyfile(path, SEALED / name)
        write(RECEIPT, result)
        native = read(paths["jack-visuals.json"])
        native["failures"] = 0
        for entry in native["records"]:
            entry["native_class"] = "PumpkinHead"
        write(ROOT / "outputs/creatures/jack_o_lanterns/live.json", native)
        write(active_path, dict(active, entries=active["entries"] + fitted))
    print("JACK O' LANTERN ROUTES: both native bodies with source, gameplay and corpse evidence")


if __name__ == "__main__":
    main()
