# SPDX-License-Identifier: GPL-3.0-or-later
"""Validate the expanded Enhanced references and prepare private body-826 scenes."""

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
    parser.add_argument("--reference", type=Path, required=True, help="Expanded official EC body-826 AMOU members")
    parser.add_argument("--output", type=Path, default=ROOT / "Viewer/local-art/creatures/stygian-dragon")
    args = parser.parse_args()
    pins = json.loads(Path(__file__).with_name("stygian-dragon-inputs.json").read_bytes())
    for member in pins["archive_frames"]:
        path = args.reference / f"ec-frame-826-{member['group']}.bin"
        if digest(path) != member["sha256"]:
            raise ValueError(f"Official Stygian Dragon reference differs for {path.name}")
    godot = next((ROOT / ".tools/godot").glob("*console.exe"))
    target = args.output.resolve()
    target.mkdir(parents=True, exist_ok=True)

    with TemporaryDirectory(prefix="stygian-bake-", dir=target) as work:
        temporary = Path(work)
        env = dict(os.environ, BR_STYGIAN_DRAGON_OUTPUT=work,
                   APPDATA=str(ROOT / ".godot-user"), LOCALAPPDATA=str(ROOT / ".godot-user"))
        subprocess.run([godot, "--headless", "--path", ROOT / "Viewer", "--script",
                        Path(__file__).with_name("bake-stygian-dragon.gd")], check=True, env=env)
        fitted = json.loads((temporary / "fitted-scenes.json").read_bytes())
        hashes = {}
        for style in STYLES:
            scene = temporary / f"826-{style}.scn"
            computed = digest(scene)
            if fitted[style]["donor"] != pins["donors"][style] or fitted[style]["scene"] != computed:
                raise ValueError(f"Stygian Dragon donor or fitted scene differs for {style}")
            hashes[style] = computed
            final = target / f"826-{style}-{computed}.scn"
            if not final.is_file() or digest(final) != computed:
                scene.replace(final)
        profile = temporary / "profile.json"
        profile.write_text(json.dumps({"schema": 1, "body": 826, "asset_sha256": hashes}, indent=2) + "\n",
                           encoding="utf-8")
        profile.replace(target / profile.name)
    print("Stygian Dragon installed with all three validated local scenes.")


if __name__ == "__main__":
    main()
