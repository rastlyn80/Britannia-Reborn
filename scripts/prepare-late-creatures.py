"""Prepare private Dryad, Troglodyte and Ferret scenes from extracted UOML files."""
import argparse
import json
from pathlib import Path
import runpy

TOOLS = runpy.run_path(str(Path(__file__).with_name('prepare-gazer-larva-source.py')))
ROOT = TOOLS['ROOT']
BASE = ROOT / 'work/creatures/late-client-inputs'
MANIFEST = Path(__file__).with_name('late-creature-inputs.json')
FAMILIES = {'dryad': 266, 'troglodyte': 267, 'ferret': 279}
TOE_HELPERS = {'bip01 l toe0nub', 'bip01 r toe0nub'}


def verify_file(path, pin):
    if path.stat().st_size != pin['bytes'] or TOOLS['sha'](path) != pin['sha256']:
        raise ValueError(f'Unexpected source input: {path}')


def match_dryad(animation, body, match):
    # The mesh binds these unweighted leaves to the root. Every source clip
    # inserts a toe bone above each leaf. Preserve the full bind and skin.
    indices = {i for i, bone in enumerate(body['bones']) if bone['name'] in TOE_HELPERS}
    weighted = any(joint in indices and weight > 0 for point in body['weights'] for joint, weight in point)
    has_children = any(i not in indices and bone['parent'] in indices
                       for i, bone in enumerate(body['bones']))
    if len(indices) != 2 or weighted or has_children:
        raise ValueError('Dryad toe-helper omission requires two unweighted leaf joints')
    retained = [bone for i, bone in enumerate(body['bones']) if i not in indices]
    return match(animation, dict(body, bones=retained))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--families', nargs='+', choices=FAMILIES, default=list(FAMILIES))
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    table_path = BASE / 'model-table/Client/Models.txt'
    verify_file(table_path, manifest['model_table'])
    members = {}
    for name, pin in manifest['files'].items():
        path = BASE / 'dryad-troglodyte-ferret-source' / name
        verify_file(path, pin)
        members[name.lower()] = path

    class Inputs:
        def read(self, name):
            return members[name].read_bytes()

    pipeline = TOOLS['pipeline']()
    pipeline.helper.audit.ARCHIVE_HASH = manifest['installer_sha256']
    pipeline.OUTPUT = BASE / 'dryad-troglodyte-ferret-preview'
    pipeline.OUTPUT.mkdir(exist_ok=True)
    table = pipeline.table_rows(table_path.read_bytes())
    _, native = pipeline.native_bodies()
    names = {name: name for name in members}
    match = pipeline.helper.match_animation
    humanoid_actions = pipeline.humanoid_actions
    install_humanoid_actions = humanoid_actions.install

    def install_actions(body, clips, authored, aliases, stem):
        if stem == 'dryad':
            if 'Cast' not in clips:
                clips['Cast'] = humanoid_actions.gesture(body, clips['Idle'], 'Cast')
                authored['Cast'] = 'Authored arm reach and planted stance on the recovered Dryad rig.'
            return True
        return install_humanoid_actions(body, clips, authored, aliases, stem)

    humanoid_actions.install = install_actions
    pipeline.LABELS.update(takedamage='Hit', fidget2='Fidget2', idle2='Idle2',
                           misc='Misc', grazing='Eat', lying='LieDown')
    for family in args.families:
        body = FAMILIES[family]
        pipeline.helper.match_animation = (
            (lambda animation, model: match_dryad(animation, model, match))
            if family == 'dryad' else match)
        row, = pipeline.prepare(family, Inputs(), names, table, native)
        if row['status'] != 'prepared' or [entry['body'] for entry in row['bodies']] != [body]:
            raise RuntimeError(f'{family} preparation failed: {row.get("blocker", row["status"])}')
        if not {'Idle', 'Walk', 'Hit', 'Death', 'Death2'} <= row['clip_sources'].keys():
            raise RuntimeError(f'{family} lost required archive motions')
        report_path = pipeline.OUTPUT / family / 'preparation.json'
        report = json.loads(report_path.read_text(encoding='utf-8'))
        report['input_manifest_sha256'] = TOOLS['sha'](MANIFEST)
        report['late_recipe_sha256'] = TOOLS['sha'](Path(__file__))
        if family == 'dryad':
            atlas = 'dryad-original-albedo.png'
            prepared = report['models'][0]
            prepared['source_alpha_texture'] = atlas
            prepared['art_dependency_sha256'] = {atlas: TOOLS['sha'](pipeline.OUTPUT / atlas)}
            if 'Cast' in prepared['clip_sources'] or 'Cast' not in prepared['authored_replacements']:
                raise RuntimeError('Dryad cast must be an authored gesture on the recovered rig')
        if family == 'ferret':
            renderer = 'Presentation/SourceFerretVisual.gd'
            report['models'][0].update(
                presentation_script='res://' + renderer,
                presentation_script_sha256=TOOLS['sha'](ROOT / 'Viewer' / renderer))
        report_path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        print(f'{family} {body}: {len(row["clip_sources"])} linked archive motions', flush=True)


if __name__ == '__main__':
    main()
