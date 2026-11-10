from pathlib import Path
import hashlib
import json
import runpy

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "work/creatures/native-form-audit/enhanced-source-gaps/orc-shaman-ophidian-mage"
SOURCE = ROOT / "work/third-dawn/late-source-research/uoaos-source/Models"
STAFF = "Others/weapon_orc_shaman_staff_lod2.grn"
ATLAS = "Maps/weapons_512b.tga"
STAFF_SHA = "80368567f0edca6fcd54adad541fef37b397c7bd7681a59558c8745ff6ef1a3d"
ATLAS_SHA = "6b6db69ff83ce1950113b4c10965a42e730eb4887fab16e11ccfb064f661f720"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    import_grn = runpy.run_path(str(ROOT / "scripts/import-third-dawn.py"))
    rigid = runpy.run_path(str(ROOT / "scripts/prepare-lizardman-weapons.py"))
    atlas = (SOURCE / ATLAS).read_bytes()
    assert sha(atlas) == ATLAS_SHA
    staff = rigid["rigid_mesh_corners"](import_grn["parse"], SOURCE / STAFF, STAFF_SHA, 50, 96)
    assert len(staff) == 288
    corners = json.dumps(staff).encode("ascii")
    texture = import_grn["png_from_tga"](atlas)
    (OUT / "orc-shaman-staff-corners.json").write_bytes(corners)
    (OUT / "orc-shaman-staff-atlas.png").write_bytes(texture)
    proof = {
        "staff": STAFF, "sha256": STAFF_SHA, "atlas": ATLAS, "atlas_sha256": ATLAS_SHA,
        "points": 50, "triangles": 96, "corners_sha256": sha(corners), "png_sha256": sha(texture),
        "native_class": "OrcishMage", "native_body": 140, "purpose": "Original visible prop for the fitted actions",
    }
    (OUT / "orc-shaman-staff-source.json").write_text(json.dumps(proof, indent=2) + "\n", encoding="utf-8")
    print("Orc Shaman staff: 50 source points, 96 triangles, 512 atlas pinned.")


if __name__ == "__main__":
    main()

