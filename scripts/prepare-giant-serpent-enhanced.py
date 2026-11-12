"""Build the optional Giant Serpent actions from the preceding prepared Enhanced scenes."""

import argparse
from hashlib import sha256
import json
import os
from pathlib import Path
from shutil import copyfile
import subprocess
from tempfile import TemporaryDirectory


SCRIPTS = Path(__file__).resolve().parent
ROOT = next(parent for parent in SCRIPTS.parents if (parent / "Viewer/project.godot").is_file())
BASE = ROOT / "Viewer/local-art/creatures"
ART = BASE / "giant-serpent-enhanced"
STYLES = ("original", "rounded", "modern")


def digest(path):
    return sha256(path.read_bytes()).hexdigest()


def base_hashes():
    profile = json.loads((BASE / "enhanced-creature-actions.json").read_text(encoding="utf-8"))
    entry = profile["bodies"]["21"]
    hashes = {}
    for style in STYLES:
        name = f"21-{style}.scn"
        hashes[style] = digest(BASE / "enhanced-creature-actions" / name)
        if entry["assets"][style]["sha256"] != hashes[style]:
            raise ValueError(f"The preceding Giant Serpent scene differs from its installed manifest: {name}")
    return hashes


def check_installed(destination=ART):
    record = json.loads((destination / "manifest.json").read_text(encoding="utf-8"))
    if record.get("schema") != 1 or record.get("base_sha256") != base_hashes():
        raise ValueError("The installed Giant Serpent is based on different retained Enhanced scenes.")
    for style in STYLES:
        name = f"giant-serpent-enhanced-{style}.scn"
        if digest(destination / name) != record["scene_sha256"].get(style):
            raise ValueError(f"The installed Enhanced scene differs from its manifest: {name}")


def install(study, destination=ART):
    base = base_hashes()
    record = {"schema": 1, "base_sha256": base, "scene_sha256": {}}
    destination.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(dir=destination) as temporary:
        staged = Path(temporary)
        names = []
        for style in STYLES:
            name = f"giant-serpent-enhanced-{style}.scn"
            report = json.loads((study / f"bake-{style}.json").read_text(encoding="utf-8"))
            if report.get("source") != base[style] or report.get("scene") != digest(study / name):
                raise ValueError(f"The Giant Serpent bake inputs or outputs changed: {name}")
            record["scene_sha256"][style] = report["scene"]
            copyfile(study / name, staged / name)
            names.append(name)
        (staged / "manifest.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
        check_installed(staged)
        for name in (*names, "manifest.json"):
            (staged / name).replace(destination / name)
    check_installed(destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--study", type=Path, default=ROOT / "work/creatures/giant-serpent-enhanced-bake")
    parser.add_argument("--godot", type=Path, help="Godot 4 console executable")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--install", action="store_true")
    mode.add_argument("--check-installed", action="store_true")
    args = parser.parse_args()
    if args.check_installed:
        check_installed()
        print("Giant Serpent Enhanced scenes and retained Enhanced inputs verified.")
        return
    base_hashes()
    godot = args.godot or next((ROOT / ".tools/godot").glob("*console.exe"), None)
    if godot is None or not godot.is_file():
        parser.error("Supply the local Godot 4 console executable with --godot.")
    study = args.study.resolve()
    study.mkdir(parents=True, exist_ok=True)
    profile = study / "godot-user"
    profile.mkdir(exist_ok=True)
    env = dict(os.environ, APPDATA=str(profile), LOCALAPPDATA=str(profile))
    subprocess.run([str(godot.resolve()), "--headless", "--path", str(ROOT / "Viewer"),
                    "--script", str(SCRIPTS / "bake-giant-serpent-enhanced.gd"),
                    "--log-file", str(study / "bake.log"), "--", f"--study={study.as_posix()}"],
                   env=env, check=True, timeout=180)
    if args.install:
        install(study)
    print(f"Giant Serpent Enhanced scenes prepared in {study}.")


if __name__ == "__main__":
    main()
