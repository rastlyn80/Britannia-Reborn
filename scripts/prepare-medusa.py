# SPDX-License-Identifier: GPL-3.0-or-later
"""Validate the expanded Enhanced references and prepare private body-728 scenes."""

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
    parser.add_argument("--reference", type=Path, required=True, help="Expanded official EC body-728 AMOU members")
    parser.add_argument("--output", type=Path, default=ROOT / "Viewer/local-art/creatures/medusa")
    args = parser.parse_args()
    pins = json.loads(Path(__file__).with_name("medusa-inputs.json").read_bytes())
    for member in pins["archive_frames"]:
        path = args.reference / f"ec-frame-728-{member['group']}.bin"
        if digest(path) != member["sha256"]:
            raise ValueError(f"Official Medusa reference differs for {path.name}")
    godot = next((ROOT / ".tools/godot").glob("*console.exe"))
    target = args.output.resolve()
    target.mkdir(parents=True, exist_ok=True)

    with TemporaryDirectory(prefix="medusa-bake-", dir=target) as work:
        temporary = Path(work)
        env = dict(os.environ, BR_MEDUSA_OUTPUT=work,
                   APPDATA=str(ROOT / ".godot-user"), LOCALAPPDATA=str(ROOT / ".godot-user"))
        subprocess.run([godot, "--headless", "--path", ROOT / "Viewer", "--script",
                        Path(__file__).with_name("bake-medusa.gd")], check=True, env=env)
        fitted = json.loads((temporary / "fitted-scenes.json").read_bytes())
        hashes = {}
        for style in STYLES:
            scene = temporary / f"728-{style}.scn"
            computed = digest(scene)
            if fitted[style]["donor"] != pins["donors"][style] or fitted[style]["scene"] != computed:
                raise ValueError(f"Medusa donor or fitted scene differs for {style}")
            hashes[style] = computed
            final = target / f"728-{style}-{computed}.scn"
            if not final.is_file() or digest(final) != computed:
                scene.replace(final)
        profile = temporary / "profile.json"
        profile.write_text(json.dumps({"schema": 1, "body": 728, "asset_sha256": hashes}, indent=2) + "\n",
                           encoding="utf-8")
        profile.replace(target / profile.name)
    print("Medusa installed with all three validated local scenes.")


if __name__ == "__main__":
    main()
