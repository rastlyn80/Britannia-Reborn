"""Register the validated local Fire Beetle through the shared Beetle gates."""
from pathlib import Path

import runpy
import sys

SCRIPTS = Path(__file__).resolve().parent
publisher = runpy.run_path(str(SCRIPTS / 'accept-giant-beetle.py'))
variant = publisher['preparer'].module('fire_beetle', 'prepare-fire-beetle.py')


def bound_riding_test():
    path = variant.ROOT / 'Viewer/Presentation/GiantBeetleRidingTests.gd'
    source = path.read_text(encoding='utf-8')
    for before, after in {
        'res://local-art/creatures/giant_beetle/preparation.json':
            'res://local-art/creatures/giant_beetle_fire/preparation.json',
        'giant-beetle/final/riding': 'giant-beetle/fire-final/riding',
        '791': '169',
        '"SourceBeetleVisual.gd",': '"SourceBeetleVisual.gd","SourceFireBeetleVisual.gd",',
    }.items():
        assert before in source
        source = source.replace(before, after)
    return source


if __name__ == '__main__':
    bound = variant.WORK / 'FireBeetleRidingTests.gd'
    if sys.argv[1:] == ['--write-riding-test']:
        variant.WORK.mkdir(parents=True, exist_ok=True)
        bound.write_text(bound_riding_test(), encoding='utf-8')
    else:
        assert bound.read_text(encoding='utf-8') == bound_riding_test()
        base, source = variant.recipe()
        variant.check(base, source)
        publisher['register'](variant, base, variant.KIND, 169, Path(__file__), ('SourceFireBeetleVisual.gd',))
