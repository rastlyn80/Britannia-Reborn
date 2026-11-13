# SPDX-License-Identifier: GPL-3.0-or-later
"""Install locally baked indexed scenes after checking their registered base models."""
from argparse import ArgumentParser
from hashlib import sha256
import json
from pathlib import Path
from shutil import copyfile


VARIANTS = Path("local-art/creatures/enhanced-indexed-variants")
SOURCES = {
    692: ("animated-weapon-variants", "692.scn"),
    705: ("stone-form-enhanced", "705-{treatment}.scn"),
    831: ("parrot-variants", "831-{treatment}.scn"),
    1246: ("pumpkin-head-enhanced", "1246.scn"),
    1247: ("pumpkin-head-enhanced", "1247.scn"),
}


def digest(path):
    return sha256(path.read_bytes()).hexdigest()


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--baked", required=True, type=Path)
    parser.add_argument("--input-viewer", default=Path("Viewer"), type=Path)
    parser.add_argument("--output-viewer", required=True, type=Path)
    args = parser.parse_args()

    template = Path(__file__).with_name("enhanced-indexed-variant-routes.json")
    profile = json.loads(template.read_bytes())
    base_path = args.input_viewer / "local-art/creatures/accepted-index.json"
    registry = json.loads(base_path.read_bytes())["entries"]
    registered = {int(body["body"]): row for row in registry for body in row["bodies"]
                  if row.get("status") == "validated"}
    copies = {}
    for key, entry in profile["bodies"].items():
        body = int(key)
        base = registered[body]
        if base["kind"] != entry["kind"] or base["asset_sha256"] != entry["base_sha256"]:
            raise ValueError(f"Body {body} differs from the reviewed base registration.")
        folder, filename = SOURCES[body]
        entry["assets"] = {}
        for treatment, expected in entry["base_sha256"].items():
            original = args.input_viewer / base["assets"][treatment].removeprefix("res://")
            if digest(original) != expected:
                raise ValueError(f"Body {body} {treatment} base asset failed its digest check.")
            baked = args.baked / folder / filename.format(treatment=treatment)
            relative = VARIANTS / f"{body}-{treatment}.scn"
            copies[args.output_viewer / relative] = baked
            entry["assets"][treatment] = {"path": "res://" + relative.as_posix(), "sha256": digest(baked)}

    destination = args.output_viewer / VARIANTS
    destination.mkdir(parents=True, exist_ok=True)
    # Install the manifest last. The client only activates individually valid body rows.
    for target, source in copies.items():
        temporary = target.with_suffix(".pending")
        copyfile(source, temporary)
        temporary.replace(target)
    pending = destination / "profile.pending"
    pending.write_text(json.dumps(profile, indent=2) + "\n", encoding="utf-8")
    pending.replace(destination / "profile.json")
    print(f"ENHANCED INDEXED VARIANTS: {len(SOURCES)} body rows and {len(copies)} treatments")


if __name__ == "__main__":
    main()
