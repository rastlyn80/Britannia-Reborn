# SPDX-License-Identifier: GPL-3.0-or-later
"""Recover the owned Mondain's Legacy perch parrot with its original weighted wings."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import runpy
import struct


ROOT = Path(__file__).resolve().parents[1]


def parrot_body_chunks(chunks):
    # The two rigid wing objects duplicate animation-linked helper geometry
    # without a UV buffer. The textured mesh already skins both wings.
    groups = []
    texture_tables = []
    mesh_index = -1
    texture_group = -1
    for tag, data, parents in chunks:
        if tag == 0xca5e0601:
            mesh_index += 1
            groups.append({})
        if 0xca5e0601 in parents and tag in (0xca5e0801, 0xca5e0802, 0xca5e0803, 0xca5e0901, 0xca5e0702, 0xca5e0f04):
            groups[mesh_index][tag] = data
            if mesh_index > 0:
                continue
        if tag == 0xca5e0e02:
            texture_group, count = struct.unpack('<II', data)
            assert texture_group == len(texture_tables) and count == 3 - texture_group
        if tag == 0xca5e0e06:
            assert texture_group == len(texture_tables)
            texture_tables.append(struct.unpack_from('<I', data)[0])
            if texture_group in (0, 1):
                continue
        yield tag, data, parents

    assert texture_tables == [34, 34, 276]
    assert len(groups) == 3
    for group, object_id in zip(groups[1:], (7, 22), strict=True):
        assert struct.unpack('<I',group[0xca5e0f04])[0] == object_id
        assert group[0xca5e0702] == bytes(12) and 0xca5e0803 not in group
        assert len(group[0xca5e0801]) == 25 * 12 and len(group[0xca5e0901]) == 34 * 24
    actor = groups[0]
    assert struct.unpack('<I',actor[0xca5e0f04])[0] == 12
    assert struct.unpack_from('<I',actor[0xca5e0702])[0] == 180
    assert len(actor[0xca5e0901]) == 276 * 24


def export_parrot(root, output, source, pins):
    paths = {name: source / name for name in pins}
    for name, path in paths.items():
        if hashlib.sha256(path.read_bytes()).hexdigest() != pins[name]:
            raise ValueError(f"Perch parrot source differs: {name}")
    spec = importlib.util.spec_from_file_location("ml_parrot_pipeline", root / "scripts/prepare-creatures.py")
    pipeline = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(pipeline)
    pipeline.OUTPUT = output

    class CabinetMembers:
        def read(self, name):
            return paths[name].read_bytes()

    table = pipeline.table_rows(paths["Client/Models.txt"].read_bytes())
    for row in table:
        row["source_table_stem"] = row["stem"]
        row["stem"] = row["stem"].casefold()
    _, native = pipeline.native_bodies()
    pipeline.LABELS.update(fidget2="Fidget2")
    # Match the size of the house perch rather than the table's larger model scale.
    pipeline.HEIGHTS["parrot"] = 0.33
    pipeline.reuse.RECIPES["parrot"] = {"floor_sample_rate": 120, "measure_motion_bounds": True}
    original_chunks = pipeline.td.chunks
    mesh_bytes = paths["Client/Models/Animals/Parrot_LOD2.grn"].read_bytes()

    mesh_palettes = runpy.run_path(str(root / "scripts/grn-mesh-palettes.py"))["mesh_palettes"]
    palettes, headers = mesh_palettes(mesh_bytes, pipeline.td)
    if headers != [(180, 24, 4), (0, 0, 0), (0, 0, 0)] or list(palettes) != [3, 2, 1]:
        raise ValueError("Unexpected perch parrot joint palettes")
    _, body_joints = palettes[1]
    parse_original = pipeline.td.parse

    def chunks(raw):
        if raw == mesh_bytes:
            yield from parrot_body_chunks(original_chunks(raw))
        else:
            yield from original_chunks(raw)

    def parse(raw, **options):
        body = parse_original(raw, **options)
        if raw == mesh_bytes and not options.get("animations_only"):
            if body["ties"] != [joint for _, joints in palettes.values() for joint in joints]:
                raise ValueError("Unexpected combined perch parrot joint ties")
            if max(index for weights in body["weights"] for index, _ in weights) != len(body_joints) - 1:
                raise ValueError("Perch parrot weight outside its local joint palette")
            body["ties"] = body_joints
        return body

    pipeline.td.chunks = chunks
    pipeline.td.parse = parse
    record, = pipeline.prepare("parrot", CabinetMembers(), {name.casefold(): name for name in pins},
                               table, native, selected_kinds={"parrot"})
    if record["status"] != "prepared" or set(record["clip_sources"]) != {"Idle", "Walk", "Fidget", "Fidget2"}:
        raise ValueError(f"Perch parrot export failed: {record.get('blocker', record.get('rejected_source_clips'))}")



def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    inputs = json.loads((ROOT / "scripts/later-creature-inputs.json").read_bytes())
    export_parrot(ROOT, args.output, args.source, inputs["bodies"]["282"]["reference"]["legacy_members"])


if __name__ == "__main__":
    main()
