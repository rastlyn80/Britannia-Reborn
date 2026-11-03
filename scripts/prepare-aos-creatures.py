"""Rebuild original Age of Shadows creatures from statically extracted archive members."""
import argparse
from copy import deepcopy
import json
from pathlib import Path
import runpy
from shutil import copyfile

HERE = Path(__file__).resolve().parent
LATE = runpy.run_path(str(HERE / 'prepare-hydra.py'))
ROOT, BASE, SHA = (LATE[key] for key in ('ROOT', 'BASE', 'SHA'))
MANIFEST = HERE / 'aos-creature-inputs.json'
FAMILY = 'aos_creatures'
FORMS = {
    306: ('impaler', ('Impaler',), 37, 7),
    307: ('gibberling', ('Gibberling',), 43, 8),
    308: ('bonedemon', ('BoneDemon',), 56, 10),
    313: ('darknight_creeper', ('DarknightCreeper',), 81, 8),
    318: ('demon_knight', ('DemonKnight',), 78, 8),
}
ALIAS_FORMS = {
    315: ('flesh_renderer', ('FleshRenderer',), 78, 8),
    316: ('wander', ('WandererOfTheVoid',), 97, 8),
}
ALIASES = {
    315: ('bip01 bip01bone rb2', 'bip01 bone rb2', 'bip01 bone rb1'),
    316: ('head', 'bip01 head', 'neck2'),
}


def checked(path, digest):
    if SHA(path) != digest:
        raise ValueError(f'Unexpected archive input: {path}')
    return path


def match_alias(animation, body, match, alias):
    old, new, parent = alias
    candidates = [bone for bone in animation['bones'] if bone['name'] == old]
    if not candidates:
        return match(animation, body)
    source, = candidates
    target, = [bone for bone in body['bones'] if bone['name'] == new]
    if (any(bone['name'] == new for bone in animation['bones'])
            or animation['bones'][source['parent']]['name'] != parent
            or body['bones'][target['parent']]['name'] != parent
            or any(abs(a - b) > 0.0001 for a, b in zip(source['translation'], target['translation']))):
        raise ValueError(f'Unrecognised animation joint alias: {old}')
    animation = deepcopy(animation)
    for channel in animation['bones'] + animation['tracks']:
        if channel['name'] == old:
            channel['name'] = new
    return match(animation, body)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--alias-batch', action='store_true')
    args = parser.parse_args()
    family = 'aos_aliases' if args.alias_batch else FAMILY
    forms = ALIAS_FORMS if args.alias_batch else FORMS
    manifest_path = HERE / 'aos-creature-alias-inputs.json' if args.alias_batch else MANIFEST
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    table = checked(BASE / 'model-table/Client/Models.txt', manifest['model_table_sha256'])
    members = {name.lower(): checked(BASE / 'aos-creature-source' / name, digest)
               for name, digest in manifest['files'].items()}

    class Inputs:
        def read(self, name):
            return members[name].read_bytes()

    pipeline = LATE['TOOLS']['pipeline']()
    pipeline.helper.audit.ARCHIVE_HASH = manifest['installer_sha256']
    pipeline.OUTPUT = BASE / ('aos-alias-preview' if args.alias_batch else 'aos-creature-preview')
    rows = pipeline.table_rows(table.read_bytes())
    _, native = pipeline.native_bodies()
    names = {name: name for name in members}
    destination = ROOT / 'Viewer/local-art/creatures' / family
    destination.mkdir(parents=True, exist_ok=True)
    models = []
    match = pipeline.helper.match_animation
    for body, (kind, native_classes, joints, motions) in forms.items():
        selected = [row for row in rows if row['stem'] != kind or row['body'] == body]
        if body in ALIASES:
            alias = ALIASES[body]
            pipeline.helper.match_animation = lambda animation, mesh: match_alias(animation, mesh, match, alias)
        try:
            row, = pipeline.prepare(kind.split('_')[0], Inputs(), names, selected, native,
                                    selected_kinds={kind})
        finally:
            pipeline.helper.match_animation = match
        if row['status'] != 'prepared':
            raise ValueError(f'{kind} conversion failed: {row.get("blocker")}')
        identity, = row['bodies']
        if (identity['body'] != body or row['stats']['original']['bones'] != joints
                or len(row['clip_sources']) != motions):
            raise ValueError(f'Unexpected rig or recovered motions for {kind}')
        for source in identity['native_sources']:
            checked(ROOT / 'Server/ModernUO' / source['path'].replace(chr(92), '/'), source['sha256'])
        row.update(family=family, native_constructor_hues=dict.fromkeys(native_classes, 0),
                   assets={}, asset_sha256={}, art_dependency_sha256={})
        if body in ALIASES:
            row['animation_joint_alias'] = dict(zip(('source', 'bind', 'parent'), ALIASES[body]))
        renderer = 'Presentation/OccurrenceCreatureVisual.gd'
        if body == 313:
            renderer = 'Presentation/SourcePreservingCreatureVisual.gd'
            row['limb_support'] = 'plane'
            dependency = 'Presentation/SourceGroundLookup.gd'
            row['art_dependency_sha256'][f'res://{dependency}'] = SHA(ROOT / 'Viewer' / dependency)
        row['presentation_script'] = f'res://{renderer}'
        row['presentation_script_sha256'] = SHA(ROOT / 'Viewer' / renderer)
        for treatment in ('original', 'rounded', 'modern'):
            filename = f'{kind}-{treatment}.gltf'
            copyfile(pipeline.OUTPUT / filename, destination / filename)
            row['assets'][treatment] = f'res://local-art/creatures/{family}/{filename}'
            row['asset_sha256'][treatment] = SHA(destination / filename)
        models.append(row)
    pending = destination / 'preparation.pending'
    pending.write_text(json.dumps({'models': models, 'input_manifest_sha256': SHA(manifest_path)},
                                  indent=2) + '\n', encoding='utf-8')
    pending.replace(destination / 'preparation.json')


if __name__ == '__main__':
    main()
