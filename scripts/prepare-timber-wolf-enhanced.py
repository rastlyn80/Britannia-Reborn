"""Build and verify the local Timber Wolf scenes against the accepted wolf rigs."""

import argparse
from hashlib import file_digest
import json
import math
import os
from pathlib import Path
from shutil import copyfile
import subprocess
from tempfile import TemporaryDirectory


SCRIPTS = Path(__file__).resolve().parent
ROOT = next(path for path in SCRIPTS.parents if (path / "Viewer/project.godot").is_file())
VIEWER = ROOT / "Viewer"
CREATURES = VIEWER / "local-art/creatures"
ART = CREATURES / "timber-wolf-enhanced"
STYLES = ("original", "rounded", "modern")
CLIPS = {
    "4": "TimberWolfSnap",
    "15": "TimberWolfLowRecoil",
    "25": "TimberWolfQuietStand",
    "26": "TimberWolfScentWatch",
    "27": "TimberWolfHowl",
    "28": "TimberWolfEarAlert",
}


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def digest(path):
    with path.open("rb") as handle:
        return file_digest(handle, "sha256").hexdigest()


def verified_asset(resource, expected):
    prefix = "res://local-art/creatures/"
    if not resource.startswith(prefix):
        raise ValueError(f"Unexpected source scene path: {resource}")
    asset = VIEWER / resource.removeprefix("res://")
    if not asset.resolve().is_relative_to(CREATURES) or digest(asset) != expected:
        raise ValueError(f"Source scene differs from its accepted hash: {resource}")
    return expected


def inputs():
    index = read(CREATURES / "accepted-index.json")["entries"]
    source = {int(identity["body"]): row for row in index if row.get("status") == "validated"
              for identity in row.get("bodies", [])}
    timber, grey = source[225], source[25]
    reference = read(CREATURES / "enhanced-creature-actions.json")["bodies"]["25"]
    if timber["kind"] != "canines_wolf_timber" or not grey["kind"].startswith("canines_wolf_grey"):
        raise ValueError("The accepted Timber Wolf and Grey Wolf rigs are required.")
    if reference["kind"] != grey["kind"] or reference["base_sha256"] != grey["asset_sha256"]:
        raise ValueError("The installed Grey Wolf fit differs from its accepted rig.")
    variants = {}
    for style in STYLES:
        donor = reference["assets"][style]
        variants[style] = {
            "base_sha256": verified_asset(timber["assets"][style], timber["asset_sha256"][style]),
            "grey_base_sha256": verified_asset(grey["assets"][style], grey["asset_sha256"][style]),
            "reference_sha256": verified_asset(donor["path"], donor["sha256"]),
        }
    return variants


def scene_name(style):
    return f"225-{style}.scn"


def manifest(directory, sources):
    return {"schema": 1, "variants": {
        style: {"base_sha256": pins["base_sha256"], "reference_sha256": pins["reference_sha256"],
                "scene_sha256": digest(directory / scene_name(style))}
        for style, pins in sources.items()
    }}


def check_installed(directory, sources):
    if read(directory / "manifest.json") != manifest(directory, sources):
        raise ValueError("The installed Timber Wolf scenes or source rigs differ from the manifest.")


def install(study, directory, sources):
    expected = manifest(study, sources)
    proof = read(study / "timber-wolf-first-fit.json")
    if (proof["body"] != 225 or proof["motion_reference"] != 25 or proof["clips"] != CLIPS
            or proof["sample_count"] != len(STYLES) * len(CLIPS) * 61):
        raise ValueError("The Timber Wolf bake does not cover the six expected motion fits.")
    for style in STYLES:
        fitted = proof["variants"][style]
        if (fitted["scene_sha256"] != expected["variants"][style]["scene_sha256"]
                or fitted["base_sha256"] != sources[style]["base_sha256"]
                or fitted["grey_base_sha256"] != sources[style]["grey_base_sha256"]
                or set(fitted["gaps"]) != set(CLIPS.values())
                or not all(math.isfinite(gap) and gap > 0.003 for gap in fitted["gaps"].values())):
            raise ValueError(f"Timber Wolf {style} differs from the measured bake or its source rigs.")
    directory.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(dir=directory) as temporary:
        stage = Path(temporary)
        for style in STYLES:
            name = scene_name(style)
            copyfile(study / name, stage / name)
        (stage / "manifest.json").write_text(json.dumps(expected, indent=2) + "\n", encoding="utf-8")
        check_installed(stage, sources)
        # The runtime validates the manifest and all three scenes before enabling the profile.
        for name in (*(scene_name(style) for style in STYLES), "manifest.json"):
            (stage / name).replace(directory / name)
    check_installed(directory, sources)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--study", type=Path, default=ROOT / "work/creatures/timber-wolf-enhanced-bake")
    parser.add_argument("--godot", type=Path, help="Godot 4 console executable")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--install", action="store_true")
    mode.add_argument("--check-installed", action="store_true")
    args = parser.parse_args()
    sources = inputs()
    if args.check_installed:
        check_installed(ART, sources)
        print("Timber Wolf scenes and source rigs verified.")
        return
    godot = args.godot or next((ROOT / ".tools/godot").glob("*console.exe"), None)
    if godot is None or not godot.is_file():
        parser.error("Supply the local Godot 4 console executable with --godot.")
    study = args.study.resolve()
    profile = study / "godot-user"
    profile.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, APPDATA=str(profile), LOCALAPPDATA=str(profile))
    subprocess.run([str(godot.resolve()), "--headless", "--path", str(VIEWER),
                    "--script", str(SCRIPTS / "bake-timber-wolf-enhanced.gd"),
                    "--log-file", str(study / "bake.log"), "--", f"--study={study.as_posix()}"],
                   env=env, check=True, timeout=120)
    if args.install:
        install(study, ART, sources)
    print(f"Timber Wolf Enhanced scenes prepared in {study}.")


if __name__ == "__main__":
    main()
