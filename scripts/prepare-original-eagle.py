# SPDX-License-Identifier: GPL-3.0-or-later
"""Rebuild the original body-5 Eagle from a locally extracted AoS Models folder."""

import argparse
from hashlib import sha256
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess


ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "scripts"
RECIPE = Path(__file__).resolve().parent
PINS = RECIPE / "original-eagle-inputs.json"
PREVIEW = ROOT / "work/creatures/original-eagle/preview"
ASSETS = ROOT / "Viewer/local-art/creatures/original-eagle"
STYLES = ("original", "rounded", "modern")


def digest(path):
    with path.open("rb") as stream:
        return sha256(stream.read()).hexdigest()


def manifest(folder):
    return {"schema": 1, "input_sha256": digest(PINS),
            "variants": {style: digest(folder / f"5-{style}.scn") for style in STYLES}}


def check_installed():
    active = json.loads((ASSETS / "manifest.json").read_text(encoding="utf-8"))
    if active != manifest(ASSETS):
        raise ValueError("The installed original Eagle art differs from its preparation manifest.")
    print("ORIGINAL EAGLE ASSETS: three checked local scenes")


def import_source(models):
    provenance = json.loads(PINS.read_text(encoding="utf-8"))
    members = {}
    for member, record in provenance.items():
        relative = member.removeprefix("uoaos/UOTD/models/")
        path = models / relative
        if path.stat().st_size != record["bytes"] or digest(path) != record["sha256"]:
            raise ValueError(f"Unexpected Eagle archive member: {relative}")
        members[member] = path

    class ExtractedMembers:
        def read(self, name):
            raw = members[name].read_bytes()
            if sha256(raw).hexdigest() != provenance[name]["sha256"]:
                raise ValueError(f"Eagle archive member changed during the import: {name}")
            return raw

    spec = importlib.util.spec_from_file_location("eagle_import_pipeline", TOOLS / "prepare-creatures.py")
    pipeline = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(pipeline)
    pipeline.OUTPUT = PREVIEW
    pipeline.HEIGHTS["birds"] = 0.29
    pipeline.helper.audit.ARCHIVE_HASH = digest(PINS)
    export = pipeline.td.export_gltf

    def export_eagle(*args, **kwargs):
        kwargs["floor_sample_rate"] = 120
        return export(*args, **kwargs)

    pipeline.td.export_gltf = export_eagle
    table = ExtractedMembers().read("uoaos/UOTD/models/models.txt")
    _, native = pipeline.native_bodies()
    eagle, = pipeline.prepare("birds", ExtractedMembers(), {name.lower(): name for name in members},
                              pipeline.table_rows(table), native, selected_kinds={"birds_eagle"})
    assert eagle["status"] == "prepared", eagle
    assert {row["body"] for row in eagle["bodies"]} == {5}
    assert set(eagle["clip_sources"]) == {"Attack", "Death", "Eat", "Fidget", "Hit", "Idle", "Run", "Walk"}


def run_godot(script, *extra, marker):
    godot, = (ROOT / ".tools/godot").glob("*console.exe")
    user = PREVIEW.parent / "godot-user"
    user.mkdir(parents=True, exist_ok=True)
    environment = os.environ.copy()
    environment["APPDATA"] = environment["LOCALAPPDATA"] = str(user)
    arguments = [str(godot), "--headless", "--path", str(ROOT / "Viewer"),
                 "--script", str(RECIPE / script), "--", "--eagle-preview=" + PREVIEW.as_posix(), *extra]
    result = subprocess.run(arguments, cwd=ROOT, env=environment, capture_output=True, text=True, timeout=210)
    output = result.stdout + result.stderr
    print(output, end="")
    if result.returncode or "SCRIPT ERROR:" in output or marker not in output:
        raise RuntimeError(f"Original Eagle verification failed in {script}")


def install():
    ASSETS.mkdir(parents=True, exist_ok=True)
    expected = manifest(PREVIEW)
    for style in STYLES:
        name = f"5-{style}.scn"
        target = ASSETS / name
        temporary = target.with_suffix(".scn.tmp")
        shutil.copyfile(PREVIEW / name, temporary)
        if digest(temporary) != expected["variants"][style]:
            raise ValueError(f"Eagle scene changed during staging: {name}")
        temporary.replace(target)
    temporary = ASSETS / "manifest.json.tmp"
    temporary.write_text(json.dumps(expected, indent=2) + "\n", encoding="utf-8")
    temporary.replace(ASSETS / "manifest.json")
    check_installed()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--models", type=Path, default=ROOT / "work/third-dawn/late-source-research/uoaos-source/Models")
    action = parser.add_mutually_exclusive_group()
    action.add_argument("--install", action="store_true")
    action.add_argument("--check-installed", action="store_true")
    options = parser.parse_args()
    if options.check_installed:
        check_installed()
        return
    import_source(options.models)
    run_godot("bake-original-eagle.gd", marker="ORIGINAL EAGLE BAKE: 8 preserved source clips")
    run_godot("test-original-eagle-bake.gd", "--baked", marker="EAGLE FLIGHT GEOMETRY: 1830 full-skin poses")
    if options.install:
        install()


if __name__ == "__main__":
    main()
