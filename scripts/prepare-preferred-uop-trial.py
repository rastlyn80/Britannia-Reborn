"""Prepare disposable native packet tests for the saved Gargoyle and Parrot scenes."""

from pathlib import Path
import runpy


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'scripts'
PACKAGE = runpy.run_path(str(SCRIPTS / 'prepare-preferred-uop-actions.py'))
WORK = PACKAGE['WORK'] / 'native'
FAMILY = PACKAGE['FAMILY']
replace = runpy.run_path(str(SCRIPTS / 'prepare-halberd-uop-trial.py'))['replace']


def main():
    helper = runpy.run_path(str(SCRIPTS / 'prepare-classic-gesture-bridge-trials.py'))
    prepare = helper['prepare']
    prepare.__globals__.update(WORK=WORK, FAMILY_PREFIX=FAMILY.removesuffix('01'))
    routes = {str(body): {kind: PACKAGE['CLIPS'][body][group] for kind, group in types.items()}
              for body, types in PACKAGE['ROUTES'].items()}
    classes = {str(body): name for body, name in PACKAGE['CLASSES'].items()}
    prepare(routes, classes, ('2', '8', '11', '14', '15'), 22)

    path = WORK / 'ClassicGestureBridgeLive.gd'
    text = path.read_text(encoding='utf-8')
    text = replace(text, 'const Dispatcher :=',
                   'const TrialRegistry := preload("res://Presentation/CreatureRegistry.gd")\nconst Dispatcher :=')
    text = replace(text, '\tassert(mapping.size() == candidates.size())',
                   '\tassert(mapping.size() == candidates.size() and candidates.size() == 2)\n'
                   '\tTrialRegistry.load_index()\n'
                   '\tfor candidate: Dictionary in candidates:\n'
                   '\t\tvar body := int(candidate.body)\n'
                   '\t\tvar presentation: Dictionary = candidate.presentation\n'
                   '\t\tassert(body in [753, 831] and presentation.status == "prepared")\n'
                   '\t\tassert(FileAccess.get_sha256(presentation.assets.modern) == presentation.asset_sha256.modern)\n'
                   '\t\tTrialRegistry.entries[body] = presentation')
    text = replace(text, '\t\tvar rule: Array = mapping[str(body)][kind]',
                   '\t\tvar expected: String = mapping[str(body)][kind]')
    text = replace(text, 'mode, int(rule[mode]), actors)', 'mode, expected, actors)')
    text = replace(text, 'mode: int, classic_group: int, actors:', 'mode: int, expected: String, actors:')
    text = replace(text, '\tvar expected := ""\n', '')
    start = text.index('\t\tif not check(actor.receive_native_action({"protocol": "classic"')
    end = text.index('\t\tif not check(Dispatcher.dispatch(actor, packet)', start)
    path.write_text(text[:start] + text[end:], encoding='utf-8')

    path = WORK / 'prepare-bridge-fixtures.py'
    text = path.read_text(encoding='utf-8')
    start = text.index('def prepared_entries(')
    end = text.index("\n\nselector['main']", start)
    text = text[:start] + f'''def prepared_entries(family):
    assert family == {FAMILY!r}
    recipe = runpy.run_path(str(root / 'scripts/prepare-preferred-uop-actions.py'))
    index = recipe['read'](root / 'Viewer/local-art/creatures/accepted-index.json')
    rows = index['entries']
    if any(row.get('preferred_uop_native_sha256') for row in rows):
        rows = recipe['read'](recipe['WORK'] / 'accepted-native/base.json')
    return recipe['prepared'](rows), {{body: [name] for body, name in recipe['CLASSES'].items()}}
''' + text[end:]
    path.write_text(text, encoding='utf-8')


if __name__ == '__main__':
    main()
