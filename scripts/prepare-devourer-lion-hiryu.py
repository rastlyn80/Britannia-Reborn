"""Rebuild Devourer, Revenant Lion and Hiryu from statically extracted archive members."""
import argparse
import copy
import json
from pathlib import Path
import runpy
from shutil import copyfile

HERE = Path(__file__).resolve().parent
LATE = runpy.run_path(str(HERE / 'prepare-hydra.py'))
ROOT, BASE, SHA = (LATE[key] for key in ('ROOT', 'BASE', 'SHA'))
MANIFEST = HERE / 'devourer-lion-hiryu-inputs.json'
FAMILY = 'devourer_lion_hiryu'
FORMS = {
    303: ('devourer', ('Devourer',), 55, 8),
    251: ('vampyric_beast', ('RevenantLion',), 25, 11),
    243: ('hai_riyo', ('Hiryu', 'LesserHiryu'), 28, 11),
}
NUBS = {f'bip01 {side} {part}0nub' for side in ('l', 'r') for part in ('finger', 'toe')}
HIRYU_HUES = {
    'Hiryu': (0, 0x85c, 0x490, 0x030, 0x037, 0x295, 0x123, 0x482, 0x487, 0x8a5,
              0x979, 0x495, 0x48d, 0x47f),
    'LesserHiryu': (0, 0x258, 0x8ab, 0x7d4, 0x163, 0x295),
}


def match_devourer(match, animation, body):
    removed = {i for i, bone in enumerate(body['bones']) if bone['name'] in NUBS}
    if (len(removed) != len(NUBS)
            or any(body['ties'][tie] in removed and weight > 0
                   for weights in body['weights'] for tie, weight in weights)
            or any(bone['parent'] in removed for bone in body['bones'])):
        raise ValueError('Devourer finger and toe nubs must be unweighted leaves')
    kept = [i for i in range(len(body['bones'])) if i not in removed]
    remap = {old: new for new, old in enumerate(kept)}
    retained = [dict(body['bones'][i], parent=remap[body['bones'][i]['parent']]) for i in kept]
    return match(animation, dict(body, bones=retained))


def checked(path, digest):
    if SHA(path) != digest:
        raise ValueError(f'Unexpected archive input: {path}')
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mounted-hiryu', action='store_true')
    args = parser.parse_args()
    family = 'hiryu_mount' if args.mounted_hiryu else FAMILY
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    table = checked(BASE / 'model-table/Client/Models.txt', manifest['model_table_sha256'])
    for path, digest in manifest['native_dependencies'].items():
        checked(ROOT / 'Server/ModernUO' / path, digest)
    members = {name.lower(): checked(BASE / 'devourer-lion-hiryu-source' / name, digest)
               for name, digest in manifest['files'].items()}

    class Inputs:
        def read(self, name):
            return members[name].read_bytes()

    pipeline = LATE['TOOLS']['pipeline']()
    pipeline.helper.audit.ARCHIVE_HASH = manifest['installer_sha256']
    pipeline.OUTPUT = BASE / ('hiryu-mount-preview' if args.mounted_hiryu else 'devourer-lion-hiryu-preview')
    rows = pipeline.table_rows(table.read_bytes())
    _, native = pipeline.native_bodies()
    names = {name: name for name in members}
    destination = ROOT / 'Viewer/local-art/creatures' / family
    destination.mkdir(parents=True, exist_ok=True)
    match = pipeline.helper.match_animation
    actions = pipeline.humanoid_actions
    install_actions = actions.install

    def install(body, clips, authored, aliases, kind):
        if kind == 'devourer' and 'Cast' not in clips:
            clips['Cast'] = actions.gesture(body, clips['Idle'], 'Cast')
            authored['Cast'] = 'Authored casting gesture on the original rig.'
        if kind == 'vampyric_beast' and 'Cast' not in clips:
            clips['Cast'] = copy.deepcopy(clips['Attack2'])
            aliases['Cast'] = 'Attack2: authored reuse of an original motion for casting packets.'
        return install_actions(body, clips, authored, aliases, kind)

    actions.install = install
    models = []
    for body, (kind, native_classes, joints, motions) in FORMS.items():
        if args.mounted_hiryu:
            if body != 243:
                continue
            pipeline.LABELS.update(fidget1='Fidget', fidget2='Fidget2')
            motions += 2
        selected = [row for row in rows if row['stem'] != kind or row['body'] == body]
        if body == 303:
            pipeline.helper.match_animation = lambda anim, mesh: match_devourer(match, anim, mesh)
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
        renderer = 'Presentation/OccurrenceCreatureVisual.gd'
        if args.mounted_hiryu:
            renderer = 'Presentation/SourceHiryuMountVisual.gd'
            row['mount_item'] = 0x3e94
            row['classic_action_categories'] = {'10': 'Fidget2'}
            dependency = 'Presentation/SourceRigMountVisual.gd'
            row['art_dependency_sha256'][f'res://{dependency}'] = SHA(ROOT / 'Viewer' / dependency)
        row['presentation_script'] = f'res://{renderer}'
        row['presentation_script_sha256'] = SHA(ROOT / 'Viewer' / renderer)
        if body == 303:
            row['unweighted_nubs_retained_in_bind'] = sorted(NUBS)
        if body == 243:
            row['native_mount_graphic'] = 0x3e94
            row['native_constructor_hue_ranges'] = {
                name: [[hue | 0x8000, hue | 0x8000] for hue in hues]
                for name, hues in HIRYU_HUES.items()
            }
        elif body == 303:
            row['authored_cast_recipe_sha256'] = SHA(HERE / 'creature-humanoid-actions.py')
        for treatment in ('original', 'rounded', 'modern'):
            filename = f'{kind}-{treatment}.gltf'
            copyfile(pipeline.OUTPUT / filename, destination / filename)
            row['assets'][treatment] = f'res://local-art/creatures/{family}/{filename}'
            row['asset_sha256'][treatment] = SHA(destination / filename)
        models.append(row)
    pending = destination / 'preparation.pending'
    pending.write_text(json.dumps({'models': models, 'input_manifest_sha256': SHA(MANIFEST)},
                                  indent=2) + '\n', encoding='utf-8')
    pending.replace(destination / 'preparation.json')


if __name__ == '__main__':
    main()
