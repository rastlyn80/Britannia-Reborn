# SPDX-License-Identifier: GPL-3.0-or-later
"""Export the pinned Lady Melisande mesh, atlas and animations from extracted owned files."""

import argparse
from hashlib import file_digest
import json
from pathlib import Path
import runpy


ROOT = Path(__file__).resolve().parents[1]
KIND = "ladymelisande"


def digest(path):
    with path.open("rb") as handle:
        return file_digest(handle, "sha256").hexdigest()


def export_creature(root, output, extracted, pins):
    for name, signature in pins.items():
        if digest(extracted / name) != signature:
            raise ValueError(f"Lady Melisande source differs: {name}")
    pipeline = runpy.run_path(str(root / "scripts/prepare-creatures.py"))
    pipeline["prepare"].__globals__["OUTPUT"] = output
    reader, smoother = pipeline["td"], pipeline["smooth"]
    read, refine, export = reader.parse, smoother.refine, reader.export_gltf

    def read_skin(raw, **options):
        return read(raw, max_influences=8, **options)

    def retain_influences(body, **options):
        # Subdivision combines cape and limb weights across edges. The
        # original triangles fit the 8-weight skin without dropping influences.
        options.update(max_influences=8, weight_smoothing=0.0, levels=0)
        return refine(body, **options)

    def export_skin(*args, **options):
        options["preserve_vertical_clips"] = sorted(set(options.get("preserve_vertical_clips", ())) | {"Walk", "Run"})
        return export(*args, max_influences=8, **options)

    reader.parse = read_skin
    smoother.refine = retain_influences
    reader.export_gltf = export_skin
    pipeline["LABELS"].update(takedamage="Hit", fidget2="Fidget2")
    pipeline["reuse"].RECIPES[KIND] = {"floor_sample_rate": 120, "measure_motion_bounds": True}
    table = pipeline["table_rows"]((extracted / "Client/Models.txt").read_bytes())
    for row in table:
        row["source_table_stem"] = row["stem"]
        row["stem"] = row["stem"].casefold()

    class LocalMembers:
        def read(self, name):
            return (extracted / name).read_bytes()

    names = {name.casefold(): name for name in pins}
    _, native = pipeline["native_bodies"]()
    record, = pipeline["prepare"](KIND, LocalMembers(), names, table, native, selected_kinds={KIND})
    if record["status"] != "prepared" or len(record["clip_sources"]) != 13 or record["rejected_source_clips"]:
        raise ValueError(f"Lady Melisande export failed: {record.get('blocker', record['rejected_source_clips'])}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    reference = json.loads((ROOT / "scripts/later-creature-inputs.json").read_bytes())
    args.output.mkdir(parents=True, exist_ok=True)
    export_creature(ROOT, args.output, args.source, reference["bodies"]["258"]["reference"]["legacy_members"])


if __name__ == "__main__":
    main()
