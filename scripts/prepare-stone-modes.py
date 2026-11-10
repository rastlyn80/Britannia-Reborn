# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify and install Stone Form's higher archive motion groups."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import runpy
import shutil

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / "work/creatures/native-form-audit"
VIEWER = ROOT / "Viewer"
STAGE = WORK / "isolated-client"
EVIDENCE = WORK / "stone-modes"
SEALED = EVIDENCE / "accepted-proof"
INDEX = VIEWER / "local-art/creatures/accepted-index.json"
MODES = {22: "StonePeaceWalk", 23: "StoneKneelRise", 24: "Run", 25: "ReadyStance",
         26: "StonePeaceGesture", 27: "StoneWarGesture", 28: "StoneStanceRise"}
NEW = {"2": "StoneHunch", "4": "Hit", "8": "StoneStanceRise", "11": "StoneFormCast",
       "14": "StoneGesture", "15": "StoneKneelRise"}
VISUAL = "res://Presentation/StoneFormModesVisual.gd"


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write(path, value):
    temporary = path.with_suffix(path.suffix + ".pending")
    temporary.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def resource(viewer, uri):
    return viewer / uri.removeprefix("res://")


def proof_paths():
    return {
        "native.json": WORK / "stone-modes-native.json",
        "native-runtime.json": WORK / "stone-modes-native-runtime.json",
        "NativeStoneModesLive.gd": STAGE / "Network/NativeStoneModesLive.gd",
        "presentation.json": EVIDENCE / "presentation.json",
        "TestStoneModes.gd": EVIDENCE / "TestStoneModes.gd",
    }


def check_proofs(paths):
    native = read(paths["native.json"])
    offline = read(paths["presentation.json"])
    runtime = read(paths["native-runtime.json"])
    assert native["test_sha256"] == sha(paths["NativeStoneModesLive.gd"])
    assert offline["test_sha256"] == sha(paths["TestStoneModes.gd"])
    assert native["renderer_sha256"] == sha(resource(VIEWER, VISUAL))
    assert runtime["report_sha256"].lower() == sha(paths["native.json"])
    assert runtime["server_sha256"].lower() == sha(ROOT / "Server/runtime/Server.dll")
    assert runtime["content_sha256"].lower() == sha(ROOT / "Server/runtime/Assemblies/UOContent.dll")
    assert native["checks"] == 33
    assert [row["combat"] for row in native["walk_modes"]] == [False, True, False]
    assert all(row["from"] != row["to"] and bool(row["observer_flags"] & 0x40) == row["combat"]
               for row in native["walk_modes"])
    assert offline["routes"] == 39 and offline["poses"] == 1575
    assert offline["minimum"] >= -0.004 and offline["minimum_kneel_range"] > 0.35
    assert offline["assets"] == native["assets"]
    return native["assets"]


def candidate(base, paths, art, data):
    assert base["kind"] == "spell_form_stone" and base["bodies"][0]["body"] == 705
    assert base["fitted_spell_form_source"]["donor_body"] == 14
    frames = base["fitted_spell_form_source"]["source_frame_groups"]
    assert {item["group"] for item in frames} >= MODES.keys()
    reader = runpy.run_path(str(ROOT / "scripts/uo-human-sequences.py"))
    sequence, = reader["inspect"](data / "AnimationSequence.uop", {705})
    peaceful, = [mode for mode in sequence["modes"] if mode["mode"] == 1]
    assert peaceful["default_group"] == 25
    assert peaceful["transitions"] == [{"target_mode": 0, "group": 28}]
    assert [item["one_handed_group"] for item in peaceful["movement"]] == [25, 22, 24]
    classic = ROOT / "work/reference/ClassicUO/src/ClassicUO.Client/Game/GameObjects/MobileAnimation.cs"
    source = classic.read_text(encoding="utf-8-sig")
    assert "&& !mobile.InWarMode" in source and "result = 25;" in source and "result = 22;" in source
    assets = {treatment: f"res://local-art/creatures/stone-mode-trial/705-{treatment}.scn"
              for treatment in base["assets"]}
    hashes = {treatment: sha(resource(art, path)) for treatment, path in assets.items()}
    assert hashes == check_proofs(paths)
    row = copy.deepcopy(base)
    row.update(assets=assets, asset_sha256=hashes, presentation_script=VISUAL,
               presentation_script_sha256=sha(resource(VIEWER, VISUAL)),
               loop_categories=["ReadyStance", "StonePeaceWalk"], new_action_categories=NEW,
               stone_mode_predecessor=base,
               stone_mode_source={"sequence": sequence, "classic_reference_sha256": sha(classic),
                                  "proof_sha256": {name: sha(path) for name, path in paths.items()}})
    for group, clip in MODES.items():
        row["classic_action_categories"][str(group)] = clip
        if clip not in row["archive_grounded_gestures"]:
            row["archive_grounded_gestures"].append(clip)
        row["authored_clips"][clip] = f"Fitted to Stone Form 705, AnimationFrame3.uop group {group}"
    row["clip_sources"].pop("Run", None)
    return row


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--activate", action="store_true")
    mode.add_argument("--check-active", action="store_true")
    parser.add_argument("--data", type=Path)
    args = parser.parse_args()
    data = args.data or Path(read(ROOT / "Server/runtime/Configuration/modernuo.json")["dataDirectories"][0])
    index = read(INDEX)
    current, = [row for row in index["entries"] if row["kind"] == "spell_form_stone"]
    paths = proof_paths()
    if args.check_active:
        sealed = {name: SEALED / name for name in paths}
        assert current == candidate(current["stone_mode_predecessor"], sealed, VIEWER, data)
    else:
        assert "stone_mode_predecessor" not in current
        installed = candidate(current, paths, STAGE, data)
        for uri in installed["assets"].values():
            target = resource(VIEWER, uri)
            target.parent.mkdir(parents=True, exist_ok=True)
            pending = target.with_suffix(".scn.pending")
            shutil.copyfile(resource(STAGE, uri), pending)
            pending.replace(target)
        SEALED.mkdir(parents=True, exist_ok=True)
        for name, path in paths.items():
            shutil.copyfile(path, SEALED / name)
        write(INDEX, dict(index, entries=[installed if row is current else row for row in index["entries"]]))
    print("STONE MODES: seven source clips, native combat flags and terrain support verified")


if __name__ == "__main__":
    main()
