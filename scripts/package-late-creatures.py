"""Install the recovered previews as a private, inactive test package."""
import json
from pathlib import Path
import runpy
from shutil import copyfile

SOURCE = runpy.run_path(str(Path(__file__).with_name('prepare-late-creatures.py')))
ROOT, BASE, FAMILIES = (SOURCE[key] for key in ('ROOT', 'BASE', 'FAMILIES'))
SHA = SOURCE['TOOLS']['sha']
PREVIEWS = BASE / 'dryad-troglodyte-ferret-preview'
VIEWER = ROOT / 'Viewer'
TARGET = VIEWER / 'local-art/creatures/late_source'
RES = 'res://local-art/creatures/late_source/'
CONSTRUCTORS = {
    'dryad': {'MLDryad': 0, 'InsaneDryad': 0},
    'troglodyte': {'Troglodyte': 0, 'Lurg': 0x455},
    'ferret': {'Ferret': 0},
}
INHERITED = {
    'dryad': 'Projects/UOContent/Mobiles/Monsters/ML/Blighted Grove/InsaneDryad.cs',
    'troglodyte': 'Projects/UOContent/Mobiles/Monsters/ML/Painted Caves/Lurg.cs',
}


def main():
    recipe = Path(__file__).with_name('prepare-late-creatures.py')
    manifest = SOURCE['MANIFEST']
    rows = []
    TARGET.mkdir(parents=True, exist_ok=True)
    for family, body in FAMILIES.items():
        report = json.loads((PREVIEWS / family / 'preparation.json').read_text(encoding='utf-8'))
        if report['late_recipe_sha256'] != SHA(recipe) or report['input_manifest_sha256'] != SHA(manifest):
            raise ValueError(f'Rebuild the {family} preview before packaging')
        row, = report['models']
        identity, = row['bodies']
        if row['status'] != 'prepared' or identity['body'] != body:
            raise ValueError(f'Unexpected preview identity for {family}')
        row['native_constructor_hues'] = CONSTRUCTORS[family]
        if family in INHERITED:
            path = INHERITED[family]
            identity['native_sources'].append({'path': path, 'sha256': SHA(ROOT / 'Server/ModernUO' / path)})
        row['assets'] = {}
        row['asset_sha256'] = {}
        for variant in ('original', 'rounded', 'modern'):
            name = f'{family}-{variant}.gltf'
            copyfile(PREVIEWS / name, TARGET / name)
            row['assets'][variant] = RES + name
            row['asset_sha256'][variant] = SHA(TARGET / name)
        dependencies = {}
        for name, digest in row.get('art_dependency_sha256', {}).items():
            if SHA(PREVIEWS / name) != digest:
                raise ValueError(f'Preview dependency changed: {name}')
            copyfile(PREVIEWS / name, TARGET / name)
            dependencies[RES + name] = digest
            if row.get('source_alpha_texture') == name:
                row['source_alpha_texture'] = 'late_source/' + name
        row['art_dependency_sha256'] = dependencies
        rows.append(row)
    pending = TARGET / 'preparation.pending'
    pending.write_text(json.dumps({'models': rows, 'source_manifest_sha256': SHA(manifest)},
                                  indent=2) + '\n', encoding='utf-8')
    pending.replace(TARGET / 'preparation.json')
    print(f'Packaged {len(rows)} inactive local creature routes')


if __name__ == '__main__':
    main()
