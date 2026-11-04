"""Export the original Skeleton Axe for the private body 56 trial."""

import argparse
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'work/creatures/skeleton-axe'
MEMBER = 'Others/weapon_skeleton_axe_lod2.grn'
DIGEST = '8a4ffbda38101ea4d936e6590df8f0be2b748eb289e68c8b16288734a9d7dc24'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='Local extracted Third Dawn Models directory')
    source = parser.parse_args().source
    importer = runpy.run_path(str(ROOT / 'scripts/import-third-dawn.py'))
    rigid = runpy.run_path(str(ROOT / 'scripts/prepare-lizardman-weapons.py'))
    corners = rigid['rigid_mesh_corners'](importer['parse'], source / MEMBER, DIGEST, 41, 66)
    atlas = rigid['pinned_bytes'](source / 'Maps/weapons_512b.tga', rigid['ATLAS_SHA256'])
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / 'corners.json').write_text(json.dumps(corners), encoding='utf-8')
    (OUTPUT / 'atlas.png').write_bytes(importer['png_from_tga'](atlas))
    print('Skeleton Axe: 41 vertices, 66 triangles and the pinned source atlas.')


if __name__ == '__main__':
    main()
