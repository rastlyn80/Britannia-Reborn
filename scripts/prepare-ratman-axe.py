# SPDX-License-Identifier: GPL-3.0-or-later
"""Extract the original Ratman prop and atlas into the private local build folder."""

import argparse
import json
from pathlib import Path
import runpy


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "work/creatures/native-form-audit/enhanced-source-gaps/troll-ratman"
MESH_SHA256 = "b7d77ee4b4b798fa71788726dc6e264d6f519d51d14117c03fed2cf84ca2ff68"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Local extracted Age of Shadows Models directory")
    source = parser.parse_args().source
    importer = runpy.run_path(str(ROOT / "scripts/import-third-dawn.py"))
    rigid = runpy.run_path(str(ROOT / "scripts/prepare-lizardman-weapons.py"))
    member = source / "Others/weapon_ratman_axe_lod2.grn"
    corners = rigid["rigid_mesh_corners"](importer["parse"], member, MESH_SHA256, 41, 66)
    atlas = rigid["pinned_bytes"](source / "Maps/weapons_512b.tga", rigid["ATLAS_SHA256"])
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / "ratman-axe-corners.json").write_text(json.dumps(corners), encoding="utf-8")
    (OUTPUT / "ratman-axe-atlas.png").write_bytes(importer["png_from_tga"](atlas))
    print(f"Ratman axe: {len(corners) // 3} source triangles with the original atlas and UVs")


if __name__ == "__main__":
    main()
