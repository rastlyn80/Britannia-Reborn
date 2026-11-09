"""Verify the exact Classic frames and prepare the five fitted creature packages."""

import json
from pathlib import Path
import runpy


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'scripts'
VIEWER = ROOT / 'Viewer'
FAMILY = 'centaur_through_essence_actions'
PACKAGE = runpy.run_path(str(SCRIPTS / 'creature-action-package.py'))
sha = PACKAGE['sha']
CLASSES = {101: ['Centaur'], 146: ['Harrower'], 255: ['YomotsuElder'],
           262: ['TormentedMinotaur'], 273: ['FetidEssence', 'MantraEffervescence']}
SLOTS = {
    101: {6: 'Attack2', 15: 'CentaurShoulderBrace', 16: 'CentaurShoulderBrace'},
    146: {15: 'ShadowlordRecoil', 16: 'ShadowlordRecoil', 18: 'ShadowlordCloakTurn'},
    255: {11: 'ElderStaffCheck', 15: 'ElderBrace', 16: 'ElderBrace', 18: 'ElderStaffCheck'},
    262: {18: 'TormentedWeaponCheck'},
    273: {15: 'EssenceCompactRecoil', 16: 'EssenceTallRecoil', 18: 'EssenceBillow'},
}
COMPARISONS = {101: (5,), 146: (11, 17), 255: (17,), 262: (17,), 273: (1, 17)}
RENDERERS = {
    146: 'ArchiveSourcePreservingGestureVisual.gd',
    262: 'ArchiveOccurrenceGestureVisual.gd',
    273: 'FetidEssenceVisual.gd',
}
BAKE_INPUTS = ('bake-centaur-through-essence-actions.gd', 'centaur-through-essence-action-pins.json',
               'bake-banshee-through-queens-actions.gd', 'bake-swamp-widow-juka-actions.gd',
               'bake-zombie-actions.gd', 'bake-troll-actions.gd', 'bake-skeleton-actions.gd')


def prepared(entries):
    pins = PACKAGE['checked_mul_sources']('centaur-through-essence-action-pins.json', {
        body: set(groups).union(COMPARISONS[body]) for body, groups in SLOTS.items()})
    inputs = PACKAGE['bake_input_hashes'](BAKE_INPUTS)
    rows = []
    for body, groups in SLOTS.items():
        base, = (row for row in entries if row['status'] == 'validated' and
                 [int(identity['body']) for identity in row['bodies']] == [body])
        stem = f'centaur-essence-{body}-actions'
        before, assets, scenes = PACKAGE['checked_scenes'](base, body, stem, inputs)
        references = {str(slot): pins[str(body)][str(slot)] for slot in groups}
        replacements = {}
        for slot, clip in groups.items():
            if clip == 'Attack2':
                continue
            if body == 273:
                description = f'EnergyRoot scale fitted to the five registered Classic directions for group {slot}'
            else:
                description = f'Fitted native rig gesture from the registered Classic group {slot} silhouette'
            replacements.setdefault(clip, description)
        renderer = 'res://Presentation/' + RENDERERS.get(body, 'ArchiveGestureVisual.gd')
        row = dict(base, status='prepared', family=FAMILY, assets=assets,
                   authored_action_scene_sha256=scenes, classic_gesture_base_assets=before,
                   classic_motion_references=references, authored_action_reference=next(iter(references.values())),
                   classic_action_categories=base.get('classic_action_categories', {}) |
                   {str(slot): clip for slot, clip in groups.items()},
                   new_action_categories=base.get('new_action_categories', {}),
                   authored_replacements=base.get('authored_replacements', {}) | replacements,
                   native_extra_classic_actions=[slot for slot in groups if slot not in (6, 11)],
                   presentation_script=renderer, presentation_script_sha256=sha(VIEWER / renderer[6:]),
                   archive_grounded_gestures=sorted(set(base.get('archive_grounded_gestures', [])) |
                                                    (set(replacements) if body != 273 else set())),
                   archive_align_gesture_slope=body != 146)
        if body == 255:
            row.pop('legacy_slot11_evidence', None)
        rows.append(row)
    return rows, CLASSES


def main():
    selector = runpy.run_path(str(SCRIPTS / 'prepare-creature-fixtures.py'))
    base = selector['gesture_baseline'](FAMILY, None, CLASSES, layered=True)
    rows, _ = prepared(base)
    work = ROOT / 'work/creatures' / FAMILY
    work.mkdir(parents=True, exist_ok=True)
    (work / 'prepared-client.json').write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
