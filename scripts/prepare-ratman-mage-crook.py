# SPDX-License-Identifier: GPL-3.0-or-later
"""Extract the pinned Ratman Mage crook inputs from local Third Dawn Models."""

import argparse
import hashlib
import json
import runpy
from pathlib import Path


def extract(scripts, source):
    pins = runpy.run_path(str(scripts / "prepare-ratman-mage-lava-serpent-enhanced.py"))
    decoder = runpy.run_path(str(scripts / "import-third-dawn.py"))
    pinned_bytes = runpy.run_path(str(scripts / "prepare-lizardman-weapons.py"))["pinned_bytes"]
    mesh = "Others/weapon_crook_lod2.grn"
    atlas = "Maps/weapons_512.tga"
    model = decoder["parse"](pinned_bytes(source / mesh, pins["CROOK_SHA256"]))
    assert len(model["points"]) == 48 and len(model["polygons"]) == 92
    assert not model["weights"] and model["textures"] == ["weapons_512.tga"]
    corners = []
    for polygon, uv in zip(model["polygons"], model["texture_polygons"], strict=True):
        for index in (0, 2, 1):
            corners.append([*model["points"][polygon[index]], *model["normals"][polygon[index + 3]],
                            *model["uv_sets"][-1][uv[index]][:2]])
    texture = decoder["png_from_tga"](pinned_bytes(source / atlas, pins["ATLAS_SHA256"]))
    proof = {"crook": {"source": mesh, "sha256": pins["CROOK_SHA256"], "vertices": 48, "triangles": 92,
                       "textures": {"weapons_512.tga": pins["ATLAS_SHA256"]}}}
    return {"crook.json": json.dumps(corners).encode("ascii"), "weapons_512.png": texture,
            "crook-source.json": (json.dumps(proof, indent=2) + "\n").encode("ascii")}


def main():
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Local extracted Third Dawn Models directory")
    args = parser.parse_args()
    output = root / "work/creatures/native-form-audit/enhanced-source-gaps/ratman-mage-lava-serpent/staff-reference"
    output.mkdir(parents=True, exist_ok=True)
    for name, data in extract(root / "scripts", args.source).items():
        (output / name).write_bytes(data)
        print(f"{name} {hashlib.sha256(data).hexdigest()}")


if __name__ == "__main__":
    main()
