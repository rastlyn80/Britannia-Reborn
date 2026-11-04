#!/usr/bin/env python3
"""Activate the exact native-tested classic gesture batch by body ID."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
INDEX = ROOT / 'Viewer/local-art/creatures/accepted-index.json'
BATCHES = {
    'classic_gestures': ((1, 3, 50), 'ClassicGestureLive.gd', ('test-classic-gesture-trials.gd',)),
    'troll_gestures': ((53, 54, 55), 'TrollGestureLive.gd',
                      ('test-troll-overhead-trial.gd', 'test-troll-weapon-trial.gd')),
    'blistering_pillage': ((130,), 'BlisteringPillageLive.gd', ('test-gargoyle-pillage-trial.gd',)),
    'parrot_flight': ((831,), 'PreparedCreatureActionLive.gd', ('test-parrot-flight-trial.gd',)),
    'troglodyte_reach': ((267,), 'PreparedCreatureActionLive.gd', ('test-troglodyte-reach-trial.gd',)),
    'ready_stances': ((730, 734), 'PreparedCreatureActionLive.gd', ('test-creature-ready-stance.gd',)),
    'giant_serpent_pillage': ((21,), 'PreparedCreatureActionLive.gd', ('test-giant-serpent-pillage.gd',)),
    'skeleton_axe': ((56,), 'PreparedCreatureActionLive.gd', ('test-skeleton-axe-trial.gd',)),
    'ratman_hunch': ((42,), 'PreparedCreatureActionLive.gd', ('test-classic-gesture-trials.gd',)),
    'spider_mongbat': ((28, 39), 'PreparedCreatureActionLive.gd', ('test-spider-mongbat-gestures.gd',)),
    'reaper_harpy': ((30, 47), 'PreparedCreatureActionLive.gd', ('test-reaper-harpy-gestures.gd',)),
    'earth_elemental_aos': ((14,), 'PreparedCreatureActionLive.gd', ('test-earth-elemental-aos.gd',)),
    'wraith_sway': ((26,), 'PreparedCreatureActionLive.gd', ('test-wraith-gesture.gd',)),
    'gargoyle_classic': ((4,), 'PreparedCreatureActionLive.gd', ('test-gargoyle-classic.gd',)),
    'scorpion_imp': ((48, 74), 'PreparedCreatureActionLive.gd', ('test-scorpion-imp-gestures.gd',)),
    'ophidian_bardiche': ((86,), 'PreparedCreatureActionLive.gd', ('test-ophidian-bardiche.gd',)),
    'dragon_daemon': ((9, 10, 12, 38, 40, 43, 59, 60, 61), 'PreparedCreatureActionLive.gd',
                      ('test-dragon-daemon-gestures.gd',)),
    'terathan_classic': ((70, 71, 72), 'PreparedCreatureActionLive.gd', ('test-terathan-gestures.gd',)),
    'ophidian_staff': ((85, 87), 'PreparedCreatureActionLive.gd', ('test-ophidian-staff-gestures.gd',)),
    'bone_cyclops': ((57, 75), 'PreparedCreatureActionLive.gd', ('test-bone-knight-cyclops.gd',)),
    'fidget_aliases_toad': ((67, 80, 149), 'PreparedCreatureActionLive.gd', ('test-fidget-aliases-toad.gd',)),
    'exact_creature_fidgets': ((146, 157, 173, 777), 'ExactCreatureFidgetLive.gd', ()),
    'skeletal_mage_staff': ((148,), 'PreparedCreatureActionLive.gd', ('test-skeletal-mage-staff.gd',)),
    'grizzle_antler': ((259,), 'PreparedCreatureActionLive.gd', ('test-grizzle-antler.gd',)),
    'vampire_bat_actions': ((317,), 'PreparedCreatureActionLive.gd', ('test-vampire-bat-actions.gd',)),
    'hopper_horde_actions': ((302, 776), 'PreparedCreatureActionLive.gd', ('test-hopper-horde-actions.gd',)),
    'late_classic_actions': ((172, 303, 311), 'PreparedCreatureActionLive.gd', ('test-late-classic-actions.gd',)),
    'orc_fidgets': ((17,), 'PreparedCreatureActionLive.gd', ('test-humanoid-fidgets.gd',)),
    'kraken_fidgets': ((77,), 'PreparedCreatureActionLive.gd', ('test-kraken-fidgets.gd',)),
    'ettin_fidgets': ((18,), 'PreparedCreatureActionLive.gd', ('test-humanoid-fidgets.gd',)),
    'mongbat_fidgets': ((39,), 'PreparedCreatureActionLive.gd', ('test-mongbat-fidgets.gd',)),
    'sea_serpent_actions': ((150,), 'PreparedCreatureActionLive.gd', ('test-sea-serpent-actions.gd',)),
    'deer_fidgets': ((234, 237), 'PreparedClassicActionsLive.gd', ('test-field-fidgets.gd',)),
    'orc_ettin_reactions': ((17, 18), 'PreparedClassicActionsLive.gd', ('test-orc-ettin-reactions.gd',)),
    'occurrence_deaths': ((17, 18), 'OccurrenceDeathsLive.gd', ('test-occurrence-deaths.gd',)),
    'kraken_reactions': ((77,), 'PreparedClassicActionsLive.gd', ('test-kraken-reactions.gd',)),
    'field_deaths': ((237,), 'FieldDeathsLive.gd', ('test-field-deaths.gd',)),
    'lizard_actions': ((35, 36), 'LizardActionsLive.gd',
                       ('test-lizard-actions.gd', 'test-lizard-collapses.gd', 'test-lizardman-weapon-corpses.gd')),
    'quadruped_actions': ((225, 207, 223), 'QuadrupedActionsLive.gd',
                          ('test-quadruped-actions.gd', 'test-quadruped-corpse.gd')),
    'hart_deaths': ((234,), 'QuadrupedActionsLive.gd', ('test-quadruped-actions.gd', 'test-quadruped-corpse.gd')),
    'dog_bear_actions': ((217, 211), 'QuadrupedActionsLive.gd',
                         ('test-quadruped-actions.gd', 'test-quadruped-corpse.gd')),
    'cat_actions': ((201,), 'CatActionsLive.gd', ()),
    'troll_actions': ((53, 54, 55), 'TrollActionsLive.gd',
                      ('test-troll-actions.gd', 'test-lizard-collapses.gd')),
    'field_fauna': ((42, 167, 214, 63), 'FieldFaunaLive.gd',
                    ('test-quadruped-actions.gd', 'test-quadruped-corpse.gd')),
    'spider_mongbat_actions': ((28, 39), 'SpiderMongbatActionsLive.gd',
                              ('test-spider-mongbat-actions.gd', 'test-spider-mongbat-landings.gd')),
    'grazers_grizzly_actions': ((25, 27, 212, 290, 209), 'QuadrupedActionsLive.gd',
                               ('test-grazers-grizzly-actions.gd', 'test-grazers-grizzly-landings.gd')),
    'pig_reaper_harpy_actions': ((203, 47, 30), 'PigReaperHarpyActionsLive.gd',
                                ('test-pig-reaper-harpy-actions.gd', 'test-pig-reaper-harpy-landings.gd')),
    'rabbit_distinct_actions': ((205,), 'QuadrupedActionsLive.gd', ()),
    'serpent_ogre_actions': ((21, 1), 'FieldFaunaLive.gd',
                             ('test-serpent-ogre-actions.gd', 'test-serpent-ogre-landings.gd')),
    'zombie_corpser_gargoyle_actions': ((3, 8, 4), 'FieldFaunaLive.gd',
                                       ('test-zombie-corpser-gargoyle-actions.gd',
                                        'test-zombie-corpser-gargoyle-landings.gd')),
    'earth_gazer_imp_actions': ((14, 22, 74), 'FieldFaunaLive.gd',
                               ('test-earth-gazer-imp-actions.gd', 'test-earth-gazer-landings.gd')),
    'wisp_distinct_actions': ((58,), 'PreparedClassicActionsLive.gd', ()),
    'air_distinct_actions': ((13,), 'PreparedClassicActionsLive.gd', ()),
    'fire_distinct_actions': ((15,), 'PreparedClassicActionsLive.gd', ()),
    'alligator_lich_actions': ((202, 24), 'FieldFaunaLive.gd',
                              ('test-alligator-lich-actions.gd', 'test-alligator-lich-landings.gd')),
    'gaman_gestures': ((248,), 'PreparedClassicActionsLive.gd', ('test-gaman-gestures.gd',)),
    'chicken_distinct_actions': ((208,), 'FieldFaunaLive.gd', ()),
    'deathwatch_gestures': ((242,), 'PreparedClassicActionsLive.gd', ('test-deathwatch-terrain.gd',)),
    'daemon_wyvern_polar_actions': ((9, 62, 213), 'DaemonActionsLive.gd', ('test-daemon-distinct-actions.gd',
                                                             'test-daemon-distinct-landings.gd')),
    'wraith_drake_walrus_actions': ((26, 60, 61, 221), 'WraithDrakeWalrusLive.gd',
                                   ('test-wraith-drake-walrus-actions.gd', 'test-wraith-drake-walrus-landings.gd')),
    'scorpion_headless_actions': ((48, 31), 'FieldFaunaLive.gd',
                                 ('test-scorpion-headless-actions.gd', 'test-scorpion-headless-landings.gd')),
    'skeleton_actions': ((50, 56), 'PreparedClassicActionsLive.gd', ('test-skeleton-actions.gd',)),
}
PREDECESSORS = {
    'mongbat_fidgets': ('spider_mongbat',),
    'orc_ettin_reactions': ('orc_fidgets', 'ettin_fidgets'),
    'occurrence_deaths': ('orc_ettin_reactions',),
    'kraken_reactions': ('kraken_fidgets',),
    'field_deaths': ('deer_fidgets',),
    'lizard_actions': (),
    'quadruped_actions': (),
    'hart_deaths': ('deer_fidgets',),
    'dog_bear_actions': (),
    'troll_actions': ('troll_gestures',),
    'field_fauna': ('ratman_hunch',),
    'spider_mongbat_actions': ('mongbat_fidgets', 'spider_mongbat'),
    'grazers_grizzly_actions': (),
    'pig_reaper_harpy_actions': ('reaper_harpy',),
    'serpent_ogre_actions': ('giant_serpent_pillage',),
    'zombie_corpser_gargoyle_actions': ('gargoyle_classic',),
    'earth_gazer_imp_actions': ('earth_elemental_aos', 'scorpion_imp'),
    'scorpion_headless_actions': ('scorpion_imp',),
    'alligator_lich_actions': (),
    'gaman_gestures': (),
    'deathwatch_gestures': (),
    'daemon_wyvern_polar_actions': ('dragon_daemon',),
    'wraith_drake_walrus_actions': ('wraith_sway', 'dragon_daemon'),
    'skeleton_actions': ('skeleton_axe',),
}


def follows(batch, successor):
    return any(prior == batch or follows(batch, prior) for prior in PREDECESSORS.get(successor, ()))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def compose(base, prepared, native_sha):
    if prepared['family'] == 'exact_creature_fidgets':
        return dict(base, classic_action_categories=prepared['classic_action_categories'],
                    legacy_slot11_evidence=prepared['legacy_slot11_evidence'])
    if prepared['family'] == 'gaman_gestures':
        return dict(base, classic_action_categories=prepared['classic_action_categories'],
                    classic_motion_references=prepared['classic_motion_references'],
                    classic_gesture_batch=prepared['family'], classic_gesture_native_sha256=native_sha)
    assets = base.get('assets', {
        name: f"res://local-art/creatures/{base['kind']}-{name}.gltf"
        for name in prepared['assets']
    })
    row = dict(prepared, status='validated', family=base['family'],
               classic_gesture_base_assets=assets, classic_gesture_native_sha256=native_sha,
               asset_sha256=prepared['authored_action_scene_sha256'], import_sha256={})
    if prepared['family'] == 'lizard_actions':
        for field in ('assets', 'asset_sha256', 'authored_action_scene_sha256'):
            row[field] = {'modern': row[field]['modern']}
    if prepared['family'] in PREDECESSORS:
        row['classic_gesture_batch'] = prepared['family']
    if prepared['family'] in ('orc_fidgets', 'ettin_fidgets'):
        row['kind'] = f"{base['kind']}_fidgets"
    elif prepared['family'] == 'sea_serpent_actions':
        row['kind'] = f"{base['kind']}_classic"
    elif len(base['bodies']) > 1:
        row['kind'] = f"{base['kind']}_slot11_{prepared['bodies'][0]['body']}"
    for key in ('validation_sha256', 'gpu_sha256', 'gpu_runtime_sha256'):
        row.pop(key, None)
    if prepared['family'] == 'ready_stances' and 'uop_redirect_targets' in base:
        row['classic_action_categories'] = base['classic_action_categories'] | prepared['classic_action_categories']
        for key in ('uop_redirect_targets', 'uop_redirect_native_sha256'):
            row[key] = base[key]
    return row


def without_ready_stance(row):
    if 'classic_gesture_native_sha256' not in row or len(row['bodies']) != 1:
        return row
    body = int(row['bodies'][0]['body'])
    if body not in BATCHES['ready_stances'][0]:
        return row
    sealed = ROOT / 'work/creatures/ready_stances/accepted-native'
    base, = (item for item in read(sealed / 'base-rows.json') if item['bodies'][0]['body'] == body)
    candidates = sealed / 'candidates.json'
    receipt = read(sealed / 'native-runtime.json')
    digest = sha(sealed / 'live.json')
    sources = [candidate['presentation'] for candidate in read(candidates) if candidate['body'] == body]
    if (receipt['candidate_sha256'] != sha(candidates) or receipt['report_sha256'] != digest
            or not sources or any(source != sources[0] for source in sources)
            or compose(base, sources[0], digest) != row):
        raise ValueError(f'Active ready stance overlay changed for body {body}')
    return base


def checked(index, active, batch, *, compare_registry=True):
    body_ids, wrapper, _ = BATCHES[batch]
    bodies = set(body_ids)
    work = ROOT / 'work/creatures' / batch
    sealed = work / 'accepted-native'
    live = ROOT / 'outputs/creatures' / batch / 'live.json'
    if active:
        baseline = read(sealed / 'base-rows.json')
    else:
        baseline = [row for row in index['entries'] if row['status'] == 'validated'
                    and any(identity['body'] in bodies for identity in row['bodies'])]
    owners = {int(identity['body']): row for row in baseline for identity in row['bodies']}
    retained_body = {'serpent_ogre_actions': 1, 'zombie_corpser_gargoyle_actions': 3}.get(batch)
    if retained_body is not None:
        # The earlier multi-body batch also contains unrelated skeleton layers.
        # Compare only the retained body after rechecking the sealed native evidence.
        _, previous = checked(index, True, 'classic_gestures', compare_registry=False)
        retained, = (row for row in previous if row['bodies'][0]['body'] == retained_body)
        if owners.get(retained_body) != retained:
            raise ValueError(f'Body {retained_body} must retain its sealed Classic gesture base')
    if batch == 'lizard_actions':
        armed = runpy.run_path(str(ROOT / 'scripts/accept-armed-lizardman.py'))['checked_rows']
        prior = [row for row in index['entries'] if row.get('classic_gesture_batch') != batch]
        armed(dict(index, entries=prior + baseline if active else prior), True)
    if predecessors := PREDECESSORS.get(batch):
        prior_entries = []
        for row in index['entries']:
            successor = row.get('classic_gesture_batch')
            if successor == batch or (active and follows(batch, successor)):
                siblings = [identity for identity in row['bodies'] if identity['body'] not in bodies]
                if siblings:
                    prior_entries.append(dict(row, bodies=siblings))
            else:
                prior_entries.append(row)
        if active:
            prior_entries.extend(baseline)
        for predecessor in predecessors:
            if predecessor in ('scorpion_imp', 'dragon_daemon'):
                # Independent successors seal their own retained rows. Replaying a
                # sibling here would send it back through the same predecessor.
                _, previous = checked(index, True, predecessor, compare_registry=False)
                retained = [row for row in previous if row['bodies'][0]['body'] in bodies]
                if not retained or any(owners[row['bodies'][0]['body']] != row for row in retained):
                    raise ValueError(f'{batch} must retain its sealed {predecessor} rows')
                continue
            checked(dict(index, entries=prior_entries), True, predecessor)
    prepare = runpy.run_path(str(ROOT / 'scripts/prepare-creature-fixtures.py'))['prepared_entries']
    prepared, classes = prepare(batch, baseline)

    report_path = sealed / 'live.json' if active else live
    folder = sealed if active else work
    report = read(report_path)
    receipt = read(folder / 'native-runtime.json')
    candidates = folder / 'candidates.json'
    native_sha = sha(report_path)
    if (receipt['report_sha256'] != native_sha or receipt['candidate_sha256'] != sha(candidates)
            or report['candidate_sha256'] != sha(candidates)
            or report['test_sha256'] != sha(ROOT / 'Viewer/Network/CreatureLive.gd')
            or report['prepared_wrapper_sha256'] != sha(ROOT / 'Viewer/Network' / wrapper)
            or report['fixture_sha256'] != sha(ROOT / 'Server/HorseIntegrationFixtures/CreatureFixtures.cs')
            or report['failures'] or not report['prepared_trial']):
        raise ValueError('Classic gesture native evidence does not match this batch')
    if wrapper in ('PreparedClassicActionsLive.gd', 'OccurrenceDeathsLive.gd', 'FieldDeathsLive.gd',
                   'LizardActionsLive.gd', 'QuadrupedActionsLive.gd', 'CatActionsLive.gd', 'TrollActionsLive.gd',
                   'FieldFaunaLive.gd', 'SpiderMongbatActionsLive.gd', 'PigReaperHarpyActionsLive.gd',
                   'DaemonActionsLive.gd', 'WraithDrakeWalrusLive.gd') and (
            report['prepared_base_sha256'] != sha(ROOT / 'Viewer/Network/PreparedCreatureActionLive.gd')):
        raise ValueError('Supplementary action trial used a different prepared fixture loader')
    if batch == 'occurrence_deaths' and (
            report['collapse_sha256'] != sha(ROOT / 'Viewer/Presentation/SourceClassicCollapseVisual.gd')
            or report['supplemental_sha256'] != sha(ROOT / 'Viewer/Network/PreparedClassicActionsLive.gd')):
        raise ValueError('The explicit collapse renderer or supplementary packet test changed')
    if batch == 'field_deaths' and (
            report['field_collapse_sha256'] != sha(ROOT / 'Viewer/Presentation/FieldClassicCollapseVisual.gd')
            or report['explicit_collapse_test_sha256'] != sha(ROOT / 'Viewer/Network/OccurrenceDeathsLive.gd')
            or report['supplemental_sha256'] != sha(ROOT / 'Viewer/Network/PreparedClassicActionsLive.gd')):
        raise ValueError('The field collapse renderer or explicit packet test changed')
    if batch in ('lizard_actions', 'quadruped_actions', 'hart_deaths', 'dog_bear_actions', 'cat_actions',
                 'troll_actions', 'field_fauna', 'grazers_grizzly_actions', 'rabbit_distinct_actions',
                 'serpent_ogre_actions', 'zombie_corpser_gargoyle_actions', 'earth_gazer_imp_actions',
                 'scorpion_headless_actions', 'alligator_lich_actions'):
        visual, base_key, base_visual = (
            ('SourceLizardActionsVisual', 'armed_renderer_sha256', 'SourceArmedLizardmanVisual')
            if batch in ('lizard_actions', 'troll_actions') else
            ('SourceQuadrupedCollapseVisual', 'field_renderer_sha256', 'FieldClassicCollapseVisual')
        )
        paths = {
            'renderer_sha256': f'Presentation/{visual}.gd',
            base_key: f'Presentation/{base_visual}.gd',
            'supplemental_sha256': 'Network/PreparedClassicActionsLive.gd',
        }
        if batch == 'cat_actions':
            paths['explicit_collapse_test_sha256'] = 'Network/OccurrenceDeathsLive.gd'
        if any(report[key] != sha(ROOT / 'Viewer' / path) for key, path in paths.items()):
            raise ValueError('The action renderer or explicit packet test changed')
    if batch in ('spider_mongbat_actions', 'pig_reaper_harpy_actions'):
        renderers = ('GiantSpiderActionsVisual', 'MongbatActionsVisual', 'SourceQuadrupedCollapseVisual',
                     'FieldClassicCollapseVisual', 'SourceGroundedGestureVisual', 'SourceGroundLookup')
        if batch == 'pig_reaper_harpy_actions':
            renderers += ('HarpyActionsVisual',)
        expected = {name: sha(ROOT / f'Viewer/Presentation/{name}.gd') for name in renderers}
        if (report['collapse_renderers'] != expected
                or report['supplemental_sha256'] != sha(ROOT / 'Viewer/Network/PreparedClassicActionsLive.gd')):
            raise ValueError('Airborne or grounded collapse evidence does not match its renderers')

    by_body = {row['bodies'][0]['body']: row for row in prepared}
    if batch == 'dragon_daemon':
        recipe = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))
        recipe['check_breath'](read((sealed if active else live.parent) / 'breath.json'), candidates, by_body)
    candidate_keys = set()
    for candidate in read(candidates):
        body = candidate['body']
        if candidate['presentation'] != by_body[body]:
            raise ValueError(f'Tested package changed for body {body}')
        candidate_keys.add((body, candidate['native_class']))
    expected = {(body, name) for body, names in classes.items() for name in names}
    if candidate_keys != expected:
        raise ValueError('The native constructor allow-list changed')
    witnesses = set()
    for witness in report['records']:
        body = int(witness['body'])
        package = by_body[body]
        source = package['authored_action_reference']
        slots = [int(slot) for slot in package.get('classic_motion_references', {})]
        if not slots:
            slots = [source['group'] if isinstance(source, dict) else 11]
            if 'authored_action_secondary_reference' in package:
                slots.append(package['authored_action_secondary_reference']['group'])
        refuses_death = batch == 'dragon_daemon' and body == 38 and witness['native_class'] == 'ServantOfSemidar'
        suppresses_corpse = (batch, witness['native_class']) in {
            ('air_distinct_actions', 'SummonedAirElemental'), ('fire_distinct_actions', 'SummonedFireElemental')}
        if (witness['kind'] != package['kind'] or witness['corpse_suppressed'] != suppresses_corpse
                or witness['native_death_refused'] != refuses_death):
            raise ValueError(f'Missing original body or expected native death behaviour for {body}')
        if batch == 'quadruped_actions' and witness['native_state'] != ('shorn' if body == 223 else 'constructor'):
            raise ValueError(f'Missing native coat or constructor state for body {body}')
        if batch == 'pig_reaper_harpy_actions' and body == 47 and witness['movement'] != 'Native AI refuses movement':
            raise ValueError('Reaper fixture did not verify the native rooted state')
        if batch == 'zombie_corpser_gargoyle_actions' and body == 8 and witness['movement'] != 'Native AI refuses movement':
            raise ValueError('Corpser fixture did not verify the native rooted state')
        if batch in ('troll_actions', 'serpent_ogre_actions') or (batch, body) in (
                ('skeleton_actions', 50), ('field_fauna', 42), ('spider_mongbat_actions', 39),
                ('pig_reaper_harpy_actions', 30), ('zombie_corpser_gargoyle_actions', 4),
                ('earth_gazer_imp_actions', 14), ('earth_gazer_imp_actions', 74), ('scorpion_headless_actions', 31),
                ('alligator_lich_actions', 24)):
            expected_new_clip = package['new_action_categories']['14']
            reach, = (action for action in witness['actions'] if action['requested'] == -5)
            if any(reach[client + '_clip'] != expected_new_clip or reach[client + '_packet']['protocol'] != 'new'
                   or (reach[client + '_packet']['type'], reach[client + '_packet']['subaction'],
                       reach[client + '_packet']['variation']) != (14, 0, 0) for client in ('owner', 'observer')):
                raise ValueError('Both clients must witness the original type-14 action')
        if batch == 'exact_creature_fidgets' and body == 146 and (
                witness.get('transformed_body') != 780 or not witness.get('true_form_corpse')):
            raise ValueError('Harrower evidence must include the transformation and true-form corpse')
        for slot in slots:
            clip = ('Fidget' if batch == 'exact_creature_fidgets' and slot == 17
                    else package['classic_action_categories'][str(slot)])
            actions = [row for row in witness['actions'] if row['requested'] == slot]
            if len(actions) != 1 or any(actions[0][key] != clip for key in ('owner_clip', 'observer_clip')):
                raise ValueError(f'Missing Classic gesture evidence for body {body}, slot {slot}')
            if (batch in ('lizard_actions', 'quadruped_actions', 'hart_deaths', 'dog_bear_actions', 'cat_actions',
                          'skeleton_actions', 'troll_actions', 'field_fauna', 'spider_mongbat_actions',
                          'grazers_grizzly_actions', 'pig_reaper_harpy_actions', 'rabbit_distinct_actions',
                          'serpent_ogre_actions', 'zombie_corpser_gargoyle_actions', 'earth_gazer_imp_actions',
                          'wisp_distinct_actions', 'air_distinct_actions', 'scorpion_headless_actions',
                          'alligator_lich_actions', 'fire_distinct_actions', 'gaman_gestures',
                          'chicken_distinct_actions', 'deathwatch_gestures', 'daemon_wyvern_polar_actions',
                          'wraith_drake_walrus_actions') or
                    slot in package.get('native_extra_classic_actions', [])) and any(
                    actions[0][key]['protocol'] != 'classic' or actions[0][key]['action'] != slot
                    for key in ('owner_packet', 'observer_packet')):
                raise ValueError(f'Missing exact supplementary packet for body {body}, slot {slot}')
        if isinstance(source, dict) and 'new_type' in source:
            matches = [row for row in witness['actions'] if row['requested'] == -5]
            if (len(matches) != 1 or any(matches[0][key] != clip for key in ('owner_clip', 'observer_clip'))
                    or any(matches[0][side]['type'] != source['new_type']
                           for side in ('owner_packet', 'observer_packet'))):
                raise ValueError(f'Missing new-protocol ready stance evidence for {body}')
        witnesses.add(((body, witness['native_class']), witness['female']))
    if len(report['records']) != len(expected) * 2 or witnesses != {
            (pair, female) for pair in expected for female in (False, True)}:
        raise ValueError('Both clients must witness every native constructor')

    rows = [compose(owners[row['bodies'][0]['body']], row, native_sha) for row in prepared
            if batch != 'field_deaths' or row['bodies'][0]['body'] in bodies]
    if active and compare_registry:
        redirect = runpy.run_path(str(ROOT / 'scripts/prepare-creature-uop-redirects.py'))['without_active_redirect']
        targets = {row['bodies'][0]['body']: row for row in rows}
        siblings = {body: row for body, row in owners.items() if body not in bodies}
        for body, expected_row in (targets | siblings).items():
            matches = [row for row in index['entries'] if row['status'] == 'validated'
                       and any(identity['body'] == body for identity in row['bodies'])]
            if body in siblings:
                expected_row = dict(expected_row, bodies=[identity for identity in expected_row['bodies']
                                                         if identity['body'] not in bodies])
                if (batch == 'skeleton_axe' and body == 57 and len(matches) == 1
                        and matches[0].get('classic_gesture_native_sha256')):
                    bone_base, _ = checked(index, True, 'bone_cyclops')
                    if expected_row not in bone_base:
                        raise ValueError('Bone Knight overlay must retain the independently checked sibling base')
                    continue
            compared = matches if batch == 'ready_stances' else [redirect(row) for row in matches]
            comparison_index = index
            while len(compared) == 1:
                successor = compared[0].get('classic_gesture_batch')
                if not follows(batch, successor):
                    break
                earlier, _ = checked(comparison_index, True, successor)
                comparison_index = dict(comparison_index, entries=[
                    row for row in comparison_index['entries'] if row.get('classic_gesture_batch') != successor
                ] + earlier)
                compared = [row for row in earlier if any(identity['body'] == body for identity in row['bodies'])]
            if compared != [expected_row]:
                raise ValueError(f'Active body {body} differs from its checked package')
    return baseline, rows


def test_active(batch):
    godot = next((ROOT / '.tools/godot').glob('*console.exe'))
    profile = str(ROOT / '.godot-user')
    env = dict(os.environ, APPDATA=profile, LOCALAPPDATA=profile)
    trial_args = {'blistering_pillage': ['--blistering'], 'ratman_hunch': ['--ratman'],
                  'ettin_fidgets': ['--ettin'], 'hart_deaths': ['--hart'],
                  'dog_bear_actions': ['--dog-bear'], 'troll_actions': ['--troll'],
                  'field_fauna': ['--field-fauna']}.get(batch, [])
    for script in BATCHES[batch][2]:
        run_client_check(godot, env, f'res://../scripts/{script}', ['--active', *trial_args])
    if batch == 'zombie_corpser_gargoyle_actions':
        run_client_check(godot, env, 'res://Presentation/CorpserEmergenceTests.gd', ['--active'])
    package = {'parrot_flight': 'late_donors', 'troglodyte_reach': 'late_source',
               'late_classic_actions': 'aos_armed'}.get(batch)
    if package:
        run_client_check(godot, env, 'res://Presentation/LateCreatureRouteTests.gd', [f'--family={package}'])
    if batch == 'vampire_bat_actions':
        run_client_check(godot, env, 'res://Presentation/VampireBatRouteTests.gd', [])
    if batch == 'hopper_horde_actions':
        for family in ('occurrence_next', 'horde_rune'):
            run_client_check(godot, env, 'res://Presentation/OccurrenceCreatureRouteTests.gd', [f'--family={family}'])
    if batch == 'late_classic_actions':
        for test in ('ChampionCreatureRouteTests', 'DevourerLionHiryuRouteTests'):
            run_client_check(godot, env, f'res://Presentation/{test}.gd', [])
    if batch == 'ready_stances':
        for family in ('raptor', 'slith'):
            run_client_check(godot, env, 'res://Presentation/LateCreatureRouteTests.gd', [f'--family={family}'])
    if batch == 'exact_creature_fidgets':
        run_client_check(godot, env, 'res://Presentation/LegacyCreatureAliasTests.gd', ['--exact-fidgets', '--active'])
        for test in ('ChampionCreatureRouteTests', 'HarrowerMorphTests'):
            run_client_check(godot, env, f'res://Presentation/{test}.gd', [])


def run_client_check(godot, env, script, args):
    result = subprocess.run([str(godot), '--headless', '--path', str(ROOT / 'Viewer'), '--script',
                             script, '--', *args], cwd=ROOT, env=env, timeout=65,
                            capture_output=True, text=True, encoding='utf-8', errors='replace')
    output = result.stdout + result.stderr
    print(output.strip())
    if result.returncode or 'SCRIPT ERROR:' in output or 'Parse Error:' in output:
        raise RuntimeError(f'Creature action check failed: {script}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--activate', action='store_true')
    mode.add_argument('--check-active', action='store_true')
    parser.add_argument('--batch', choices=BATCHES, default='classic_gestures')
    args = parser.parse_args()
    batch = args.batch
    work = ROOT / 'work/creatures' / batch
    sealed = work / 'accepted-native'
    live = ROOT / 'outputs/creatures' / batch / 'live.json'
    previous = INDEX.read_bytes()
    index = read(INDEX)
    if batch in ('cat_actions', 'rabbit_distinct_actions', 'wisp_distinct_actions', 'air_distinct_actions',
                 'fire_distinct_actions', 'chicken_distinct_actions'):
        if args.activate or args.check_active:
            parser.error('Use the public animal preparation recipe for installation and verification')
        index = read(ROOT / 'Viewer/Art/Creatures/index.json')
    baseline, rows = checked(index, args.check_active, batch)
    if args.activate:
        if batch == 'ready_stances' and any('uop_redirect_native_sha256' not in row for row in baseline):
            raise ValueError('Activate the already verified UOP redirect layer before the ready stances')
        if any((row.get('classic_gesture_batch') == batch if batch in PREDECESSORS else
                row.get('classic_gesture_native_sha256') or
                batch == 'exact_creature_fidgets' and row.get('legacy_slot11_evidence')) and
               any(identity['body'] in BATCHES[batch][0] for identity in row['bodies'])
               for row in index['entries']):
            raise ValueError('The classic gesture batch is already active')
        bodies = {row['bodies'][0]['body'] for row in rows}
        retained = []
        for row in index['entries']:
            if row in baseline:
                siblings = [identity for identity in row['bodies'] if identity['body'] not in bodies]
                if siblings:
                    retained.append(dict(row, bodies=siblings))
            else:
                retained.append(row)
        index['entries'] = retained + rows
        if INDEX.read_bytes() != previous:
            raise RuntimeError('Registry changed during classic gesture activation')
        sealed.mkdir(exist_ok=True)
        for source in (live, work / 'native-runtime.json', work / 'candidates.json'):
            shutil.copyfile(source, sealed / source.name)
        if batch == 'dragon_daemon':
            shutil.copyfile(live.parent / 'breath.json', sealed / 'breath.json')
        (sealed / 'base-rows.json').write_text(json.dumps(baseline, indent=2) + '\n', encoding='utf-8')
        pending = INDEX.with_suffix('.classic-gestures.pending')
        updated = (json.dumps(index, indent=2) + '\n').encode()
        pending.write_bytes(updated)
        pending.replace(INDEX)
        try:
            checked(read(INDEX), True, batch)
            for predecessor in PREDECESSORS.get(batch, ()):
                test_active(predecessor)
            test_active(batch)
        except (Exception, KeyboardInterrupt):
            if INDEX.read_bytes() == updated:
                pending.write_bytes(previous)
                pending.replace(INDEX)
            raise
    elif args.check_active:
        test_active(batch)
    print(batch + ':', 'active and verified' if args.activate or args.check_active else 'verified for activation')


if __name__ == '__main__':
    main()
