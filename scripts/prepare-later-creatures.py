# SPDX-License-Identifier: GPL-3.0-or-later
"""Build optional creature scenes from reviewed references and local donor models."""
import argparse
from hashlib import file_digest, sha256
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
from tempfile import TemporaryDirectory


ROOT = Path(__file__).resolve().parent.parent
VIEWER = ROOT / "Viewer"
RECIPES = {181: "orc-scout", 287: "bloodworm", 334: "enslaved-goblin",
           714: "iron-beetle", 715: "ruddy-boura", 716: "chicken-lizard", 717: "clockwork-scorpion", 718: "fairy-dragon", 720: "lava-elemental",
           722: "undead-guardian", 723: "goblin",
           726: "kepetch", 732: "rotworm", 733: "skree", 736: "wolf-spider", 737: "trapdoor-spider", 738: "fire-ant"}
STYLES = ("original", "rounded", "modern")


def digest(path):
    with path.open("rb") as file:
        return file_digest(file, "sha256").hexdigest()


def check_references(sequence, classic, reference, selected):
    reader = runpy.run_path(str(ROOT / "scripts/uo-human-sequences.py"))
    sequence_digest = digest(sequence)
    alternate = sequence_digest == reference.get("alternate_sequence_sha256")
    if sequence_digest != reference["sequence_sha256"] and not alternate:
        raise ValueError("AnimationSequence.uop differs from the reviewed build.")
    if alternate:
        expected = {
            int(reference["bodies"][str(body)]["reference"]["sequence"], 16):
                reference["bodies"][str(body)]["reference"]["sequence_payload_sha256"]
            for body in selected
        }
        actual = {key: sha256(payload).hexdigest()
                  for key, payload in reader["payloads"](sequence, expected)}
        if actual != expected:
            raise ValueError("The alternate sequence archive contains different creature records.")
    records = reader["inspect"](sequence, selected)
    named = {record["animation_ref"]: record.get("uop_name_hash") for record in records if "parse_blocker" not in record}
    members = {}
    for body in selected:
        info = reference["bodies"][str(body)]["reference"]
        if named.get(body) != info["sequence"]:
            raise ValueError(f"The Enhanced sequence record for body {body} differs.")
        for frame in info["classic_members"].values():
            archive = members.setdefault(frame["archive"], {})
            archive[int(frame["name_hash"], 16)] = frame["sha256"]
    for archive, expected in members.items():
        actual = {key: sha256(payload).hexdigest() for key, payload in reader["payloads"](classic / archive, expected)}
        if actual != expected:
            raise ValueError(f"Reviewed Classic body references differ in {archive}.")


def build_selected(godot, folder, selected):
    env = dict(os.environ, BR_LATER_CREATURE_OUTPUT=str(folder),
               APPDATA=str(ROOT / ".godot-user"), LOCALAPPDATA=str(ROOT / ".godot-user"))
    if 716 in selected:
        pins = json.loads((ROOT / "scripts/raptor-inputs.json").read_bytes())
        sources = VIEWER / "local-art/creatures/raptor-trial"
        for filename, expected in pins["files"].items():
            if digest(sources / filename) != expected:
                raise ValueError(f"Chicken Lizard's CC0 donor source differs: {filename}")
        if not (VIEWER / "local-art/creatures/raptor/raptor.scn").is_file():
            raise ValueError("Prepare the reviewed Raptor donor before building the Chicken Lizard.")
    if 181 in selected:
        subprocess.run([sys.executable, "-B", str(ROOT / "scripts/prepare-later-orc-scout.py"),
                        "--output", str(folder)], check=True, timeout=120)
    order = sorted(set(selected) | ({723} if 334 in selected else set()),
                   key=lambda body: (body == 334, body))
    for body in order:
        script = ROOT / "scripts" / f"bake-later-{RECIPES[body]}.gd"
        result = subprocess.run(
            [str(godot), "--headless", "--path", str(VIEWER), "--log-file", str(folder / f"{body}-engine.log"),
             "--script", str(script)],
            env=env, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120,
        )
        if result.returncode or "ERROR:" in result.stdout + result.stderr:
            raise RuntimeError(result.stdout + result.stderr)
        print(result.stdout.strip())


def install(folder, target, reference, selected):
    manifest = target / "profile.json"
    old = json.loads(manifest.read_bytes()) if manifest.is_file() else {"schema": 1, "bodies": {}}
    if old["schema"] != 1:
        raise ValueError("Unsupported installed creature profile schema.")
    for body in selected:
        row = reference["bodies"][str(body)].copy()
        if body == 716:
            row["donor_scene_sha256"] = digest(VIEWER / "local-art/creatures/raptor/raptor.scn")
        row["asset_sha256"] = {}
        for style in STYLES:
            baked = folder / f"{body}-{style}.scn"
            hashed = digest(baked)
            row["asset_sha256"][style] = hashed
            baked.replace(target / f"{body}-{style}-{hashed}.scn")
        old["bodies"][str(body)] = row
    staged = folder / manifest.name
    staged.write_text(json.dumps(old, indent=2) + "\n", encoding="utf-8")
    staged.replace(manifest)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--sequence", type=Path, required=True)
    parser.add_argument("--classic", type=Path, required=True)
    parser.add_argument("--body", type=int, choices=RECIPES, action="append")
    parser.add_argument("--output", type=Path, default=VIEWER / "local-art/creatures/later-prepared")
    args = parser.parse_args()
    selected = sorted(set(args.body or RECIPES))
    reference = json.loads((ROOT / "scripts/later-creature-inputs.json").read_bytes())
    inputs = sorted(set(selected) | ({723} if 334 in selected else set()))
    check_references(args.sequence, args.classic, reference, inputs)
    executable = next((ROOT / ".tools/godot").glob("*console.exe"))
    target = args.output.resolve()
    target.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(prefix="bake-", dir=target) as temporary:
        folder = Path(temporary)
        build_selected(executable, folder, selected)
        install(folder, target, reference, selected)


if __name__ == "__main__":
    main()
