# SPDX-License-Identifier: GPL-3.0-or-later
"""Extract the pinned rigid hammer and atlas from the local 3D client files."""

import argparse
import json
from pathlib import Path
import runpy


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "work/creatures/native-form-audit/enhanced-source-gaps/bird-ettin"
MESH_SHA256 = "b23e9be0b06c04dde940cff8322541a0b1e8d920e7a23526867e9eeec7f34155"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Local extracted Age of Shadows Models directory")
    source = parser.parse_args().source
    importer = runpy.run_path(str(ROOT / "scripts/import-third-dawn.py"))
    rigid = runpy.run_path(str(ROOT / "scripts/prepare-lizardman-weapons.py"))
    member = source / "Others/weapon_ettin_hammer_lod2.grn"
    corners = rigid["rigid_mesh_corners"](importer["parse"], member, MESH_SHA256, 38, 68)
    atlas = rigid["pinned_bytes"](source / "Maps/weapons_512b.tga", rigid["ATLAS_SHA256"])
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / "ettin-hammer-corners.json").write_text(json.dumps(corners), encoding="utf-8")
    (OUTPUT / "ettin-hammer-atlas.png").write_bytes(importer["png_from_tga"](atlas))
    print(f"Ettin hammer: {len(corners) // 3} source triangles, original atlas and UVs")


if __name__ == "__main__":
    main()
