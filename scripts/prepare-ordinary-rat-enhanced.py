"""Fit the installed Giant Rat motions to the small licensed Rat rig."""

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
VIEWER = ROOT / "Viewer"
CREATURES = VIEWER / "local-art/creatures"
ART = CREATURES / "ordinary-rat-enhanced"
TARGET = VIEWER / "Art/Creatures/Rat/rat-deaths.scn"
DONOR = CREATURES / "enhanced-creature-actions/215-modern.scn"
SCENE = "rat-enhanced.scn"


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def digest(path):
    return sha256(path.read_bytes()).hexdigest()


def inputs():
    profile = read(CREATURES / "enhanced-creature-actions.json")
    source = profile["bodies"]["215"]
    donor = digest(DONOR)
    if source.get("kind") != "rodents_rat_giant" or source["assets"]["modern"]["sha256"] != donor:
        raise ValueError("The Giant Rat scene does not match its installed Enhanced profile.")
    return {"source_sha256": digest(TARGET), "donor_sha256": donor}


def check_installed(directory=ART):
    manifest = read(directory / "manifest.json")
    if manifest != {"schema": 1, **inputs(), "scene_sha256": digest(directory / SCENE)}:
        raise ValueError("The installed ordinary Rat scene or donor differs from its manifest.")


def install(study, directory=ART):
    source = inputs()
    scene = study / SCENE
    expected = {"schema": 1, **source, "scene_sha256": digest(scene)}
    bake = read(study / "rat-enhanced-bake.json")
    if (any(bake.get(key) != value for key, value in expected.items() if key != "schema")
            or len(bake.get("clips", {})) != 7 or bake.get("ear_vertices", 0) < 244):
        raise ValueError("The measured ordinary Rat bake differs from its installed inputs or output.")
    directory.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(dir=directory) as temporary:
        stage = Path(temporary)
        copyfile(scene, stage / SCENE)
        (stage / "manifest.json").write_text(json.dumps(expected, indent=2) + "\n", encoding="utf-8")
        check_installed(stage)
        for name in (SCENE, "manifest.json"):
            (stage / name).replace(directory / name)
    check_installed(directory)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--study", type=Path, default=ROOT / "work/creatures/ordinary-rat-enhanced-bake")
    parser.add_argument("--godot", type=Path, help="Godot 4 console executable")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--install", action="store_true")
    mode.add_argument("--check-installed", action="store_true")
    args = parser.parse_args()
    if args.check_installed:
        check_installed()
        print("Ordinary Rat scene and donor verified.")
        return
    inputs()
    godot = args.godot or next((ROOT / ".tools/godot").glob("*console.exe"), None)
    if godot is None or not godot.is_file():
        parser.error("Supply the local Godot 4 console executable with --godot.")
    study = args.study.resolve()
    profile = study / "godot-user"
    profile.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, APPDATA=str(profile), LOCALAPPDATA=str(profile))
    subprocess.run([str(godot.resolve()), "--headless", "--path", str(VIEWER),
                    "--script", str(SCRIPTS / "bake-ordinary-rat-enhanced.gd"),
                    "--log-file", str(study / "bake.log"), "--", f"--study={study.as_posix()}"],
                   env=env, check=True, timeout=120)
    if args.install:
        install(study)
    print(f"Ordinary Rat Enhanced scene prepared in {study}.")


if __name__ == "__main__":
    main()
