"""Prepare Corporeal Brume with the archived Slime as a visual donor."""
import json
from pathlib import Path
import runpy
from shutil import copyfile

TOOLS = runpy.run_path(str(Path(__file__).with_name('prepare-hydra.py')))
ROOT, SHA, checked = (TOOLS[key] for key in ('ROOT', 'SHA', 'checked'))
MANIFEST = Path(__file__).with_name('corporeal-brume-inputs.json')
VIEWER = ROOT / 'Viewer'
BASE = VIEWER / 'local-art/creatures'
FAMILY = 'corporeal_brume'


def main():
    pins = json.loads(MANIFEST.read_text(encoding='utf-8'))
    checked(ROOT / 'Server/ModernUO' / pins['native_path'], pins['native_sha256'])
    index = json.loads((BASE / 'accepted-index.json').read_text(encoding='utf-8-sig'))
    donor, = [row for row in index['entries'] if row['kind'] == 'slimes_slime']
    fields = ('profile', 'inputs', 'clip_sources', 'stats', 'pose_subdivision', 'movement_mode',
              'source_atlas_texture', 'amorphous_surface', 'category_aliases')
    row = {name: donor[name] for name in fields}
    atlas = BASE / row['source_atlas_texture']
    checked(atlas, pins['donor_atlas_sha256'])
    source = checked(BASE / 'slimes_slime-modern.gltf', pins['donor_scene_sha256'])
    scene = json.loads(source.read_text(encoding='utf-8'))
    if any(not item.get('uri', 'data:').startswith('data:')
           for item in scene['buffers'] + scene['images']):
        raise ValueError('Slime donor scene must be self-contained')

    destination = BASE / FAMILY
    destination.mkdir(parents=True, exist_ok=True)
    asset = destination / 'brume.gltf'
    copyfile(source, asset)
    asset_uri = f'res://local-art/creatures/{FAMILY}/{asset.name}'
    renderer = 'Presentation/CorporealBrumeVisual.gd'
    dependencies = ('Presentation/CorporealBrumeSurface.gdshader', 'Presentation/SourceAmorphousVisual.gd',
                    'Presentation/SourcePoseSubdivision.gd', 'Presentation/SourceGroundLookup.gd',
                    atlas.relative_to(VIEWER).as_posix())
    variants = ('original', 'rounded', 'modern')
    row.update(
        kind=FAMILY, family=FAMILY, status='prepared',
        bodies=[{'body': 260, 'native': 'Corporeal Brume', 'native_profile': 'monster', 'scale': [1.3] * 3,
                 'native_sources': [{'path': pins['native_path'], 'sha256': pins['native_sha256']}]}],
        native_constructor_hues={'CorporealBrume': 0},
        presentation_script=f'res://{renderer}', presentation_script_sha256=SHA(VIEWER / renderer),
        art_dependency_sha256={f'res://{name}': SHA(VIEWER / name) for name in dependencies},
        assets=dict.fromkeys(variants, asset_uri), asset_sha256=dict.fromkeys(variants, SHA(asset)),
        source_interpretation='Third Dawn Slime mesh and motions adapted to a historical Brume screenshot. '
                              'The pinned server provisionally uses body 260; the classic tables label it Travesty.',
    )
    pending = destination / 'preparation.pending'
    pending.write_text(json.dumps({'models': [row], 'input_manifest_sha256': SHA(MANIFEST)}, indent=2) + '\n',
                       encoding='utf-8')
    pending.replace(destination / 'preparation.json')


if __name__ == '__main__':
    main()
