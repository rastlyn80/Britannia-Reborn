"""Rebuild the original Meer forms and their model-table human donors from statically extracted archive members."""
import json
from pathlib import Path
import runpy
from shutil import copyfile

HERE = Path(__file__).resolve().parent
LATE = runpy.run_path(str(HERE / 'prepare-hydra.py'))
ROOT, BASE, SHA = (LATE[key] for key in ('ROOT', 'BASE', 'SHA'))
MANIFEST = HERE / 'meer-donor-inputs.json'
FAMILY = 'meer_donors'
FORMS = {
    771: ('meer_warrior', ('MeerWarrior',), 34, 8),
    770: ('meer_mage', ('MeerMage',), 39, 7),
    773: ('npc_cpt_dasha', ('MeerCaptain',), 39, 7),
}
HUMAN_ROWS = (
    (400, 'h_male', [1.78, 1.54, 1.9]),
    (401, 'h_female', [1.85, 1.56, 1.96]),
)
COMMON_DONOR = {'idle': 'idle_01', 'walk': 'walk_01', 'run': 'run_01',
                'gethit': 'gethit_fr_mid_01'}
DONORS = {
    771: ('h_male', dict(COMMON_DONOR, attack1='attackslash1h_01', attack2='attackpierce2h_01',
                         die1='die_hard_twist_01', die2='die_hard_twist_02')),
    770: ('h_female', dict(COMMON_DONOR, attack1='attackbash1h_01', die1='die_hard_fwd_01', cast='spell1')),
    773: ('h_female', dict(COMMON_DONOR, attack1='attackbash1h_01', die1='die_hard_fwd_01',
                           attackxbow='attackcrossbow_01')),
}


def checked(path, digest):
    if SHA(path) != digest:
        raise ValueError(f'Unexpected archive input: {path}')
    return path


def main():
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    table = checked(BASE / 'model-table/Client/Models.txt', manifest['model_table_sha256'])
    members = {name.lower(): checked(BASE / 'elemental-minotaur-meer-source' / name, digest)
               for name, digest in manifest['files'].items()}

    class Inputs:
        def read(self, name):
            return members[name].read_bytes()

    pipeline = LATE['TOOLS']['pipeline']()
    pipeline.helper.audit.ARCHIVE_HASH = manifest['installer_sha256']
    pipeline.OUTPUT = BASE / 'meer-pinned-preview'
    rows = pipeline.table_rows(table.read_bytes())
    lines = [line.split() for line in table.read_text(encoding='latin1').splitlines()]
    for body, stem, scale in HUMAN_ROWS:
        row, = [line for line in lines if len(line) == 9 and line[0] == str(body)
                and line[-1].lower() == stem]
        if row[1:3] != ['3', '0'] or [float(value) for value in row[5:8]] != scale:
            raise ValueError(f'Unexpected human donor model-table row: {body}')
        rows.append(dict(body=body, stem=stem, type=3, animation_body=0, scale=scale))
    _, native = pipeline.native_bodies()
    destination = ROOT / 'Viewer/local-art/creatures' / FAMILY
    destination.mkdir(parents=True, exist_ok=True)
    models = []
    for body, (kind, native_classes, joints, motions) in FORMS.items():
        selected = [row for row in rows if row['stem'] != kind or row['body'] == body]
        donor, clips = DONORS[body]
        names = {name: name for name in members}
        for label, suffix in clips.items():
            member = f'client/models/humans/{donor}_{suffix}.grn'
            if member not in members:
                raise ValueError(f'Missing exact Meer donor: {member}')
            names[f'client/models/monsters/{donor}_{label}.grn'] = member
        row, = pipeline.prepare(kind.split('_')[0], Inputs(), names, selected, native,
                                selected_kinds={kind})
        if row['status'] != 'prepared':
            raise ValueError(f'{kind} conversion failed: {row.get("blocker")}')
        identity, = row['bodies']
        if (identity['body'] != body or row['stats']['original']['bones'] != joints
                or len(row['clip_sources']) != motions):
            raise ValueError(f'Unexpected rig or recovered motions for {kind}')
        for source in identity['native_sources']:
            checked(ROOT / 'Server/ModernUO' / source['path'].replace(chr(92), '/'), source['sha256'])
        row.update(family=FAMILY, native_constructor_hues=dict.fromkeys(native_classes, 0),
                   assets={}, asset_sha256={}, art_dependency_sha256={})
        if set(row['clip_sources'].values()) != {
                f'client/models/humans/{donor}_{suffix}.grn' for suffix in clips.values()}:
            raise ValueError('Meer conversion did not use all pinned donor clips')
        for treatment in ('original', 'rounded', 'modern'):
            filename = f'{kind}-{treatment}.gltf'
            copyfile(pipeline.OUTPUT / filename, destination / filename)
            row['assets'][treatment] = f'res://local-art/creatures/{FAMILY}/{filename}'
            row['asset_sha256'][treatment] = SHA(destination / filename)
        models.append(row)
    pending = destination / 'preparation.pending'
    pending.write_text(json.dumps({'models': models, 'input_manifest_sha256': SHA(MANIFEST)},
                                  indent=2) + '\n', encoding='utf-8')
    pending.replace(destination / 'preparation.json')


if __name__ == '__main__':
    main()
