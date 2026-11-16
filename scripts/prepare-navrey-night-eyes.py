# SPDX-License-Identifier: GPL-3.0-or-later
"""Bake and install the private Navrey refit from a prepared Third Dawn spider."""

import argparse
from hashlib import file_digest
import json
import os
from pathlib import Path
import subprocess
from tempfile import TemporaryDirectory


ROOT = Path(__file__).resolve().parent.parent
STYLES = ("original", "rounded", "modern")


def digest(path):
    with path.open("rb") as source:
        return file_digest(source, "sha256").hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", type=Path, required=True, help="Expanded official EC body-735 AMOU files")
    parser.add_argument("--output", type=Path, default=ROOT / "Viewer/local-art/creatures/navrey")
    args = parser.parse_args()
    pins = json.loads(Path(__file__).with_name("navrey-night-eyes-inputs.json").read_bytes())
    for frame in pins["archive_frames"]:
        path = args.reference / f"ec-frame-735-{frame['group']}.bin"
        if digest(path) != frame["sha256"]:
            raise ValueError(f"Official Navrey sprite reference differs: {path.name}")
    godot = next((ROOT / ".tools/godot").glob("*console.exe"))
    target = args.output.resolve()
    target.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(prefix="navrey-bake-", dir=target) as temporary:
        folder = Path(temporary)
        env = dict(os.environ, BR_NAVREY_OUTPUT=str(folder),
                   APPDATA=str(ROOT / ".godot-user"), LOCALAPPDATA=str(ROOT / ".godot-user"))
        subprocess.run([godot, "--headless", "--path", ROOT / "Viewer", "--script",
                        Path(__file__).with_name("bake-navrey-night-eyes.gd")], check=True, env=env)
        fitted = json.loads((folder / "fitted-scenes.json").read_bytes())
        hashes = {}
        for style in STYLES:
            baked = folder / f"735-{style}.scn"
            hashed = digest(baked)
            if fitted[style]["source"] != pins["donors"][style] or fitted[style]["scene"] != hashed:
                raise ValueError(f"Navrey donor or fitted scene differs for {style}")
            hashes[style] = hashed
            final = target / f"735-{style}-{hashed}.scn"
            if not final.is_file() or digest(final) != hashed:
                baked.replace(final)
        profile = folder / "profile.json"
        profile.write_text(json.dumps({"schema": 1, "body": 735, "asset_sha256": hashes}, indent=2) + "\n",
                           encoding="utf-8")
        profile.replace(target / profile.name)
    print("Navrey Night-Eyes installed with all three validated local scenes.")


if __name__ == "__main__":
    main()
