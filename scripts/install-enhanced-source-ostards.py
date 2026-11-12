"""Install or check the optional local Desert and Forest Ostard scenes."""

import argparse
from hashlib import sha256
import json
from pathlib import Path
from shutil import copyfile
from tempfile import TemporaryDirectory


ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "Viewer/local-art/ostards"
DEFAULT_INPUT = ROOT / "work/creatures/enhanced-source-ostards-bake"
MANIFEST = "enhanced-ostards.json"
FORMS = {"210": "desert", "219": "forest"}
STYLES = ("original", "rounded", "modern")
SOURCES = {f"{body}-{style}.scn": ART / f"{form}-{style}.gltf"
           for body, form in FORMS.items() for style in STYLES}


def digest(path):
    return sha256(path.read_bytes()).hexdigest()


def check_installed(destination=ART):
    manifest = json.loads((destination / MANIFEST).read_text(encoding="utf-8"))
    if manifest["schema"] != 1 or manifest["bodies"].keys() != FORMS.keys():
        raise ValueError("The installed manifest differs from the prepared Ostard body set.")
    for body, styles in manifest["bodies"].items():
        if set(styles) != set(STYLES):
            raise ValueError(f"Body {body} is missing an Ostard treatment.")
        for style, expected in styles.items():
            name = f"enhanced-{body}-{style}.scn"
            if digest(destination / name) != expected:
                raise ValueError(f"Installed scene differs from its manifest: {name}")


def install(input_folder, destination=ART):
    receipt = json.loads((input_folder / "bake-receipt.json").read_text(encoding="utf-8"))
    if receipt.keys() != SOURCES.keys():
        raise ValueError("Bake both bodies and all three treatments before installing.")
    hashes = {body: {} for body in FORMS}
    for name, source in SOURCES.items():
        if digest(source) != receipt[name]["source"]:
            raise ValueError(f"The source scene changed after baking: {source.name}")
        body, style = Path(name).stem.split("-", 1)
        hashes[body][style] = receipt[name]["scene"]
    destination.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(dir=destination) as temporary:
        staged = Path(temporary)
        for name, recorded in receipt.items():
            path = staged / f"enhanced-{name}"
            copyfile(input_folder / name, path)
            if digest(path) != recorded["scene"]:
                raise ValueError(f"The baked scene differs from its receipt: {name}")
        manifest = staged / MANIFEST
        manifest.write_text(json.dumps({"schema": 1, "bodies": hashes}, indent=2) + "\n",
                            encoding="utf-8", newline="\n")
        for name in SOURCES:
            scene = f"enhanced-{name}"
            (staged / scene).replace(destination / scene)
        manifest.replace(destination / MANIFEST)
    check_installed(destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--check-installed", action="store_true")
    args = parser.parse_args()
    if args.check_installed:
        check_installed()
    else:
        install(args.input)
    print(f"Enhanced Source Ostards: {len(SOURCES)} checked local scenes")


if __name__ == "__main__":
    main()
