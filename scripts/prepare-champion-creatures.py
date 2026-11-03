"""Convert the pinned Rikktor and Mephitis source meshes and linked motions."""
import json
import math
from pathlib import Path
import runpy
from shutil import copyfile
import statistics

HERE = Path(__file__).resolve().parent
LATE = runpy.run_path(str(HERE / 'prepare-hydra.py'))
ROOT, BASE, SHA, checked = (LATE[key] for key in ('ROOT', 'BASE', 'SHA', 'checked'))
MANIFEST = HERE / 'champion-creature-inputs.json'
FORMS = (
    ('dragons', 'dragons_dragon_retro_red', 172, 57, 10, 'Rikktor'),
    ('arachnids', 'arachnids_spider_black_widow', 173, 30, 7, 'Mephitis'),
)


def preserve_rikktor_death_units(animation, body):
    target = {bone['name']: bone for bone in body['bones']}
    ratios = []
    for bone in animation['bones']:
        source_length = math.hypot(*bone['translation'])
        target_length = math.hypot(*target[bone['name']]['translation'])
        if min(source_length, target_length) > 0.001:
            ratios.append(target_length / source_length)
    matching = sum(abs(ratio - 1.0) < 0.01 for ratio in ratios)
    if len(ratios) != 54 or matching != 53 or abs(statistics.median(ratios) - 1.0) >= 0.01:
        raise ValueError('Rikktor death clip no longer meets the measured same-unit contract')
    return animation, {
        'translation_factor': 1.0, 'measured_bones': len(ratios), 'same_unit_bones': matching,
        'ratio_range': [min(ratios), max(ratios)],
        'method': 'Native translation keys preserved. Matched lengths establish units, not exact poses.',
    }


def main():
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    table = checked(BASE / 'model-table/Client/Models.txt', manifest['model_table_sha256'])
    members = {name.lower(): checked(BASE / 'champions-source' / name, digest)
               for name, digest in manifest['files'].items()}

    class Inputs:
        def read(self, name):
            return members[name].read_bytes()

    pipeline = LATE['TOOLS']['pipeline']()
    pipeline.helper.audit.ARCHIVE_HASH = manifest['installer_sha256']
    pipeline.OUTPUT = BASE / 'champions-preview'
    rows = pipeline.table_rows(table.read_bytes())
    _, native = pipeline.native_bodies()
    names = {name: name for name in members}
    recipes = pipeline.reuse.RECIPES
    # Only the pinned Retro Red candidate reaches the dragon death-unit hook.
    pipeline.reuse.rescale_translation_units = preserve_rikktor_death_units
    package = []
    target = ROOT / 'Viewer/local-art/creatures/champions'
    target.mkdir(parents=True, exist_ok=True)
    res = 'res://local-art/creatures/champions/'
    for family, kind, body, joints, clips, native_class in FORMS:
        pipeline.reuse.RECIPES = {key: value for key, value in recipes.items() if key == kind}
        # Keep the animation donor rows and bake at this champion's own scale.
        selected_rows = [item for item in rows if item['stem'] != kind or item['body'] == body]
        row, = pipeline.prepare(family, Inputs(), names, selected_rows, native, selected_kinds={kind})
        if row['status'] != 'prepared':
            raise RuntimeError(f'{kind} failed: {row.get("blocker")}')
        if ([item['body'] for item in row['bodies']], row['stats']['original']['bones'],
                len(row['clip_sources'])) != ([body], joints, clips):
            raise ValueError(f'Unexpected original rig or clip assignment for {kind}')
        row.update(family='champions', native_constructor_hues={native_class: 0},
                   assets={}, asset_sha256={})
        for variant in ('original', 'rounded', 'modern'):
            name = f'{kind}-{variant}.gltf'
            copyfile(pipeline.OUTPUT / name, target / name)
            row['assets'][variant] = res + name
            row['asset_sha256'][variant] = SHA(target / name)
        dependencies = {}
        for name, digest in row.get('art_dependency_sha256', {}).items():
            copyfile(checked(pipeline.OUTPUT / name, digest), target / name)
            dependencies[res + name] = digest
            if row.get('source_alpha_texture') == name:
                row['source_alpha_texture'] = 'champions/' + name
        row['art_dependency_sha256'] = dependencies
        if body == 173:
            renderer = 'Presentation/MephitisVisual.gd'
            support = 'Presentation/MephitisGroundSupport.gd'
            row.update(presentation_script='res://' + renderer,
                       presentation_script_sha256=SHA(ROOT / 'Viewer' / renderer))
            dependencies['res://' + support] = SHA(ROOT / 'Viewer' / support)
        package.append(row)
        print(f'{kind} {body}: {joints} joints and {clips} linked motions', flush=True)
    pending = target / 'preparation.pending'
    pending.write_text(json.dumps({'models': package, 'input_manifest_sha256': SHA(MANIFEST)},
                                  indent=2) + '\n', encoding='utf-8')
    pending.replace(target / 'preparation.json')


if __name__ == '__main__':
    main()
