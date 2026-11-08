"""Compose a reviewed local alias with a separately verified base package."""
import json
from pathlib import Path
import runpy

MANIFEST = Path(__file__).resolve().parents[1] / 'Viewer/Presentation/legacy-late-action-aliases.json'
# Exact publishers that produced the base receipts before action overlays.
# Their remaining evidence is still recomputed by the current publisher.
BASE_PUBLISHERS = {
    'accept-ant-lion.py': '3c507a72e2cc65a67b95e75d618475a298ed8a35a3520d3359efa48d518a033a',
    'accept-crystal-lattice.py': '5dc9ad35bec0177c782a8055c8c1722703db1e03f0a1aae1c6060451be3d29e7',
    'accept-solen-queens.py': '093842f336fdb1f439ae838490ca1882a973cc2aa59452913e37db1d4b2acc25',
    'accept-source-preserving.py': '6fc7d7ba23fbbfeadd806703bdf45be2e894aa1be3fa3df1eb0419596b12edcc',
    'accept-reviewed-creatures.py': '3401f74138a90fa1f36edb0552ee695f5cb75c08f1e0cc440f271fff39e1d85c',
}


def check_publisher(name, recorded, current):
    if recorded != current and recorded != BASE_PUBLISHERS[name]:
        raise ValueError(f'Unrecognized base receipt publisher for {name}')


def check_base_receipt(name, recorded, current):
    check_publisher(name, recorded['publisher_sha256'], current['publisher_sha256'])
    if recorded != dict(current, publisher_sha256=recorded['publisher_sha256']):
        raise ValueError(f'Base receipt evidence changed for {name}')


def expected_rows_with_legacy_aliases(rows, active):
    active_by_kind = {row['kind']: row for row in active}
    expected = [expected_with_legacy_alias(row, active_by_kind.get(row['kind'], {})) for row in rows]
    for kind, batch in (('monstrousinterredgrizzle', 'grizzle_antler'),
                        ('wild_guar', 'gaman_gestures'),
                        ('walking_dead_mummy', 'lowland_creature_gestures'),
                        ('elementals_ice_elemental', 'cyclops_titan_ice_actions'),
                        ('elementals_blood_elemental', 'hopper_fan_blood_actions'),
                        ('serpents_snake_giant_lava', 'ratman_lava_actions'),
                        ('rat_race_shaman', 'ratman_lava_actions')):
        overlay = active_by_kind.get(kind, {})
        if overlay.get('classic_gesture_native_sha256') and any(row['kind'] == kind for row in expected):
            gate = runpy.run_path(str(Path(__file__).with_name('accept-classic-gestures.py')))
            base, overlays = gate['checked']({'entries': active}, True, batch)
            original, = (row for row in expected if row['kind'] == kind)
            if ([row for row in base if row['kind'] == kind] != [original]
                    or [row for row in overlays if row['kind'] == kind] != [overlay]):
                raise ValueError(f'{kind} action overlay no longer matches the verified base package')
            expected = [overlay if row == original else row for row in expected]
    return expected


def expected_with_legacy_alias(base, active):
    if 'legacy_slot11_evidence' not in active:
        return base
    identity, = base['bodies']
    body = str(int(identity['body']))
    proof = json.loads(MANIFEST.read_text(encoding='utf-8'))[body]
    if (active['legacy_slot11_evidence'] != proof or proof['kind'] != base['kind']
            or proof['family'] != base['family']
            or base.get('classic_action_categories', {}).get('11', 'Fidget') != 'Fidget'):
        raise ValueError(f'Unreviewed legacy slot 11 alias for body {body}')
    return dict(base, legacy_slot11_evidence=proof,
                classic_action_categories=base.get('classic_action_categories', {}) | {'11': 'Fidget'})
