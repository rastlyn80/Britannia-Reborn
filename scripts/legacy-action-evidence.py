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


def row_identity(row):
    return row['kind'], tuple(sorted(int(identity['body']) for identity in row['bodies']))


def expected_rows_with_legacy_aliases(rows, active):
    active_by_identity = {row_identity(row): row for row in active}
    batches = dict((('monstrousinterredgrizzle', 'grizzle_antler'),
                        ('wild_guar', 'gaman_gestures'),
                        ('walking_dead_mummy', 'lowland_creature_gestures'),
                        ('elementals_ice_elemental', 'cyclops_titan_ice_actions'),
                        ('elementals_blood_elemental', 'hopper_fan_blood_actions'),
                        ('gazer_larva', 'gargoyle_kitsune_larva_actions'),
                        ('walking_dead_rotting_corpse', 'avenger_rotting_actions'),
                        ('genies_efreet', 'efreet_actions'),
                        ('orcs_orc_captain', 'orc_bog_actions'),
                        ('changling', 'ranked_classic_actions'),
                        ('swamp_dragon', 'swamp_widow_juka_actions'),
                        ('swamp_dragon_armor', 'swamp_widow_juka_actions'),
                        ('arachnids_spider_black_widow', 'swamp_widow_juka_actions'),
                        ('juka_mage', 'swamp_widow_juka_actions'),
                        ('orcs_orc_bomber', 'bomber_ogre_rune_dopple_actions'),
                        ('rune_beetle', 'bomber_ogre_rune_dopple_actions'),
                        ('doppleganger', 'bomber_ogre_rune_dopple_actions'),
                        ('golem_iron', 'golem_raptor_juka_solen_actions'),
                        ('ant_lion', 'post_solen_actions'),
                        ('quagmire', 'quagmire_through_exodus_actions'),
                        ('arcane_demon', 'quagmire_through_exodus_actions'),
                        ('dryad', 'quagmire_through_exodus_actions'),
                        ('npc_adranath', 'quagmire_through_exodus_actions'),
                        ('flesh_golem', 'quagmire_through_exodus_actions'),
                        ('dragons_wyrm_ancient', 'quagmire_through_exodus_actions'),
                        ('clockwork_minion', 'quagmire_through_exodus_actions'),
                        ('clockwork_overseer', 'quagmire_through_exodus_actions'),
                        ('lady_of_the_snow', 'quagmire_through_exodus_actions'),
                        ('gouzen_ha', 'quagmire_through_exodus_actions'),
                        ('satyr', 'quagmire_through_exodus_actions'),
                        ('ridgeback_ridgeback', 'ridgeback_through_dragons_actions'),
                        ('ridgeback_savage', 'ridgeback_through_dragons_actions'),
                        ('raptalon', 'ridgeback_through_dragons_actions'),
                        ('bonedemon', 'ridgeback_through_dragons_actions'),
                        ('dragons_dragon_asian', 'ridgeback_through_dragons_actions'),
                        ('dragons_dragon_skeletal', 'ridgeback_through_dragons_actions'),
                        ('wailingbanshee', 'banshee_through_queens_actions'),
                        ('minotaurarmored', 'banshee_through_queens_actions'),
                        ('npc_blackthorn_cohort', 'banshee_through_queens_actions'),
                        ('ferret', 'banshee_through_queens_actions'),
                        ('juggernaut', 'banshee_through_queens_actions'),
                        ('gibberling', 'banshee_through_queens_actions'),
                        ('black_ant_queen', 'banshee_through_queens_actions'),
                        ('fire_ant_queen', 'banshee_through_queens_actions'),
                        ('yamandon', 'banshee_through_queens_actions'),
                        ('chaos_demon', 'frost_through_gargoyle_actions'),
                        ('ethereal_warriors_male', 'lattice_through_meer_actions'),
                        ('four_armed_demon', 'lattice_through_meer_actions'),
                        ('orcs_orc_brute', 'lattice_through_meer_actions'),
                        ('oni', 'lattice_through_meer_actions'),
                        ('meer_mage', 'lattice_through_meer_actions'),
                        ('npc_cpt_dasha', 'lattice_through_meer_actions'),
                        ('treefellow', 'lattice_through_meer_actions'),
                        ('cushidhe', 'lattice_through_meer_actions'),
                        ('gargoyles_gargoyle_guard', 'frost_through_gargoyle_actions'),
                        ('gargoyles_gargoyle_enforcer', 'frost_through_gargoyle_actions'),
                        ('fire_ant_warrior', 'golem_raptor_juka_solen_actions'),
                        ('black_ant_warrior', 'golem_raptor_juka_solen_actions'),
                        ('serpents_snake_giant_lava', 'ratman_lava_actions'),
                        ('rat_race_shaman', 'ratman_lava_actions')))
    expected = []
    for row in rows:
        identity = row_identity(row)
        overlay = active_by_identity.get(identity, {})
        original = expected_with_legacy_alias(row, overlay)
        kind = row['kind']
        batch = batches.get(kind)
        if batch and overlay.get('classic_gesture_native_sha256'):
            gate = runpy.run_path(str(Path(__file__).with_name('accept-classic-gestures.py')))
            index = {'entries': active}
            retained = original
            successor = overlay.get('classic_gesture_batch')
            if (batch, successor) in {('grizzle_antler', 'ranked_classic_actions'),
                                       ('gaman_gestures', 'post_solen_actions'),
                                       ('lattice_through_meer_actions', 'meer_forward_falls'),
                                       ('frost_through_gargoyle_actions', 'gargoyle_flight_minotaur_actions')}:
                earlier, previous = gate['checked'](index, True, batch, compare_registry=False)
                if [row for row in earlier if row_identity(row) == identity] != [original]:
                    raise ValueError(f'{kind} earlier action overlay no longer matches the verified base package')
                retained, = (row for row in previous if row_identity(row) == identity)
                batch = successor
            base, overlays = gate['checked'](index, True, batch)
            if ([row for row in base if row_identity(row) == identity] != [retained]
                    or [row for row in overlays if row_identity(row) == identity] != [overlay]):
                raise ValueError(f'{kind} action overlay no longer matches the verified base package')
            expected.append(overlay)
        else:
            expected.append(original)
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
