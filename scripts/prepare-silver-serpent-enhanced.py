"""Retarget the registered Giant Serpent motions to the original Silver Serpent."""

import argparse
import json
import os
from pathlib import Path
import runpy
from shutil import copyfile
import subprocess
from tempfile import TemporaryDirectory


SCRIPTS = Path(__file__).resolve().parent
GIANT = runpy.run_path(str(SCRIPTS / "prepare-giant-serpent-enhanced.py"))
ROOT = GIANT["ROOT"]
BASE = GIANT["BASE"]
DONOR = GIANT["ART"]
STYLES = GIANT["STYLES"]
digest = GIANT["digest"]
ART = BASE / "silver-serpent-enhanced"


def input_hashes(donor):
    GIANT["check_installed"](donor)
    return {
        "base_sha256": {style: digest(BASE / f"serpents_snake_giant_silver-{style}.gltf") for style in STYLES},
        "donor_sha256": {style: digest(donor / f"giant-serpent-enhanced-{style}.scn") for style in STYLES},
    }


def check_installed(donor, destination=ART):
    record = json.loads((destination / "manifest.json").read_text(encoding="utf-8"))
    if record.get("schema") != 1 or any(record.get(key) != value for key, value in input_hashes(donor).items()):
        raise ValueError("The installed Silver Serpent uses different source or donor scenes.")
    for style in STYLES:
        name = f"silver-serpent-enhanced-{style}.scn"
        if record.get("scene_sha256", {}).get(style) != digest(destination / name):
            raise ValueError(f"The installed Silver Serpent scene differs from its manifest: {name}")


def install(study, donor, destination=ART):
    inputs = input_hashes(donor)
    report = json.loads((study / "shared-motion-bake.json").read_text(encoding="utf-8"))
    destination.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(dir=destination) as temp:
        stage = Path(temp)
        names = []
        scenes = {}
        for style in STYLES:
            name = f"silver-serpent-enhanced-{style}.scn"
            scenes[style] = digest(study / name)
            measured = report[style]
            if (measured.get("source_sha256") != inputs["base_sha256"][style]
                    or measured.get("donor_sha256") != inputs["donor_sha256"][style]
                    or measured.get("scene_sha256") != scenes[style]
                    or len(measured.get("shared_clips", {})) != 9):
                raise ValueError(f"The checked inputs or baked scene changed: {name}")
            copyfile(study / name, stage / name)
            names.append(name)
        manifest = {"schema": 1, **inputs, "scene_sha256": scenes}
        (stage / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        check_installed(donor, stage)
        for name in (*names, "manifest.json"):
            (stage / name).replace(destination / name)
    check_installed(donor, destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--study", type=Path, default=ROOT / "work/creatures/silver-serpent-enhanced-bake")
    parser.add_argument("--donor", type=Path, default=DONOR)
    parser.add_argument("--godot", type=Path, help="Godot 4 console executable")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--install", action="store_true")
    mode.add_argument("--check-installed", action="store_true")
    args = parser.parse_args()
    donor = args.donor.resolve()
    if args.check_installed:
        check_installed(donor)
        print("Silver Serpent Enhanced scenes and registered donor scenes verified.")
        return
    input_hashes(donor)
    godot = args.godot or next((ROOT / ".tools/godot").glob("*console.exe"), None)
    if godot is None or not godot.is_file():
        parser.error("Supply the local Godot 4 console executable with --godot.")
    study = args.study.resolve()
    profile = study / "godot-user"
    profile.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, APPDATA=str(profile), LOCALAPPDATA=str(profile))
    subprocess.run([str(godot.resolve()), "--headless", "--path", str(ROOT / "Viewer"),
                    "--script", str(SCRIPTS / "bake-silver-serpent-enhanced.gd"),
                    "--log-file", str(study / "bake.log"), "--", f"--study={study.as_posix()}",
                    f"--donor={donor.as_posix()}"], env=env, check=True, timeout=120)
    if args.install:
        if donor != DONOR:
            parser.error("--install uses the installed Giant Serpent donor.")
        install(study, donor)
    print(f"Silver Serpent Enhanced scenes prepared in {study}.")


if __name__ == "__main__":
    main()
