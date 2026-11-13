# SPDX-License-Identifier: GPL-3.0-or-later
"""Assemble the optional Raptor/Slith profile from verified local inputs."""

from argparse import ArgumentParser
from hashlib import sha256
import json
from pathlib import Path
import runpy
from shutil import copyfile


Sequence = "d474b11e3f7e68d3651e3feea1d063ab8f20b77fa0c92fec1fa1eb473a14c7d6"
Members = {730: "0x9fed8396eb2a2d", 734: "0xafc4399ccb01be12"}
Motions = {
    730: ("RaptorRearAndSnap", "RaptorRearingKick", "RaptorHeadRecoil",
          "RaptorForwardFall", "RaptorRearFall"),
    734: ("SlithHeadFeint", "SlithLowTailStrike", "SlithRaisedRecoil",
          "SlithDippingFall", "SlithRearingFall"),
}
References = {
    730: {
        2: (50, "91497fba869048937d51495fdd1e1bae1b585bafbde2eba88024369107c334a1"),
        3: (35, "5382d5606fbf0d69d09c45389c33302ecc19c885cac412dde44a42d4fbd211a5"),
        5: (45, "acc0de10cee6a9119dd9c5d85fe99759dd5262cb4f5cf5c4b7bda26b5f86f9b5"),
        10: (35, "f22cd6b4b2df25554ad336a439688d91a386f776e6837986ea6dc763afb0ae12"),
    },
    734: {
        2: (50, "1dcf4c184d99feb56edb32ddaaafc6102789796f3cfbda15881ca49d5b435059"),
        3: (40, "63d5b9bd49dc1e06aefcd79878b5995e23a7455523a29582397a3917432d3b99"),
        5: (45, "a55589ffa2765afebfe08967c31dc317a4e9f99787b62218ac207bc6bc08d443"),
        10: (35, "9ec14ce9961ced96e4886445ec3165e2f3d8415eeaad05270917eca870f675e8"),
    },
}
ActionGroups = {
    (0, -1): [4, 5, 4, 4, 4, 4],
    (0, 0): [4, 5, 4], (0, 1): [4], (0, 2): [4], (0, 9): [4],
    (3, -1): [2, 3], (4, -1): [10],
}
Relative = Path("local-art/creatures/enhanced-reptile-variants")


def check_references(inputs, sequence, scripts):
    if sha256(sequence.read_bytes()).hexdigest() != Sequence:
        raise ValueError("The Enhanced AnimationSequence.uop digest differs from 4.0.117.33.")
    inspect = runpy.run_path(str(scripts / "uo-human-sequences.py"))["inspect"]
    decode = runpy.run_path(str(scripts / "uo-enhanced-frames.py"))["read_amou"]
    relevant = {kind for kind, _ in ActionGroups}
    for body, member in Members.items():
        record, = [row for row in inspect(sequence, {body}) if row["uop_name_hash"] == member]
        combat, peace = record["modes"]
        actions = {(row["type"], row["subaction"]): row["groups"]
                   for row in combat["new_protocol_actions"] if row["type"] in relevant}
        if record["unparsed_bytes"] or (combat["mode"], peace["mode"], peace["fallback_mode"]) != (0, 1, 0) \
                or actions != ActionGroups or any(row["type"] in relevant for row in peace["new_protocol_actions"]):
            raise ValueError(f"Unexpected Enhanced action table for body {body}.")
        for group, (count, digest) in References[body].items():
            data = (inputs / f"ec-frame-{body}-{group}.bin").read_bytes()
            if sha256(data).hexdigest() != digest:
                raise ValueError(f"The Enhanced frame digest differs for {body}/{group}.")
            identity, frames = decode(data)
            if identity != body or len(frames) != count or {frame.group for frame in frames} != {group}:
                raise ValueError(f"Unexpected Enhanced frame identity for {body}/{group}.")


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--reference", required=True, type=Path)
    parser.add_argument("--sequence", required=True, type=Path)
    parser.add_argument("--scenes", required=True, type=Path)
    parser.add_argument("--input-viewer", type=Path, default=Path("Viewer"))
    parser.add_argument("--output-viewer", required=True, type=Path)
    args = parser.parse_args()
    check_references(args.reference, args.sequence, Path(__file__).resolve().parent)
    profile = args.input_viewer / "local-art/creatures/enhanced-creature-actions.json"
    base = json.loads(profile.read_text(encoding="utf-8-sig"))
    dest = args.output_viewer / Relative
    dest.mkdir(parents=True, exist_ok=True)
    rows, files = {}, {}
    for body, (primary, secondary, hit, first, second) in Motions.items():
        row = base["bodies"][str(body)]
        clips = {2: first, 3: second, 4: primary, 5: secondary, 10: hit}
        attacks = [(sub & 255, groups) for (kind, sub), groups in ActionGroups.items() if kind == 0]
        row["attack_subactions"] = {str(sub): [clips[group] for group in groups]
                                    for sub, groups in sorted(attacks)}
        row["groups"]["0"].update({"3": [first, second], "4": [hit]})
        row["grounded"] += [secondary, hit]
        for treatment in row["assets"]:
            filename = f"{body}-{treatment}.scn"
            scene = args.scenes / filename
            digest = sha256(scene.read_bytes()).hexdigest()
            files[dest / filename] = scene
            row["assets"][treatment] = {"path": f"res://{Relative.as_posix()}/{filename}", "sha256": digest}
        rows[str(body)] = row
    for target, source in files.items():
        pending = target.with_suffix(".pending")
        copyfile(source, pending)
        pending.replace(target)
    pending = dest / "profile.pending"
    pending.write_text(json.dumps({"schema": 1, "bodies": rows}, indent=2) + "\n", encoding="utf-8")
    pending.replace(dest / "profile.json")
    print(f"ENHANCED REPTILE VARIANTS: {len(rows)} bodies, {len(files)} fitted scenes")


if __name__ == "__main__":
    main()
