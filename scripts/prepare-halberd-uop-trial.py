"""Create an isolated packet trial for the exact Animated Weapon package."""

from pathlib import Path
import runpy


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'scripts'
ACCEPT = runpy.run_path(str(SCRIPTS / 'accept-halberd-uop-actions.py'))
WORK = ACCEPT['NATIVE']
FAMILY = ACCEPT['FAMILY']


def replace(text, before, after):
    if text.count(before) != 1:
        raise ValueError(f'The disposable packet fixture changed around {before!r}')
    return text.replace(before, after)


def main():
    helper = runpy.run_path(str(SCRIPTS / 'prepare-classic-gesture-bridge-trials.py'))
    prepare = helper['prepare']
    prepare.__globals__.update(WORK=WORK, FAMILY_PREFIX=FAMILY.removesuffix('01'))
    routes = ACCEPT['ROUTES']
    prepare({'692': routes}, {'692': 'AnimatedWeapon'}, routes.keys(), 22)

    path = WORK / 'ClassicGestureBridgeLive.gd'
    text = path.read_text(encoding='utf-8')
    text = replace(text, 'const Dispatcher :=',
                   'const TrialRegistry := preload("res://Presentation/CreatureRegistry.gd")\nconst Dispatcher :=')
    text = replace(text, '\tassert(mapping.size() == candidates.size())',
                   '\tassert(mapping.size() == candidates.size() and candidates.size() == 1)\n'
                   '\tTrialRegistry.load_index()\n'
                   '\tvar presentation: Dictionary = candidates[0].presentation\n'
                   '\tassert(int(candidates[0].body) == 692 and presentation.status == "prepared")\n'
                   '\tassert(FileAccess.get_sha256(presentation.assets.modern) == presentation.asset_sha256.modern)\n'
                   '\tTrialRegistry.entries[692] = presentation')
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
    gate = runpy.run_path(str(root / 'scripts/accept-halberd-uop-actions.py'))
    row = gate['body_row'](gate['read'](gate['INDEX']))
    base = gate['retained'](row)
    return [gate['prepared'](base)], {{692: ['AnimatedWeapon']}}
''' + text[end:]
    path.write_text(text, encoding='utf-8')


if __name__ == '__main__':
    main()
