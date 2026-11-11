"""Install or validate the optional local cattle scenes baked by Godot."""

import argparse
from hashlib import sha256
import json
from pathlib import Path
from shutil import copyfile
from tempfile import TemporaryDirectory


ROOT = Path(__file__).resolve().parents[1]
ANIMALS = ROOT / "Viewer/local-art/animals"
DESTINATION = ANIMALS / "enhanced-cattle"
DEFAULT_INPUT = ROOT / "work/creatures/enhanced-cattle-bake"
KINDS = {216: "bovine_cow_spotted", 231: "bovine_cow_brown", 232: "bovine_bull_brown", 233: "bovine_bull_spotted"}
TREATMENTS = ("original", "rounded", "modern")
SOURCES = {f"{body}-{treatment}.scn": ANIMALS / f"{kind}-{treatment}-actions.scn"
           for body, kind in KINDS.items() for treatment in TREATMENTS}


def digest(path):
    return sha256(path.read_bytes()).hexdigest()


def check_installed():
    manifest = json.loads((DESTINATION / "manifest.json").read_text(encoding="utf-8"))
    if manifest["schema"] != 1 or manifest["scenes"].keys() != SOURCES.keys():
        raise ValueError("The installed cattle manifest differs from the prepared body and treatment set.")
    for name, expected in manifest["scenes"].items():
        if digest(DESTINATION / name) != expected:
            raise ValueError(f"Installed scene differs from its manifest: {name}")


def install(input_folder):
    receipt = json.loads((input_folder / "candidate-poses.json").read_text(encoding="utf-8"))
    if receipt.keys() != SOURCES.keys():
        raise ValueError("Bake all four cattle bodies and their three treatments before installing.")
    hashes = {}
    for name, source in SOURCES.items():
        if digest(source) != receipt[name]["source"]:
            raise ValueError(f"The source scene changed after baking {name}.")
        hashes[name] = digest(input_folder / name)
        if hashes[name] != receipt[name]["scene"]:
            raise ValueError(f"The fitted scene changed after baking {name}.")
    DESTINATION.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(dir=DESTINATION) as temporary:
        staging = Path(temporary)
        for name in hashes:
            copyfile(input_folder / name, staging / name)
            if digest(staging / name) != hashes[name]:
                raise ValueError(f"The copied fitted scene differs: {name}")
        manifest = staging / "manifest.json"
        manifest.write_text(json.dumps({"schema": 1, "scenes": dict(sorted(hashes.items()))}, indent=2) + "\n",
                            encoding="utf-8", newline="\n")
        for name in hashes:
            (staging / name).replace(DESTINATION / name)
        manifest.replace(DESTINATION / manifest.name)
    check_installed()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--check-installed", action="store_true")
    args = parser.parse_args()
    if args.check_installed:
        check_installed()
    else:
        install(args.input)
    print(f"Enhanced cattle: {len(SOURCES)} locally prepared scenes")


if __name__ == "__main__":
    main()
