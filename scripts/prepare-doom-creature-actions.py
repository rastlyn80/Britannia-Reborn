"""Prepare the fitted Doom creature motions on their retained source rigs."""

import json
from pathlib import Path
import runpy


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'scripts'
VIEWER = ROOT / 'Viewer'
FAMILY = 'doom_creature_actions'
PACKAGE = runpy.run_path(str(SCRIPTS / 'creature-action-package.py'))
sha = PACKAGE['sha']
FITS = {
    306: ('Impaler', 'ImpalerShortRecoil', 'ImpalerClawCheck'),
    311: ('ShadowKnight', 'ShadowKnightShortGuard', 'ShadowKnightSwordCheck'),
    312: ('AbysmalHorror', 'HorrorTentacleRecoil', 'HorrorTentacleSpread'),
    313: ('DarknightCreeper', 'CreeperRear', 'CreeperCurl'),
    314: ('Ravager', 'RavagerShortBrace', 'RavagerClubRaise'),
    315: ('FleshRenderer', 'FleshRendererFrontRecoil', 'FleshRendererShellRock'),
    316: ('WandererOfTheVoid', 'WandererShortCurl', 'WandererBow'),
    318: ('DemonKnight', 'DemonKnightShortGuard', 'DemonKnightTailCheck'),
    319: ('MoundOfMaggots', 'MoundShortTuck', 'MoundHeadRise'),
}
CLASSES = {body: [name] for body, (name, _, _) in FITS.items()}
RENDERERS = {
    'res://Presentation/OccurrenceCreatureVisual.gd': 'res://Presentation/ArchiveOccurrenceGestureVisual.gd',
    'res://Presentation/SourcePreservingCreatureVisual.gd': 'res://Presentation/ArchiveSourcePreservingGestureVisual.gd',
}
BAKE_INPUTS = ('bake-doom-creature-actions.gd', 'doom-creature-action-pins.json',
               'bake-swamp-widow-juka-actions.gd', 'bake-zombie-actions.gd',
               'bake-troll-actions.gd', 'bake-skeleton-actions.gd')


def prepared(entries):
    comparison_groups = {4, 5, 6, 10, 11, 15, 16, 17, 18}
    pins = PACKAGE['checked_mul_sources']('doom-creature-action-pins.json', {
        body: {2, 3, 10, 11, 15, 16, 17, 18} if body == 306 else comparison_groups for body in FITS})
    inputs = PACKAGE['bake_input_hashes'](BAKE_INPUTS)
    rows = []
    for body, (_, recoil, gesture) in FITS.items():
        base, = (row for row in entries if row['status'] == 'validated' and
                 [int(identity['body']) for identity in row['bodies']] == [body])
        before, assets, scenes = PACKAGE['checked_scenes'](base, body, f'doom-creature-{body}-actions', inputs)
        groups = ({'6': 'Attack2'} if body != 306 else {}) | {'15': recoil, '16': recoil, '18': gesture}
        references = {slot: pins[str(body)][slot] for slot in groups}
        descriptions = {groups[str(slot)]: f'Fitted on the retained rig from the registered Classic group {slot}'
                        for slot in (15, 18)}
        renderer = RENDERERS[base['presentation_script']]
        rows.append(dict(base, status='prepared', family=FAMILY, assets=assets,
                         authored_action_scene_sha256=scenes, classic_gesture_base_assets=before,
                         classic_motion_references=references, authored_action_reference=references['15'],
                         classic_action_categories=base.get('classic_action_categories', {}) | groups,
                         new_action_categories=base.get('new_action_categories', {}),
                         authored_replacements=base.get('authored_replacements', {}) | descriptions,
                         native_extra_classic_actions=[15, 16, 18], presentation_script=renderer,
                         presentation_script_sha256=sha(VIEWER / renderer[6:]),
                         archive_grounded_gestures=sorted(descriptions), archive_align_gesture_slope=True))
    return rows, CLASSES


if __name__ == '__main__':
    selector = runpy.run_path(str(SCRIPTS / 'prepare-creature-fixtures.py'))
    base = selector['gesture_baseline'](FAMILY, None, CLASSES, layered=True)
    rows, _ = prepared(base)
    work = ROOT / 'work/creatures' / FAMILY
    work.mkdir(parents=True, exist_ok=True)
    (work / 'prepared-client.json').write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8')
