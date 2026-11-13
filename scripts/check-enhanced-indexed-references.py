# SPDX-License-Identifier: GPL-3.0-or-later
"""Validate exact local Enhanced references for the indexed creature variants."""
from argparse import ArgumentParser
from hashlib import sha256
import json
from pathlib import Path
import runpy


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--sequence", type=Path, required=True)
    parser.add_argument("--frames", type=Path, required=True)
    parser.add_argument("--scripts", type=Path, default=Path(__file__).resolve().parent)
    args = parser.parse_args()

    scripts = Path(__file__).resolve().parent
    pins = json.loads((scripts / "enhanced-indexed-variant-inputs.json").read_bytes())
    if sha256(args.sequence.read_bytes()).hexdigest() != pins["sequence_sha256"]:
        raise ValueError("The sequence archive does not match Enhanced Client 4.0.117.33.")

    inspect = runpy.run_path(str(args.scripts / "uo-human-sequences.py"))["inspect"]
    decode = runpy.run_path(str(args.scripts / "uo-enhanced-frames.py"))["read_amou"]
    bodies = {row["animation_ref"] for row in pins["sequence_records"]}
    records = []
    for row in sorted(inspect(args.sequence, bodies), key=lambda row: row["animation_ref"]):
        if row["unparsed_bytes"]:
            raise ValueError(f"Unparsed data in sequence {row['animation_ref']}.")
        records.append({
            "animation_ref": row["animation_ref"],
            "uop_name_hash": row["uop_name_hash"],
            "modes": [
                {key: mode[key] for key in ("mode", "fallback_mode", "transitions", "new_protocol_actions")}
                for mode in row["modes"]
            ],
        })
    if records != pins["sequence_records"]:
        raise ValueError("The indexed action tables differ from the pinned tables.")

    total = 0
    for row in pins["frame_members"]:
        body, group = row["body"], row["group"]
        source = args.frames / f"ec-frame-{body}-{group}.bin"
        data = source.read_bytes()
        if sha256(data).hexdigest() != row["sha256"]:
            raise ValueError(f"Enhanced frame digest differs for body {body}, group {group}.")
        identity, frames = decode(data)
        if identity != body or {frame.group for frame in frames} != {group} or len(frames) != row["frames"]:
            raise ValueError(f"Unexpected Enhanced frame table for body {body}, group {group}.")
        total += len(frames)

    print(f"ENHANCED INDEXED REFERENCES: {len(bodies)} bodies, {len(pins['frame_members'])} members, {total} frames")


if __name__ == "__main__":
    main()
