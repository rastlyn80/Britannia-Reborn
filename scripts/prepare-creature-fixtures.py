"""Private native-constructor/state allow-list from checked identities."""
import argparse,hashlib,json,re,runpy,subprocess,sys,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
# Reviewed native declarations, each verified by its real constructor.
EXPLICIT_CLASSES={764:['JukaWarrior'],765:['JukaMage'],124:['EvilMage'],125:['EvilMageLord'],126:['EvilMageLord'],92:['SilverSerpent'],158:['AcidElemental'],162:['PoisonElemental'],237:['Hind','EnragedHind'],234:['GreatHart','EnragedHart'],21:['GiantSerpent'],89:['IceSerpent'],52:['Snake','IceSnake','LavaSnake'],208:['Chicken'],205:['JackRabbit','Rabbit'],58:['Wisp','CrystalWisp'],13:['AirElemental','SummonedAirElemental','CrystalVortex'],15:['FireElemental','SummonedFireElemental'],153:['Ghoul','Bogle'],29:['Gorilla'],31:['HeadlessOne'],779:['Bogling'],24:['Lich'],78:['AncientLich','DarkGuardian'],79:['LichLord'],163:['SnowElemental'],80:['GiantToad'],81:['BullFrog'],51:['Slime','CorrosiveSlime','Jwilson'],775:['PlagueBeast','PlagueBeastLord'],781:['RedSolenWorker'],805:['BlackSolenWorker']}
PREPARED_FORMS={
    'mummies':('preparation.json','check-prepared-mummy.py','--runtime',{154:['Mummy','PestilentBandage']}),
    'solen_warriors':('preparation.json','check-solen-warrior-sources.py','--fidelity',{782:['RedSolenWarrior','RedSolenInfiltratorWarrior'],806:['BlackSolenWarrior','BlackSolenInfiltratorWarrior']}),
    'ice_elementals':('candidate.json','check-source-ice-elemental.py','--candidate',{161:['IceElemental']}),
}
QUEEN_FORM=('preparation.json','prepare-solen-queens.py','--check-prepared',
            {783:['RedSolenQueen','RedSolenInfiltratorQueen'],807:['BlackSolenQueen','BlackSolenInfiltratorQueen']})
RECENT_CLASSES={166:['GoldenElemental'],753:['EnslavedGargoyle'],301:['Treefellow','FeralTreefellow'],
                155:['RottingCorpse','UnfrozenMummy'],189:['OrcBrute'],165:['ShadowWisp','ShadowWispFamiliar'],
                154:['Mummy','PestilentBandage'],782:['RedSolenWarrior','RedSolenInfiltratorWarrior'],
                806:['BlackSolenWarrior','BlackSolenInfiltratorWarrior'],161:['IceElemental']}
SOURCE_COVERAGE_CLASSES = {
    'source_coverage_common': {248: ['Gaman'], 143: ['RatmanMage'], 182: ['OrcBomber'],
                               259: ['InterredGrizzle', 'Ilhenir']},
    'source_coverage_uncommon': {777: ['Doppleganger'], 264: ['Changeling'], 752: ['Golem'],
                                 94: ['FrostOoze'], 792: ['ChaosDaemon']},
    'source_coverage_rare': {785: ['Moloch'], 784: ['ArcaneDaemon', 'CrystalDaemon'],
                             755: ['GargoyleDestroyer'], 754: ['GargoyleEnforcer']},
    'source_coverage_loose_mounts': {794: ['SwampDragon'], 799: ['ScaledSwampDragon'],
                                     187: ['Ridgeback'], 188: ['SavageRidgeback']},
}

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def gesture_baseline(family, registry_entries, bodies, layered=False):
    if registry_entries is not None:
        return registry_entries
    path = ROOT / 'Viewer/local-art/creatures/accepted-index.json'
    rows = json.loads(path.read_text(encoding='utf-8'))['entries']
    if any((row.get('classic_gesture_batch') == family if layered else
            row.get('classic_gesture_native_sha256') or
            family == 'exact_creature_fidgets' and row.get('legacy_slot11_evidence'))
           and any(identity['body'] in bodies for identity in row['bodies']) for row in rows):
        baseline = ROOT / 'work/creatures' / family / 'accepted-native/base-rows.json'
        return json.loads(baseline.read_text(encoding='utf-8'))
    return rows


def prepared_recovered_action(family, registry_entries):
    ledger = json.loads((ROOT / 'outputs/creatures/actions.json').read_text(encoding='utf-8'))
    if family == 'parrot_flight':
        body, slot, package, stem, clip = 831, 19, 'late_donors', 'parrot-831-flight-trial', 'Fly'
        source, = (group for group in ledger['original_uop_frame_groups']
                   if (group['body'], group['group']) == (body, slot))
        assert source['archive'] == 'AnimationFrame4.uop' and source['frame_headers'] == 40
        assert source['payload_sha256'] == 'feea55575116337dba1cbaa3b4d6f705459b9084ac173c5dc8aeb18f51620c78'
        description = 'Authored wingbeat from the eight-frame preferred UOP direction'
    else:
        assert family == 'troglodyte_reach'
        body, slot, package, stem, clip = 267, 11, 'late_source', 'troglodyte-267-reach-trial', 'Pillage'
        group, = (row for row in ledger['original_mul_group_candidates']
                  if (row['body'], row['group']) == (body, slot))
        assert group['archive'] == 'anim5.mul' and group['graphic'] == 26
        assert group['layout'] == 'large' and not group['mobtype_prefers_uop']
        assert [direction['direction'] for direction in group['directions']] == list(range(5))
        assert all(direction['frames'] == 5 for direction in group['directions'])
        hashes = ''.join(direction['payload_sha256'] for direction in group['directions']).encode('ascii')
        digest = hashlib.sha256(hashes).hexdigest()
        assert digest == 'b8cea81705fc094ede2b3bbeca4e790f29b7bdf1366c7df0606a8f46d385c78e'
        source = {'body': body, 'group': slot, 'archive': group['archive'], 'graphic': group['graphic'],
                  'directional_payload_sha256': digest}
        description = 'Recovered Misc reach retimed to the five-frame Classic MUL sequence'
    base, = (row for row in gesture_baseline(family, registry_entries, {body})
             if row['status'] == 'validated' and [identity['body'] for identity in row['bodies']] == [body])
    originals, classes = prepared_entries(package)
    original, = (row for row in originals if row['bodies'][0]['body'] == body)
    if base != dict(original, status='validated'):
        raise ValueError(f'{family} requires the exact recovered base package')
    assets = {name: f'res://local-art/creatures/{stem}-{name}.scn' for name in base['assets']}
    row = dict(base, status='prepared', family=family, assets=assets,
               authored_action_reference=source,
               authored_action_scene_sha256={name: sha(ROOT / 'Viewer' / path.removeprefix('res://'))
                                             for name, path in assets.items()},
               classic_action_categories=base.get('classic_action_categories', {}) | {str(slot): clip},
               authored_replacements=base.get('authored_replacements', {}) | {clip: description})
    return [row], {body: classes[body]}


def prepared_entries(family, registry_entries=None):
    if family == 'cat_actions':
        return runpy.run_path(str(ROOT / 'scripts/prepare-cat-actions.py'))['prepared'](registry_entries)
    if family == 'skeleton_actions':
        rows = gesture_baseline(family, registry_entries, {50, 56}, layered=True)
        return runpy.run_path(str(ROOT / 'scripts/prepare-skeleton-actions.py'))['prepared'](rows)
    if family == 'hart_deaths':
        rows = gesture_baseline(family, registry_entries, {234}, layered=True)
        return runpy.run_path(str(ROOT / 'scripts/prepare-hart-deaths.py'))['prepared'](rows)
    if family == 'quadruped_actions':
        rows = gesture_baseline(family, registry_entries, {225, 207, 223}, layered=True)
        return runpy.run_path(str(ROOT / 'scripts/prepare-quadruped-actions.py'))['prepared'](rows)
    if family == 'lizard_actions':
        rows = gesture_baseline(family, registry_entries, {35, 36}, layered=True)
        return runpy.run_path(str(ROOT / 'scripts/prepare-lizard-actions.py'))['prepared'](rows)
    if family == 'field_deaths':
        rows = gesture_baseline(family, registry_entries, {237}, layered=True)
        return runpy.run_path(str(ROOT / 'scripts/prepare-field-deaths.py'))['prepared'](rows)
    if family in ('occurrence_deaths', 'kraken_reactions', 'dog_bear_actions', 'troll_actions', 'field_fauna',
                  'spider_mongbat_actions', 'grazers_grizzly_actions'):
        recipe = runpy.run_path(str(ROOT / ('scripts/prepare-' + family.replace('_', '-') + '.py')))
        rows = gesture_baseline(family, registry_entries, set(recipe['CLASSES']), layered=True)
        return recipe['prepared'](rows)
    if family == 'restless_soul_mounted':
        return runpy.run_path(str(ROOT / 'scripts/prepare-restless-soul-mounted.py'))['prepared']()
    if family == 'restless_soul_actions':
        return runpy.run_path(str(ROOT / 'scripts/prepare-restless-soul-actions.py'))['prepared']()
    if family == 'khaldun_actions':
        workflow = runpy.run_path(str(ROOT / 'scripts/prepare-khaldun-actions.py'))
        report = workflow['read'](workflow['OUTPUT'])
        assert workflow['stage']() == report, 'Khaldun scenes or Classic action inputs changed'
        return report['models'], {637: ['SpectralArmour'], 970: ['RestlessSoul']}
    if family == 'orc_ettin_reactions':
        recipe = runpy.run_path(str(ROOT / 'scripts/prepare-orc-ettin-reactions.py'))
        rows = gesture_baseline(family, registry_entries, set(recipe['CLASSES']), layered=True)
        return recipe['prepared'](rows)
    if family in ('deer_fidgets', 'rat_fidgets'):
        recipe = runpy.run_path(str(ROOT / 'scripts/prepare-field-fidgets.py'))
        if family == 'rat_fidgets':
            return recipe['prepared_rat']()
        rows = gesture_baseline(family, registry_entries, set(recipe['CLASSES']))
        return recipe['prepared_deer'](rows)
    if family == 'water_fidgets':
        return runpy.run_path(str(ROOT / 'scripts/prepare-water-elemental.py'))['prepared_fidgets']()
    if family == 'water_reactions':
        return runpy.run_path(str(ROOT / 'scripts/prepare-water-reactions.py'))['prepared']()
    if family == 'mongbat_fidgets':
        recipe = runpy.run_path(str(ROOT / 'scripts/prepare-mongbat-fidgets.py'))
        rows = gesture_baseline(family, registry_entries, set(recipe['CLASSES']), layered=True)
        return recipe['prepared'](rows)
    if family == 'sea_serpent_actions':
        recipe = runpy.run_path(str(ROOT / 'scripts/prepare-sea-serpent-actions.py'))
        rows = gesture_baseline(family, registry_entries, set(recipe['CLASSES']))
        return recipe['prepared'](rows)
    if family == 'ettin_fidgets':
        recipe = runpy.run_path(str(ROOT / 'scripts/prepare-ettin-fidgets.py'))
        rows = gesture_baseline(family, registry_entries, set(recipe['CLASSES']))
        return recipe['prepared'](rows)
    if family == 'kraken_fidgets':
        recipe = runpy.run_path(str(ROOT / 'scripts/prepare-kraken-fidgets.py'))
        rows = gesture_baseline(family, registry_entries, set(recipe['CLASSES']))
        return recipe['prepared'](rows)
    if family == 'orc_fidgets':
        recipe = runpy.run_path(str(ROOT / 'scripts/prepare-orc-fidgets.py'))
        rows = gesture_baseline(family, registry_entries, set(recipe['CLASSES']))
        return recipe['prepared'](rows)
    if family == 'late_classic_actions':
        recipe = runpy.run_path(str(ROOT / 'scripts/prepare-late-classic-actions.py'))
        rows = gesture_baseline(family, registry_entries, set(recipe['CLASSES']))
        return recipe['prepared'](rows)
    if family == 'hopper_horde_actions':
        recipe = runpy.run_path(str(ROOT / 'scripts/prepare-hopper-horde-actions.py'))
        rows = gesture_baseline(family, registry_entries, set(recipe['CLASSES']))
        return recipe['prepared'](rows)
    if family == 'vampire_bat_actions':
        recipe = runpy.run_path(str(ROOT / 'scripts/prepare-vampire-bat-actions.py'))
        rows = gesture_baseline(family, registry_entries, set(recipe['CLASSES']))
        return recipe['prepared'](rows)
    if family == 'grizzle_antler':
        recipe = runpy.run_path(str(ROOT / 'scripts/prepare-grizzle-antler.py'))
        rows = gesture_baseline(family, registry_entries, set(recipe['CLASSES']))
        return recipe['prepared'](rows)
    if family == 'skeletal_mage_staff':
        recipe = runpy.run_path(str(ROOT / 'scripts/prepare-skeletal-mage-staff.py'))
        rows = gesture_baseline(family, registry_entries, set(recipe['CLASSES']))
        return recipe['prepared'](rows)
    if family == 'exact_creature_fidgets':
        recipe = runpy.run_path(str(ROOT / 'scripts/prepare-exact-creature-fidgets.py'))
        rows = gesture_baseline(family, registry_entries, set(recipe['CLASSES']))
        return recipe['prepared'](rows)
    if family == 'fidget_aliases_toad':
        recipe = runpy.run_path(str(ROOT / 'scripts/prepare-fidget-aliases-toad.py'))
        rows = gesture_baseline(family, registry_entries, set(recipe['CLASSES']))
        return recipe['prepared'](rows)
    if family == 'bone_cyclops':
        recipe = runpy.run_path(str(ROOT / 'scripts/prepare-bone-knight-cyclops-actions.py'))
        rows = gesture_baseline(family, registry_entries, set(recipe['CLASSES']))
        return recipe['prepared'](rows)
    if family == 'ophidian_staff':
        recipe = runpy.run_path(str(ROOT / 'scripts/prepare-ophidian-classic.py'))
        rows = gesture_baseline(family, registry_entries, set(recipe['CLASSES']))
        return recipe['prepared'](rows)
    if family == 'terathan_classic':
        recipes = {
            70: ('terathan_terathan_warrior', 'TerathanWarrior', 'Attack',
                 'ba7d695db8ef97706e7074cf86e7180fb4712e5da5b44c2b03ae120a44f2c16d',
                 {11: ('PincerDip', '56d483ab12cc7e0a0dc0ceee08192dbca2038f9c639cf93086b152fba7c58ea2')}),
            71: ('terathan_terathan_drone', 'TerathanDrone', 'Attack',
                 '948ff146c1573d915cffb39eee915e3756596d20285eb7b3539b2c845154e8c7',
                 {11: ('PincerDip', '5ed5d4c753e4b00b4fae43c3c3cf82e44f098caf8032d2fc483a2b7534276879')}),
            72: ('terathan_terathan_queen', 'TerathanMatriarch', 'Fidget',
                 '417c3c0fe846ebe2d6be69cf4a5d0766c5816dc14eee6c840f0d773529a81105',
                 {11: ('MatriarchDip', '5f8067940b9a8dc795e15e79a39c8b86cb53d933e9d4625c60b0e53abf2f7828'),
                  12: ('TerathanCast', '8390f524cba51b04027c6b00f272915067477d6fe70595c3467c5c6ee00f9436'),
                  14: ('Cast2', '124f9d0002efe4aeb26d501b6cf479b818cd96f98d47cbd592d02e7b88f4d604')}),
        }
        descriptions = {
            'PincerDip': 'Retimed recovered upper-body Attack rotations with the original stance held',
            'MatriarchDip': 'Retimed recovered Fidget torso and abdomen motion with the original stance held',
            'TerathanCast': 'Authored held cast with green hand motes referenced to Classic group 12',
            'Cast2': 'Authored overhead release with a local hand arc referenced to Classic group 14',
        }
        ledger = json.loads((ROOT / 'outputs/creatures/actions.json').read_text(encoding='utf-8'))
        bake = json.loads((ROOT / 'work/creatures/mul-motion-review/terathan-bake.json').read_text(encoding='utf-8'))
        assert bake['recipe'] == sha(ROOT / 'scripts/bake-terathan-gestures.gd')
        assert bake['joint_solver'] == sha(ROOT / 'scripts/bake-skeleton-axe-trial.gd')
        reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
        entries = gesture_baseline(family, registry_entries, set(recipes))
        art = ROOT / 'Viewer/local-art/creatures'
        rows, classes = [], {}
        with zipfile.ZipFile(ROOT / 'work/third-dawn/uotdb.zip') as archive:
            for body, (kind, native_class, donor, donor_sha, actions) in recipes.items():
                base, = (row for row in entries if row['status'] == 'validated' and row['kind'] == kind
                         and [identity['body'] for identity in row['bodies']] == [body])
                assert hashlib.sha256(archive.read(base['clip_sources'][donor])).hexdigest() == donor_sha
                references = {str(slot): reference(ledger, body, slot, ('anim.mul', body, 5, digest))
                              for slot, (_, digest) in actions.items()}
                assets, scenes = {}, {}
                for treatment in ('original', 'rounded', 'modern'):
                    file = f'terathan-{body}-classic-{treatment}.scn'
                    source = sha(art / f'{kind}-{treatment}.gltf')
                    scenes[treatment] = sha(art / file)
                    assert source == base['asset_sha256'][treatment]
                    assert bake['forms'][str(body)][treatment] == {'source': source, 'scene': scenes[treatment]}
                    assets[treatment] = f'res://local-art/creatures/{file}'
                categories = {str(slot): clip for slot, (clip, _) in actions.items()}
                row = dict(base, status='prepared', family=family, assets=assets,
                           authored_action_scene_sha256=scenes, authored_action_reference=references['11'],
                           classic_motion_references=references,
                           classic_action_categories=base.get('classic_action_categories', {}) | categories,
                           authored_replacements=base.get('authored_replacements', {}) | {
                               clip: descriptions[clip] for clip in categories.values()})
                if body == 72:
                    visual = 'Presentation/SourceTerathanMatriarchVisual.gd'
                    row.update(presentation_script=f'res://{visual}',
                               presentation_script_sha256=sha(ROOT / 'Viewer' / visual))
                rows.append(row)
                classes[body] = [native_class]
        return rows, classes
    if family == 'dragon_daemon':
        recipe = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))
        rows = gesture_baseline(family, registry_entries, set(recipe['CLASSES']))
        return recipe['prepared'](rows)
    if family == 'ophidian_bardiche':
        body = 86
        base, = (row for row in gesture_baseline(family, registry_entries, {body})
                 if row['status'] == 'validated' and row['kind'] == 'ophidians_ophidian_warrior'
                 and [identity['body'] for identity in row['bodies']] == [body])
        recipe = runpy.run_path(str(ROOT / 'scripts/prepare-ophidian-bardiche.py'))
        recipe['checked_members']()
        private = recipe['OUTPUT']
        bake = json.loads((private / 'bake.json').read_text(encoding='utf-8'))
        source = json.loads((private / 'source.json').read_text(encoding='utf-8'))
        assert (source['member'], source['sha256'], source['atlas'], source['atlas_sha256']) == (
            recipe['WEAPON'], recipe['WEAPON_SHA'], recipe['ATLAS'], recipe['ATLAS_SHA'])
        for key, script in (('recipe', 'bake-ophidian-bardiche.gd'), ('arm', 'bake-skeleton-axe-trial.gd'),
                            ('weapon', 'bake-troll-weapons-trial.gd'), ('clearance', 'ophidian-bardiche-clearance.gd')):
            assert bake[key] == sha(ROOT / 'scripts' / script)
        assert bake['corners'] == source['corners_sha256'] == sha(private / 'corners.json')
        assert bake['atlas'] == source['png_sha256'] == sha(private / 'atlas.png')
        assets, scenes = {}, {}
        art = ROOT / 'Viewer/local-art/creatures'
        for treatment in ('original', 'rounded', 'modern'):
            file = f'ophidian-86-bardiche-{treatment}.scn'
            base_sha = sha(art / f'{base["kind"]}-{treatment}.gltf')
            scenes[treatment] = sha(art / file)
            assert base_sha == base['asset_sha256'][treatment]
            assert bake['treatments'][treatment] == {'source': base_sha, 'scene': scenes[treatment]}
            assets[treatment] = f'res://local-art/creatures/{file}'
        ledger = json.loads((ROOT / 'outputs/creatures/actions.json').read_text(encoding='utf-8'))
        record, = (item for item in ledger['original_mul_group_candidates']
                   if (item['body'], item['group']) == (body, 11) and 'matching_classic_route' in item)
        assert record['archive'] == 'anim.mul' and record['graphic'] == body and not record['mobtype_prefers_uop']
        assert [entry['direction'] for entry in record['directions']] == list(range(5))
        assert all(entry['frames'] == 5 for entry in record['directions'])
        digest = '9f4cfd4af5db47a293a738ae7e70615f3f373976b4d2ffcc2f287cc10f3073aa'
        hashes = ''.join(entry['payload_sha256'] for entry in record['directions']).encode('ascii')
        assert hashlib.sha256(hashes).hexdigest() == digest
        visual = 'Presentation/SourceArmedLizardmanVisual.gd'
        row = dict(base, status='prepared', family=family, assets=assets, authored_action_scene_sha256=scenes,
                   authored_action_reference=dict(body=body, group=11, archive='anim.mul', frames=5,
                                                  directional_payload_sha256=digest),
                   classic_action_categories=base.get('classic_action_categories', {}) | {'11': 'BardicheDip'},
                   authored_replacements=base.get('authored_replacements', {}) | {
                       'BardicheDip': 'Authored torso and tail dip with the recovered warrior bardiche on the original grasp'},
                   source_body_prop=source,
                   presentation_script=f'res://{visual}', presentation_script_sha256=sha(ROOT / 'Viewer' / visual))
        return [row], {body: ['OphidianKnight', 'OphidianWarrior']}
    if family == 'scorpion_imp':
        recipes = {
            48: ('scorpions_giant', 'Fidget', '5967204bd40ddcfb10ac0478bf522eebabe2dd19f1835e823ce40ae7346cb651',
                 'anim.mul', 48, '04b43eee722df958791e69e0d59365caefd48e8b2a4575925961b745c8e72b8d',
                 {11: ('ClawDraw', '367e0e007ee201a6ccc9ea7d8c0fff7b259a63daa994f42b10beab084cd1de95')}),
            74: ('imps_imp', 'Idle', '363fe78f8e0040b74f9546ccd35a30685e968bb3a3bb3e02bc8e181d6fae52c7',
                 'anim2.mul', 18, 'c5e35bc653d9c58d5fcda27d4a6e7c2c51672461d58da853e0607d4d31ae52e6',
                 {11: ('WingTwitch', '4d1dab4e41389efd6c764effebbf66dd737acdc64ea4c2b0b204461d5863ffe1'),
                  17: ('WingTwitch', '5d3948e1bbddce0ed77b4b34ce3c580f7fac2d11cd59df7d737265e6162a7bb1'),
                  18: ('Fidget2', '06d5c4d2b2d4f6536db70500c3fc1d4fea3f7a6b3f11d7e73bb7103eee0841d8')}),
        }
        entries = gesture_baseline(family, registry_entries, set(recipes))
        ledger = json.loads((ROOT / 'outputs/creatures/actions.json').read_text(encoding='utf-8'))
        art = ROOT / 'Viewer/local-art/creatures'
        rows = []
        with zipfile.ZipFile(ROOT / 'work/third-dawn/uotdb.zip') as source_archive:
            for body, (kind, donor, donor_sha, archive, graphic, alpha_sha, routes) in recipes.items():
                base, = (row for row in entries if row['status'] == 'validated' and row['kind'] == kind
                         and [identity['body'] for identity in row['bodies']] == [body])
                donor_member = base['clip_sources'][donor]
                assert hashlib.sha256(source_archive.read(donor_member)).hexdigest() == donor_sha
                alpha = f'{kind}-original-albedo.png'
                assert sha(art / alpha) == alpha_sha
                references, categories = {}, {}
                for slot, (clip, digest) in routes.items():
                    source, = (item for item in ledger['original_mul_group_candidates']
                               if (item['body'], item['group']) == (body, slot) and 'matching_classic_route' in item)
                    assert source['archive'] == archive and source['graphic'] == graphic and not source['mobtype_prefers_uop']
                    directions = source['directions']
                    assert [item['direction'] for item in directions] == list(range(5))
                    assert all(item['frames'] == 5 for item in directions)
                    hashes = ''.join(item['payload_sha256'] for item in directions).encode('ascii')
                    assert hashlib.sha256(hashes).hexdigest() == digest
                    references[str(slot)] = dict(body=body, group=slot, archive=archive, graphic=graphic,
                                                 frames=5, directional_payload_sha256=digest)
                    categories[str(slot)] = clip
                assets, scenes = {}, {}
                for treatment in ('original', 'rounded', 'modern'):
                    assert sha(art / f'{kind}-{treatment}.gltf') == base['asset_sha256'][treatment]
                    file = f'mul-gesture-{body}-{treatment}.scn'
                    assets[treatment] = f'res://local-art/creatures/{file}'
                    scenes[treatment] = sha(art / file)
                replacements = ({'ClawDraw': 'Recovered fidget claw and tail tracks retimed independently with held support'}
                                if body == 48 else {
                                    'WingTwitch': 'Authored restrained wing motion on the recovered idle pose',
                                    'Fidget2': 'Same authored wing motion for the pixel-equivalent Classic slot 18'})
                rows.append(dict(base, status='prepared', family=family, assets=assets,
                                 authored_action_scene_sha256=scenes, authored_action_reference=references['11'],
                                 classic_motion_references=references, source_alpha_texture=alpha,
                                 art_dependency_sha256=base.get('art_dependency_sha256', {}) | {alpha: alpha_sha},
                                 classic_action_categories=base.get('classic_action_categories', {}) | categories,
                                 authored_replacements=base.get('authored_replacements', {}) | replacements,
                                 clip_sources=base['clip_sources'] | (
                                     {'ClawDraw': donor_member} if body == 48 else {})))
        return rows, {48: ['Scorpion'], 74: ['Imp']}
    if family == 'gargoyle_classic':
        body = 4
        base, = (row for row in gesture_baseline(family, registry_entries, {body})
                 if row['status'] == 'validated' and row['kind'] == 'gargoyles_gargoyle'
                 and [identity['body'] for identity in row['bodies']] == [body])
        recipe = runpy.run_path(str(ROOT / 'scripts/prepare-gargoyle-classic.py'))
        recipe['source_cast']()
        art = recipe['ART']
        bake = json.loads((art / 'gargoyle-4-classic-bake.json').read_text(encoding='utf-8'))
        assert bake['recipe'] == sha(ROOT / 'scripts/bake-gargoyle-classic.gd')
        assert bake['leg_solver'] == sha(ROOT / 'scripts/bake-gargoyle-pillage-trial.gd')
        assert bake['donor'] == sha(art / 'gargoyle-4-cast-donor.gltf')
        treatments = ('original', 'rounded', 'modern')
        assets, scenes = {}, {}
        for treatment in treatments:
            file = f'gargoyle-4-classic-{treatment}.scn'
            source = sha(art / f'gargoyles_gargoyle-{treatment}.gltf')
            scenes[treatment] = sha(art / file)
            assert source == base['asset_sha256'][treatment]
            assert bake['treatments'][treatment] == {'source': source, 'scene': scenes[treatment]}
            assets[treatment] = f'res://local-art/creatures/{file}'
        for file, digest in base['art_dependency_sha256'].items():
            assert sha(art / file) == digest
        ledger = json.loads((ROOT / 'outputs/creatures/actions.json').read_text(encoding='utf-8'))
        references = {}
        for slot, frames, digest in (
                (11, 5, 'e52bcba1cf0205da01607774fc5e892f14bfaf14740774b0effef9aeddd76793'),
                (12, 7, 'be406a0b131cdc28550a1695a1297823a3c541f12c592911a8e689b3edf24885')):
            source, = (item for item in ledger['original_mul_group_candidates']
                       if (item['body'], item['group']) == (body, slot) and 'matching_classic_route' in item)
            assert source['archive'] == 'anim.mul' and source['graphic'] == body and not source['mobtype_prefers_uop']
            directions = source['directions']
            assert [item['direction'] for item in directions] == list(range(5))
            assert all(item['frames'] == frames for item in directions)
            hashes = ''.join(item['payload_sha256'] for item in directions).encode('ascii')
            assert hashlib.sha256(hashes).hexdigest() == digest
            references[str(slot)] = dict(body=body, group=slot, archive='anim.mul', frames=frames,
                                         directional_payload_sha256=digest)
        member = recipe['CAST_MEMBER']
        row = dict(base, status='prepared', family=family, assets=assets, authored_action_scene_sha256=scenes,
                   authored_action_reference=references['11'], classic_motion_references=references,
                   classic_action_categories=base.get('classic_action_categories', {}) | {
                       '11': 'KneelingLunge', '12': 'Cast'},
                   authored_replacements=base.get('authored_replacements', {}) | {
                       'KneelingLunge': 'Authored forward step and wing opening from the Classic MUL reference'},
                   clip_sources=base['clip_sources'] | {'Cast': member},
                   recovered_action_source={
                       'member': member, 'sha256': recipe['CAST_SHA'],
                       'cabinet': 'uoaos/UOTD/models/monsters/client11.cab', 'cabinet_sha256': recipe['CAB_SHA'],
                       'scope': '54 matched Age of Shadows tracks, with floor adjustment for the retained Third Dawn mesh',
                   })
        return [row], {body: ['Gargoyle']}
    if family == 'earth_elemental_aos':
        recipe = runpy.run_path(str(ROOT / 'scripts/prepare-earth-elemental-aos.py'))
        return [recipe['candidate']()], {14: recipe['CLASSES']}
    if family in ('spider_mongbat', 'reaper_harpy', 'wraith_sway'):
        recipes = {
            28: ('arachnids_spider_giant', 'AbdomenShift',
                 'c8c8752d1c88c0d050703bfa405af03e6044aa53a78d30bd8a78aea76a8943db'),
            39: ('mongbats_mongbat', 'WingSettle',
                 '97ad0db8b2e9ed02714dd1063f7b165c760319e49299628ebaee5b6c044bfa45'),
        } if family == 'spider_mongbat' else {
            30: ('harpies_harpy', 'Wingbeat',
                 'e7ec1461b9527155ab2224b9241573f10dcc03341480b49e767e1c1f6b880c65'),
            47: ('flails_reaper', 'TrunkBend',
                 '989d27a1410372609e3cd79b0238fed8012d57ebb290caeab9cb026775567b0c'),
        } if family == 'reaper_harpy' else {
            26: ('spirits_ghost', 'GhostSway',
                 '2463baded3114d8169a50cdcd5c64d36307c9a7e76d840a5c2458bf7dbbdf107'),
        }
        entries = gesture_baseline(family, registry_entries, set(recipes))
        ledger = json.loads((ROOT / 'outputs/creatures/actions.json').read_text(encoding='utf-8'))
        rows = []
        for body, (kind, clip, digest) in recipes.items():
            base, = (row for row in entries if row['status'] == 'validated' and row['kind'] == kind
                     and [identity['body'] for identity in row['bodies']] == [body])
            source, = (row for row in ledger['original_mul_group_candidates']
                       if (row['body'], row['group']) == (body, 11) and 'matching_classic_route' in row)
            assert source['archive'] == 'anim.mul' and source['graphic'] == body and not source['mobtype_prefers_uop']
            directions = source['directions']
            assert [entry['direction'] for entry in directions] == list(range(5))
            assert all(entry['frames'] == 5 for entry in directions)
            hashes = ''.join(entry['payload_sha256'] for entry in directions).encode('ascii')
            assert hashlib.sha256(hashes).hexdigest() == digest
            assets = {name: f'res://local-art/creatures/mul-gesture-{body}-{name}.scn'
                      for name in ('original', 'rounded', 'modern')}
            row = dict(base, status='prepared', family=family, assets=assets,
                             authored_action_reference={'body': body, 'group': 11, 'archive': 'anim.mul',
                                                        'directional_payload_sha256': digest},
                             authored_action_scene_sha256={name: sha(ROOT / 'Viewer' / path.removeprefix('res://'))
                                                           for name, path in assets.items()},
                             classic_action_categories=base.get('classic_action_categories', {}) | {'11': clip},
                             authored_replacements=base.get('authored_replacements', {}) | {
                                 clip: 'Authored gesture from five-frame Classic MUL slot 11'})
            alpha_hashes = {
                26: 'c75858973762664a4c069bb0c61b25f65f4f786bd4e8b8a180543051ff39e96e',
                39: '0060dd037c56dd226a68c21160fefc2ebcf8b2527025783960a773a48cc15e6d',
                47: '844b97fad8b1ef92371fd45c041e84d268cf4bf41c639e412d09b460df6c8e00',
            }
            if body in alpha_hashes:
                alpha = f'{kind}-original-albedo.png'
                alpha_sha = alpha_hashes[body]
                assert sha(ROOT / 'Viewer/local-art/creatures' / alpha) == alpha_sha
                row['source_alpha_texture'] = alpha
                row['art_dependency_sha256'] = base.get('art_dependency_sha256', {}) | {alpha: alpha_sha}
            if body == 30:
                fly = 'uotdb/uotd/Models/Monsters/harpies_harpy_fly.grn'
                fly_sha = '6e74003a5e945b5afc4ef5a26ceb235dce63a451ac540ec95b6ff88084568501'
                assert base['clip_sources']['Fly'] == fly
                assert {'member': fly, 'sha256': fly_sha} in base['inputs']
                donor = ROOT / 'work/third-dawn/late-source-research/uoaos-source/Models/Monsters' / Path(fly).name
                assert sha(donor) == fly_sha
                visual = 'Presentation/SourceHarpyWingbeatVisual.gd'
                row['presentation_script'] = f'res://{visual}'
                row['presentation_script_sha256'] = sha(ROOT / 'Viewer' / visual)
                row['clip_sources'] = base['clip_sources'] | {clip: fly}
                row['authored_replacements'][clip] = 'Rephased recovered Harpy flight cycle with a blended seam, following Classic MUL slot 11'
            if body == 26:
                idle = 'uotdb/uotd/Models/Monsters/spirits_ghost_idle.grn'
                idle_sha = '960a959a792c389b768c4aa6d9050c715f8e8273391ea56b59aea8e1d897cf3b'
                assert base['clip_sources']['Idle'] == idle
                with zipfile.ZipFile(ROOT / 'work/third-dawn/uotdb.zip') as archive:
                    assert hashlib.sha256(archive.read(idle)).hexdigest() == idle_sha
                row['clip_sources'] = base['clip_sources'] | {clip: idle}
                row['authored_replacements'][clip] = 'Attenuated one-shot source idle sway, following Classic MUL slot 11'
                row['native_constructor_hues'] = {'Shade': 0x4001, 'Spectre': 0x4001, 'Spellbinder': 0, 'Wraith': 0x4001}
                visual = 'Presentation/SourceWraithVisual.gd'
                row['presentation_script'] = f'res://{visual}'
                row['presentation_script_sha256'] = sha(ROOT / 'Viewer' / visual)
                shader = 'Presentation/WraithSpectralSurface.gdshader'
                row['spectral_shader_sha256'] = sha(ROOT / 'Viewer' / shader)
            rows.append(row)
        if family == 'reaper_harpy':
            return rows, {30: ['Harpy'], 47: ['Reaper']}
        if family == 'wraith_sway':
            return rows, {26: ['Shade', 'Spectre', 'Spellbinder', 'Wraith']}
        return rows, {28: ['GiantSpider'], 39: ['GreaterMongbat', 'Mongbat', 'StrongMongbat']}
    if family == 'ratman_hunch':
        body = 42
        base, = (row for row in gesture_baseline(family, registry_entries, {body})
                 if row['status'] == 'validated' and row['kind'] == 'rat_race_ratman'
                 and any(identity['body'] == body for identity in row['bodies']))
        identity, = (entry for entry in base['bodies'] if entry['body'] == body)
        ledger = json.loads((ROOT / 'outputs/creatures/actions.json').read_text(encoding='utf-8'))
        group, = (row for row in ledger['original_mul_group_candidates']
                  if (row['body'], row['group']) == (body, 11) and 'matching_classic_route' in row)
        assert group['archive'] == 'anim.mul' and group['graphic'] == body and not group['mobtype_prefers_uop']
        assert [entry['direction'] for entry in group['directions']] == list(range(5))
        digest = hashlib.sha256(''.join(entry['payload_sha256'] for entry in group['directions']).encode('ascii')).hexdigest()
        assert digest == '7c4ceb8be8a2d750530b92241524ed61bf6f6f1f0ee8f34df498172994aaf1d6'
        assets = {name: 'res://local-art/creatures/slot11-42-trial'
                  + ('' if name == 'modern' else f'-{name}') + '.scn'
                  for name in ('original', 'rounded', 'modern')}
        row = dict(base, status='prepared', family=family, bodies=[identity], assets=assets,
                   authored_action_reference={'body': body, 'group': 11, 'archive': 'anim.mul',
                                              'directional_payload_sha256': digest},
                   authored_action_scene_sha256={name: sha(ROOT / 'Viewer' / path.removeprefix('res://'))
                                                 for name, path in assets.items()},
                   classic_action_categories=base.get('classic_action_categories', {}) | {'11': 'Hunch'},
                   authored_replacements=base.get('authored_replacements', {}) | {
                       'Hunch': 'Authored Ratman hunch from five-frame Classic MUL slot 11'})
        return [row], {body: ['Ratman']}
    if family == 'skeleton_axe':
        body = 56
        base, = (row for row in gesture_baseline(family, registry_entries, {body})
                 if row['status'] == 'validated' and row['kind'] == 'skeletons_skeleton'
                 and any(identity['body'] == body for identity in row['bodies']))
        identity, = (entry for entry in base['bodies'] if entry['body'] == body)
        ledger = json.loads((ROOT / 'outputs/creatures/actions.json').read_text(encoding='utf-8'))
        group, = (row for row in ledger['original_mul_group_candidates']
                  if (row['body'], row['group']) == (body, 11) and 'matching_classic_route' in row)
        assert group['archive'] == 'anim.mul' and group['graphic'] == body and not group['mobtype_prefers_uop']
        assert [entry['direction'] for entry in group['directions']] == list(range(5))
        digest = hashlib.sha256(''.join(entry['payload_sha256'] for entry in group['directions']).encode('ascii')).hexdigest()
        assert digest == 'd93d2e233a57f8c9529948f63cca8384e418b09d76e2c88554a8ad3aee977db6'
        export = runpy.run_path(str(ROOT / 'scripts/prepare-skeleton-axe.py'))
        models = ROOT / 'work/third-dawn/late-source-research/uoaos-source/Models'
        assert sha(models / export['MEMBER']) == export['DIGEST']
        renderer = 'Presentation/SourceArmedLizardmanVisual.gd'
        assets = {name: f'res://local-art/creatures/skeleton-56-axe-trial-{name}.scn'
                  for name in ('original', 'rounded', 'modern')}
        row = dict(base, status='prepared', family=family, bodies=[identity], assets=assets,
                   presentation_script=f'res://{renderer}',
                   presentation_script_sha256=sha(ROOT / 'Viewer' / renderer),
                   authored_action_reference={'body': body, 'group': 11, 'archive': 'anim.mul',
                                              'directional_payload_sha256': digest,
                                              'weapon_member': export['MEMBER'], 'weapon_sha256': export['DIGEST']},
                   authored_action_scene_sha256={name: sha(ROOT / 'Viewer' / path.removeprefix('res://'))
                                                 for name, path in assets.items()},
                   classic_action_categories=base.get('classic_action_categories', {}) | {'11': 'AxeReach'},
                   authored_replacements=base.get('authored_replacements', {}) | {
                       'AxeReach': 'Authored Classic reach with the archived Skeleton Axe'})
        return [row], {body: ['Skeleton', 'Spellbinder']}
    if family == 'giant_serpent_pillage':
        body = 21
        base, = (row for row in gesture_baseline(family, registry_entries, {body})
                 if row['status'] == 'validated' and row['kind'] == 'serpents_snake_giant'
                 and [identity['body'] for identity in row['bodies']] == [body])
        ledger = json.loads((ROOT / 'outputs/creatures/actions.json').read_text(encoding='utf-8'))
        source, = (row for row in ledger['original_mul_group_candidates']
                   if (row['body'], row['group']) == (body, 11) and 'matching_classic_route' in row)
        assert source['archive'] == 'anim.mul' and source['graphic'] == body and not source['mobtype_prefers_uop']
        assert [entry['direction'] for entry in source['directions']] == list(range(5))
        digest = hashlib.sha256(''.join(entry['payload_sha256'] for entry in source['directions']).encode('ascii')).hexdigest()
        assert digest == 'bfdb53aef972d86f5947473bb8808e573dbbfc4d9691aa3281f133aa96e22bdd'
        donor, = (row for row in json.loads((ROOT / 'Viewer/local-art/creatures/accepted-index.json')
                                           .read_text(encoding='utf-8'))['entries']
                  if row['status'] == 'validated' and row['kind'] == 'serpents_snake_giant_silver')
        member = 'Models/Monsters/serpents_snake_giant_pillage.grn'
        path = ROOT / 'work/third-dawn/late-source-research/uoaos-source' / member
        assert donor['clip_sources']['Pillage'] == f'uoaos/UOTD/{member}'
        assert sha(path) == 'c1305092877edd08eb2e444847ed5a56f84dc94c86914ce418ac0cb4f343e21c'
        assets = {}
        for name in ('original', 'rounded', 'modern'):
            donor_asset = ROOT / 'Viewer/local-art/creatures' / f'serpents_snake_giant_silver-{name}.gltf'
            assert sha(donor_asset) == donor['asset_sha256'][name]
            assets[name] = f'res://local-art/creatures/giant-serpent-21-pillage-{name}.scn'
        row = dict(base, status='prepared', family=family, assets=assets,
                   authored_action_reference={'body': body, 'group': 11, 'archive': 'anim.mul',
                                              'directional_payload_sha256': digest, 'source_member': member},
                   authored_action_scene_sha256={name: sha(ROOT / 'Viewer' / path.removeprefix('res://'))
                                                 for name, path in assets.items()},
                   classic_action_categories=base.get('classic_action_categories', {}) | {'11': 'Pillage'},
                   clip_sources=base['clip_sources'] | {'Pillage': f'uoaos/UOTD/{member}'},
                   native_constructor_hue_ranges={'GiantSerpent': [[2001, 2018]]})
        return [row], {body: ['GiantSerpent']}
    if family == 'ready_stances':
        redirects = runpy.run_path(str(ROOT / 'scripts/prepare-creature-uop-redirects.py'))
        entries = registry_entries if registry_entries is not None else redirects['read'](redirects['INDEX'])['entries']
        ledger = redirects['read'](redirects['LEDGER'])
        sources = {730: ('raptor', '64b5c5bbdb0c7ee0bbd97af107c3b30ae58a97229d43738e0d95b96ef7235d85'),
                   734: ('slith', '3080bf857102a6b02d5e8d2cf64b5d74568a4068c7f2127da651c33c7dfe1e85')}
        rows, constructors = [], {}
        for body, (package, digest) in sources.items():
            current, = (row for row in entries if row['status'] == 'validated'
                         and [identity['body'] for identity in row['bodies']] == [body])
            base = redirects['without_active_redirect'](current)
            original, classes = prepared_entries(package)
            assert base == dict(original[0], status='validated')
            source, = (row for row in ledger['original_uop_frame_groups']
                       if (row['body'], row['group']) == (body, 25))
            assert (source['archive'], source['frame_headers'], source['payload_sha256']) == ('AnimationFrame3.uop', 50, digest)
            link, = (row for row in ledger['original_group_links']
                     if (row['body'], row['old_group']) == (body, 11))
            assert link['frame_count'] == 0 and link['new_group'] == 25
            type14, = (row for row in ledger['original_new_protocol_actions']
                       if (row['body'], row['mode'], row['type'], row['subaction']) == (body, 0, 14, -1))
            assert type14['groups'] == [25]
            assets = {treatment: f"res://local-art/creatures/ready-stance-{body}-"
                      f"{'shared' if body == 730 else treatment}.scn" for treatment in base['assets']}
            rows.append(dict(base, status='prepared', family=family, assets=assets,
                             authored_action_reference=dict(source, group=11, uop_group=25, new_type=14),
                             authored_action_scene_sha256={name: sha(ROOT / 'Viewer' / path.removeprefix('res://'))
                                                           for name, path in assets.items()},
                             classic_action_categories=base.get('classic_action_categories', {}) | {'11': 'ReadyStance'},
                             new_action_categories=base.get('new_action_categories', {}) | {'14': 'ReadyStance'},
                             authored_replacements=base.get('authored_replacements', {}) | {
                                 'ReadyStance': 'Authored ready stance from the ten-frame preferred UOP group 25'}))
            constructors[body] = classes[body]
        return rows, constructors
    if family == 'uop_redirects':
        redirects = runpy.run_path(str(ROOT / 'scripts/prepare-creature-uop-redirects.py'))
        entries = registry_entries if registry_entries is not None else redirects['read'](redirects['INDEX'])['entries']
        entries = [redirects['without_active_redirect'](row) for row in entries]
        rows = redirects['build_rows'](entries, redirects['read'](redirects['LEDGER']))
        classes = {130: ['FireGargoyle'], 692: ['AnimatedWeapon'], 730: ['Raptor'],
                   734: ['Slith', 'StoneSlith', 'ToxicSlith'], 753: ['EnslavedGargoyle']}
        assert {row['body'] for row in rows} == set(classes)
        return [dict(row['presentation'], status='prepared', family=family,
                     uop_redirect_targets=row['targets']) for row in rows], classes
    if family in ('parrot_flight', 'troglodyte_reach'):
        return prepared_recovered_action(family, registry_entries)
    if family == 'blistering_pillage':
        body = 130
        base, = (row for row in gesture_baseline(family, registry_entries, {body})
                 if row['status'] == 'validated' and row['kind'] == 'gargoyles_gargoyle_blistering'
                 and [identity['body'] for identity in row['bodies']] == [body])
        ledger = json.loads((ROOT / 'outputs/creatures/actions.json').read_text(encoding='utf-8'))
        source, = (group for group in ledger['original_uop_frame_groups']
                   if (group['body'], group['group']) == (body, 11))
        assert source['archive'] == 'AnimationFrame1.uop' and source['frame_headers'] == 55
        assert source['payload_sha256'] == 'fc5bf56283de49c0533acd72887418b43faba39bef55b6fda0e770de575d4a9c'
        assets = {name: 'res://local-art/creatures/gargoyle-130-pillage-trial'
                  + ('' if name == 'modern' else f'-{name}') + '.scn'
                  for name in ('original', 'rounded', 'modern')}
        row = dict(base, status='prepared', family=family, assets=assets,
                   authored_action_reference=source,
                   authored_action_scene_sha256={name: sha(ROOT / 'Viewer' / path.removeprefix('res://'))
                                                 for name, path in assets.items()},
                   classic_action_categories=base.get('classic_action_categories', {}) | {'11': 'Pillage'},
                   authored_replacements=base.get('authored_replacements', {}) | {
                       'Pillage': 'Authored crouch and alternating reach from preferred UOP reference'})
        return [row], {body: ['FireGargoyle']}
    if family == 'troll_gestures':
        ledger = json.loads((ROOT / 'outputs/creatures/actions.json').read_text(encoding='utf-8'))
        recipes = {
            53: ('Troll', 'troll-53-armed-trial', '801f216ae2248f69fec6ebe15b59d50d479a61d2903f67577e86e784870d975d'),
            54: ('Troll', 'trolls_troll-slot11-trial', 'ed953fa26f763e431bc68a8c3421a93ddf609f8207e93c83074f9014c548bb3c'),
            55: ('FrostTroll', 'troll-55-armed-trial', '38dfb903a8a9f0603d50c2be76621aebb2d5d24bda5daaf4524931780837312f'),
        }
        registry_entries = gesture_baseline(family, registry_entries, recipes)
        renderer = 'Presentation/SourceArmedLizardmanVisual.gd'
        rows, classes = [], {}
        for body, (native_class, stem, digest) in recipes.items():
            base, = (row for row in registry_entries if row['status'] == 'validated'
                     and any(identity['body'] == body for identity in row['bodies']))
            identity, = (identity for identity in base['bodies'] if identity['body'] == body)
            source, = (row for row in ledger['original_mul_group_candidates']
                       if (row['body'], row['group']) == (body, 11))
            directions = source['directions']
            payload = ''.join(item['payload_sha256'] for item in directions).encode('ascii')
            assert source['archive'] == 'anim.mul' and not source['mobtype_prefers_uop']
            assert [item['direction'] for item in directions] == list(range(5))
            assert hashlib.sha256(payload).hexdigest() == digest
            assets = {name: f'res://local-art/creatures/{stem}'
                      + ('' if name == 'modern' else f'-{name}') + '.scn'
                      for name in ('original', 'rounded', 'modern')}
            rows.append(dict(base, status='prepared', family=family, bodies=[identity], assets=assets,
                             authored_action_scene_sha256={name: sha(ROOT / 'Viewer' / path.removeprefix('res://'))
                                                           for name, path in assets.items()},
                             presentation_script=f'res://{renderer}',
                             presentation_script_sha256=sha(ROOT / 'Viewer' / renderer),
                             authored_action_reference=digest,
                             classic_action_categories=base.get('classic_action_categories', {}) | {'11': 'KneelingSwing'},
                             authored_replacements=base.get('authored_replacements', {}) | {
                                 'KneelingSwing': 'Authored kneeling swing from decoded Classic slot 11 frames'}))
            classes[body] = [native_class]
        return rows, classes
    if family == 'classic_gestures':
        manifest = json.loads((ROOT / 'scripts/classic-gesture-inputs.json').read_text(encoding='utf-8'))
        registry_entries = gesture_baseline(family, registry_entries, set(map(int, manifest)))
        ledger = json.loads((ROOT / 'outputs/creatures/actions.json').read_text(encoding='utf-8'))
        rows, classes = [], {}
        for key, recipe in manifest.items():
            body = int(key)
            base, = (row for row in registry_entries if row['status'] == 'validated'
                     and any(identity['body'] == body for identity in row['bodies']))
            identity, = (identity for identity in base['bodies'] if identity['body'] == body)
            source, = (row for row in ledger['original_mul_group_candidates']
                       if (row['body'], row['group']) == (body, 11))
            directions = source['directions']
            payload = ''.join(item['payload_sha256'] for item in directions).encode('ascii')
            assert source['archive'] == 'anim.mul' and not source['mobtype_prefers_uop']
            assert [item['direction'] for item in directions] == list(range(5))
            assert hashlib.sha256(payload).hexdigest() == recipe['directional_payload_sha256']
            assets = {name: f'res://local-art/creatures/slot11-{body}-trial'
                      + ('' if name == 'modern' else f'-{name}') + '.scn'
                      for name in ('original', 'rounded', 'modern')}
            clip = recipe['clip']
            rows.append(dict(base, status='prepared', family=family, bodies=[identity], assets=assets,
                             authored_action_scene_sha256={name: sha(ROOT / 'Viewer' / path.removeprefix('res://'))
                                                           for name, path in assets.items()},
                             authored_action_reference=recipe['directional_payload_sha256'],
                             classic_action_categories=base.get('classic_action_categories', {}) | {'11': clip},
                             authored_replacements=base.get('authored_replacements', {}) | {
                                 clip: 'Authored gesture from decoded Classic slot 11 frames'}))
            classes[body] = recipe['classes']
        return rows, classes
    if family == 'gargoyle_pillage':
        art = ROOT / 'Viewer/local-art/creatures'
        index = json.loads((art / 'accepted-index.json').read_text(encoding='utf-8'))
        base, = (row for row in index['entries']
                 if row['status'] == 'validated' and row['kind'] == 'gargoyles_gargoyle_slave')
        if 'uop_redirect_native_sha256' in base:
            redirects = runpy.run_path(str(ROOT / 'scripts/prepare-creature-uop-redirects.py'))
            base = redirects['without_active_redirect'](base)
        if 'authored_action_native_sha256' in base:
            evidence = runpy.run_path(str(ROOT / 'scripts/gargoyle-pillage-evidence.py'))
            active = base
            base = dict(active, assets=active['authored_action_base_assets'],
                        classic_action_categories={key: value for key, value in active['classic_action_categories'].items()
                                                   if key != '11'},
                        authored_replacements={key: value for key, value in active['authored_replacements'].items()
                                               if key != 'Pillage'})
            for key in ('authored_action_native_sha256', 'authored_action_base_assets',
                        'authored_action_reference', 'authored_action_scene_sha256'):
                base.pop(key)
            assert evidence['compose'](base, True) == active
        ledger = json.loads((ROOT / 'outputs/creatures/actions.json').read_text(encoding='utf-8'))
        source, = (group for group in ledger['original_uop_frame_groups']
                   if (group['body'], group['group']) == (753, 11))
        assert source['archive'] == 'AnimationFrame4.uop' and source['frame_headers'] == 65
        assert source['payload_sha256'] == '7645864d894aee1d394f8c38fb235392553b3ccf8b29b0cb34913ae3cd6bfaef'
        assets = {name: 'res://local-art/creatures/gargoyle-753-pillage-trial'
                  + ('' if name == 'modern' else f'-{name}') + '.scn'
                  for name in ('original', 'rounded', 'modern')}
        row = dict(base, status='prepared', family=family, assets=assets,
                   authored_action_reference=source,
                   authored_action_scene_sha256={name: sha(ROOT / 'Viewer' / path.removeprefix('res://'))
                                                 for name, path in assets.items()},
                   classic_action_categories=base['classic_action_categories'] | {'11': 'Pillage'},
                   authored_replacements=base['authored_replacements'] | {
                       'Pillage': 'Authored crouch and alternating reach from preferred UOP reference'})
        return [row], {753: ['EnslavedGargoyle']}
    if family == 'lizard_armed':
        art = ROOT / 'Viewer/local-art/creatures'
        index = json.loads((art / 'accepted-index.json').read_text(encoding='utf-8'))
        base, = (row for row in index['entries']
                 if row['status'] == 'validated' and row['kind'] == 'lizard_race_lizardman')
        renderer = 'Presentation/SourceArmedLizardmanVisual.gd'
        rows = []
        for body, form in ((35, 'spear'), (36, 'mace')):
            owners = [row for row in index['entries'] if row['status'] == 'validated'
                      and row['kind'] in (base['kind'], f'lizardman_{form}')]
            identity, = (identity for row in owners for identity in row['bodies'] if identity['body'] == body)
            asset = art / f'lizardman-pillage-trial-{form}.scn'
            row = dict(base, status='prepared', kind=f'lizardman_{form}', family=family, bodies=[identity],
                       assets={'modern': f'res://local-art/creatures/{asset.name}'},
                       asset_sha256={'modern': sha(asset)}, import_sha256={},
                       presentation_script=f'res://{renderer}',
                       presentation_script_sha256=sha(ROOT / 'Viewer' / renderer),
                       classic_action_categories={'11': 'Pillage'},
                       authored_replacements={'Pillage': 'Authored stoop on the original idle rig'})
            rows.append(row)
        return rows, {35: ['Lizardman'], 36: ['Lizardman']}
    assert family in ['mages','juka','juka_lord','hydra','energy_vortex','late_source','champions','fey_champions','crane','deathwatch','tsuki_wolf','kappa','vampire_bat','yomotsu','occurrence_next','horde_rune','sand_vortex','bake_kitsune','devourer_lion_hiryu','hiryu_mount','elemental_minotaur','meer_donors','captain_cu','clockwork_tokuno','aos_creatures','aos_aliases','aos_mound','recovered_late','tormented_minotaur','harrower','late_donors','gargoyle_vendor','aos_armed','aos_abysmal','animated_weapon','slith','raptor','fetid_essence','corporeal_brume','khaldun_doom','candidate_batch','solen_queens',*PREPARED_FORMS],'Prepared native trial requires an explicit checked family'
    if family in ('late_source', 'champions', 'fey_champions', 'yomotsu', 'occurrence_next', 'horde_rune', 'sand_vortex', 'bake_kitsune', 'devourer_lion_hiryu', 'hiryu_mount', 'elemental_minotaur', 'meer_donors', 'captain_cu', 'clockwork_tokuno', 'aos_creatures', 'aos_aliases', 'aos_mound', 'recovered_late', 'tormented_minotaur', 'harrower', 'late_donors', 'gargoyle_vendor', 'aos_armed', 'aos_abysmal', 'animated_weapon', 'slith', 'raptor', 'fetid_essence', 'corporeal_brume', 'khaldun_doom'):
        classes, manifest = {
            'late_source': ({266: ['InsaneDryad', 'MLDryad'], 267: ['Lurg', 'Troglodyte'], 279: ['Ferret']}, 'late-creature-inputs.json'),
            'champions': ({172: ['Rikktor'], 173: ['Mephitis']}, 'champion-creature-inputs.json'),
            'fey_champions': ({174: ['Semidar'], 175: ['LordOaks'], 176: ['Silvani']}, 'fey-champion-inputs.json'),
            'yomotsu': ({245: ['YomotsuWarrior'], 253: ['YomotsuPriest'], 255: ['YomotsuElder']}, 'yomotsu-inputs.json'),
            'occurrence_next': ({309: ['PatchworkSkeleton'], 196: ['KazeKemono'], 302: ['SkitteringHopper'], 247: ['FanDancer']}, 'occurrence-creature-inputs.json'),
            'horde_rune': ({776: ['HordeMinion', 'HordeMinionFamiliar'], 244: ['RuneBeetle']}, 'horde-rune-inputs.json'),
            'sand_vortex': ({790: ['SandVortex']}, 'sand-vortex-inputs.json'),
            'bake_kitsune': ({246: ['BakeKitsune']}, 'bake-kitsune-inputs.json'),
            'devourer_lion_hiryu': ({303: ['Devourer'], 251: ['RevenantLion'], 243: ['Hiryu', 'LesserHiryu']}, 'devourer-lion-hiryu-inputs.json'),
            'hiryu_mount': ({243: ['Hiryu', 'LesserHiryu']}, 'devourer-lion-hiryu-inputs.json'),
            'elemental_minotaur': ({300: ['CrystalElemental'], 263: ['Minotaur'], 305: ['GoreFiend'], 281: ['MinotaurScout'], 241: ['Oni'], 789: ['Quagmire'], 772: ['MeerEternal']}, 'elemental-minotaur-inputs.json'),
            'meer_donors': ({771: ['MeerWarrior'], 770: ['MeerMage'], 773: ['MeerCaptain']}, 'meer-donor-inputs.json'),
            'animated_weapon': ({692: ['AnimatedWeapon']}, 'animated-weapon-inputs.json'),
            'slith': ({734: ['Slith', 'StoneSlith', 'ToxicSlith']}, 'slith-inputs.json'),
            'raptor': ({730: ['Raptor']}, 'raptor-inputs.json'),
            'fetid_essence': ({273: ['FetidEssence', 'MantraEffervescence']}, 'fetid-essence-inputs.json'),
            'corporeal_brume': ({260: ['CorporealBrume']}, 'corporeal-brume-inputs.json'),
            'khaldun_doom': ({637: ['SpectralArmour'], 970: ['RestlessSoul']}, 'khaldun-doom-inputs.json'),
            'aos_abysmal': ({312: ['AbysmalHorror']}, 'aos-abysmal-inputs.json'),
            'aos_armed': ({311: ['ShadowKnight'], 314: ['Ravager']}, 'aos-armed-inputs.json'),
            'gargoyle_vendor': ({758: ['Provisioner']}, 'gargoyle-vendor-inputs.json'),
            'late_donors': ({831: ['Parrot'], 767: ['Betrayer']}, 'late-donor-inputs.json'),
            'harrower': ({146: ['Harrower']}, 'harrower-inputs.json'),
            'tormented_minotaur': ({262: ['TormentedMinotaur']}, 'tormented-minotaur-inputs.json'),
            'recovered_late': ({768: ['Juggernaut'], 249: ['Yamandon', 'Serado'], 276: ['Reptalon']}, 'recovered-late-inputs.json'),
            'aos_mound': ({319: ['MoundOfMaggots']}, 'aos-mound-inputs.json'),
            'aos_aliases': ({315: ['FleshRenderer'], 316: ['WandererOfTheVoid']}, 'aos-creature-alias-inputs.json'),
            'aos_creatures': ({306: ['Impaler'], 307: ['Gibberling'], 308: ['BoneDemon'], 313: ['DarknightCreeper'], 318: ['DemonKnight']}, 'aos-creature-inputs.json'),
            'captain_cu': ({280: ['MinotaurCaptain'], 277: ['CuSidhe']}, 'captain-cu-inputs.json'),
            'clockwork_tokuno': ({304: ['FleshGolem'], 757: ['ExodusMinion'], 756: ['ExodusOverseer'], 252: ['LadyOfTheSnow'], 199: ['RaiJu'], 271: ['Satyr'], 310: ['WailingBanshee'], 278: ['Squirrel']}, 'clockwork-tokuno-inputs.json'),
        }[family]
        path = ROOT / 'Viewer/local-art/creatures' / family / 'preparation.json'
        report = json.loads(path.read_text(encoding='utf-8'))
        manifest_key = 'source_manifest_sha256' if family == 'late_source' else 'input_manifest_sha256'
        assert report[manifest_key] == sha(ROOT / 'scripts' / manifest)
        rows = report['models']
        assert [row['bodies'][0]['body'] for row in rows] == list(classes)
        for row in rows:
            identity, = row['bodies']
            hues = row.get('native_constructor_hue_ranges', row.get('native_constructor_hues', {}))
            assert row['status'] == 'prepared' and set(hues) == set(classes[identity['body']])
            for source in identity['native_sources']:
                target = ROOT / 'Server/ModernUO' / source['path'].replace('\\', '/')
                assert sha(target) == source['sha256']
            pins = {**row['art_dependency_sha256'],
                    **{asset: row['asset_sha256'][name] for name, asset in row['assets'].items()}}
            if 'presentation_script' in row:
                pins[row['presentation_script']] = row['presentation_script_sha256']
            for asset, digest in pins.items():
                assert asset.startswith('res://')
                target = (ROOT / 'Viewer' / asset.removeprefix('res://')).resolve()
                assert target.is_relative_to(ROOT / 'Viewer') and sha(target) == digest
        return rows, classes
    if family in ('juka_lord', 'hydra', 'energy_vortex', 'crane', 'deathwatch', 'tsuki_wolf', 'kappa', 'vampire_bat'):
        expected_body, classes = {
            'juka_lord': (766, ['JukaLord']),
            'hydra': (265, ['Abscess', 'Hydra']),
            'energy_vortex': (164, ['EnergyVortex']),
            'crane': (254, ['Crane']),
            'deathwatch': (242, ['DeathwatchBeetle', 'DeathwatchBeetleHatchling']),
            'tsuki_wolf': (250, ['TsukiWolf']),
            'kappa': (240, ['Kappa']),
            'vampire_bat': (317, ['VampireBat', 'VampireBatFamiliar']),
        }[family]
        path = ROOT / 'Viewer/local-art/creatures' / family / 'preparation.json'
        report = json.loads(path.read_text(encoding='utf-8'))
        row, = report['models']
        identity, = row['bodies']
        assert row['status'] == 'prepared' and identity['body'] == expected_body
        if family == 'tsuki_wolf':
            assert row['native_constructor_hue_ranges'] == {'TsukiWolf': [[0, 0], [1801, 1908]]}
        else:
            assert set(row['native_constructor_hues']) == set(classes)
        pins = {**row['art_dependency_sha256'],
                **{asset: row['asset_sha256'][name] for name, asset in row['assets'].items()}}
        if family in ('hydra', 'energy_vortex', 'crane', 'deathwatch', 'tsuki_wolf', 'kappa', 'vampire_bat'):
            for source in identity['native_sources']:
                assert sha(ROOT / 'Server/ModernUO' / source['path']) == source['sha256']
        if family in ('hydra', 'crane', 'deathwatch', 'tsuki_wolf', 'kappa', 'vampire_bat'):
            assert report['input_manifest_sha256'] == sha(ROOT / 'scripts' / (('vampire-bat' if family == 'vampire_bat' else family) + '-inputs.json'))
        else:
            pins[row['presentation_script']] = row['presentation_script_sha256']
        for asset, digest in pins.items():
            assert asset.startswith('res://')
            target = (ROOT / 'Viewer' / asset.removeprefix('res://')).resolve()
            assert target.is_relative_to(ROOT / 'Viewer') and sha(target) == digest
        return [row], {expected_body: classes}
    if family in ['mages','juka']:
        checker='check-source-mages.py' if family=='mages' else 'check-prepared-juka.py'
        subprocess.run([sys.executable,'-B',str(ROOT/'scripts'/checker)]+([] if family=='mages' else ['--graphics']),check=True)
        path=ROOT/f'Viewer/local-art/creatures/{family}/preparation.json'
        return json.loads(path.read_text(encoding='utf-8'))['models'],{}
    entries=[];reviewed={}
    for name in PREPARED_FORMS if family=='candidate_batch' else [family]:
        filename,checker,flag,classes=QUEEN_FORM if name=='solen_queens' else PREPARED_FORMS[name]
        subprocess.run([sys.executable,'-B',str(ROOT/'scripts'/checker),flag],check=True)
        path=ROOT/'Viewer/local-art/creatures'/name/filename
        report=json.loads(path.read_text(encoding='utf-8'))
        assert {int(b['body']) for row in report['models'] for b in row['bodies']}==set(classes),'Prepared native identities changed'
        for row in report['models']:
            script=row['presentation_script']
            assert row['status']=='prepared' and script=='res://Presentation/'+Path(script).name and script.endswith('.gd')
            if 'presentation_script_sha256' in row:
                assert row['presentation_script_sha256']==sha(ROOT/'Viewer'/script.removeprefix('res://'))
            entries.append(row)
        reviewed.update(classes)
    return entries,reviewed
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('family');parser.add_argument('--prepared',action='store_true');parser.add_argument('--runtime',type=Path,required=True);args=parser.parse_args()
    runtime=args.runtime.resolve();assert runtime.is_relative_to(ROOT/'work'),'Disposable runtime must stay under work/'
    index=json.loads((ROOT/'Viewer/local-art/creatures/accepted-index.json').read_text(encoding='utf-8'));rows=[]
    states={'validated'}
    prepared_classes={}
    selected_kinds=None
    coverage_classes = SOURCE_COVERAGE_CLASSES.get(args.family, {})
    if args.family=='recent_batch':
        for script in ['prepare-source-family-batch.py','prepare-source-reused-variants.py','prepare-shadow-wisp.py']:
            subprocess.run([sys.executable,'-B',str(ROOT/'scripts'/script),'--check-prepared'],check=True)
        selected_kinds=set()
        for relative in ['source_family_batch/preparation.json','source_reused_variants/preparation.json','shadow_wisps/preparation.json']:
            report=json.loads((ROOT/'Viewer/local-art/creatures'/relative).read_text())
            selected_kinds.update(row['kind'] for row in report['models'])
        older,older_classes=prepared_entries('candidate_batch')
        selected_kinds.update(row['kind'] for row in older)
        assert all(RECENT_CLASSES[body]==classes for body,classes in older_classes.items())
    if args.prepared:
        entries,prepared_classes=prepared_entries(args.family)
        index={'entries':entries}
        states={'prepared'}
    elif args.family == 'lizard_armed_active' or (args.family == 'lizard' and
            any(row['family'] == 'lizard_armed' and row['status'] == 'validated' for row in index['entries'])):
        gate = runpy.run_path(str(ROOT / 'scripts/accept-armed-lizardman.py'))
        packages, _ = gate['checked_rows'](index, True)
        selected_kinds = {row['kind'] for row in packages}
        prepared_classes = {35: ['Lizardman'], 36: ['Lizardman']}
    elif args.family in ('late_source_active', 'hydra_active', 'energy_vortex_active', 'champions_active', 'fey_champions_active', 'crane_active', 'deathwatch_active', 'tsuki_wolf_active', 'kappa_active', 'vampire_bat_active', 'yomotsu_active', 'occurrence_next_active', 'sand_vortex_active', 'bake_kitsune_active', 'horde_rune_active', 'devourer_lion_hiryu_active', 'elemental_minotaur_active', 'meer_donors_active', 'captain_cu_active', 'clockwork_tokuno_active', 'aos_creatures_active', 'aos_aliases_active', 'aos_mound_active', 'recovered_late_active', 'tormented_minotaur_active', 'harrower_active', 'late_donors_active', 'gargoyle_vendor_active', 'aos_armed_active', 'aos_abysmal_active', 'animated_weapon_active', 'slith_active', 'raptor_active', 'fetid_essence_active', 'corporeal_brume_active'):
        package_rows, prepared_classes = prepared_entries(args.family.removesuffix('_active'))
        selected_bodies = {body['body'] for row in package_rows for body in row['bodies']}
        registered = [row for row in index['entries'] if row['status'] == 'validated'
                      and any(body['body'] in selected_bodies for body in row['bodies'])]
        if args.family == 'devourer_lion_hiryu_active' and any(
                row['family'] == 'hiryu_mount' for row in registered):
            mounted, _ = prepared_entries('hiryu_mount')
            package_rows = [mounted[0] if row['bodies'][0]['body'] == 243 else row
                            for row in package_rows]
        if args.family == 'captain_cu_active' and any(row['family'] == 'cu_sidhe_mount' for row in registered):
            mounted = json.loads((ROOT / 'Viewer/local-art/creatures/cu_sidhe_mount/preparation.json').read_text())
            package_rows = [mounted['models'][0] if row['bodies'][0]['body'] == 277 else row
                            for row in package_rows]
        expected = [dict(row, status='validated') for row in package_rows]
        active_by_body = {int(row['bodies'][0]['body']): row for row in registered}
        for row in expected:
            body = int(row['bodies'][0]['body'])
            evidence = active_by_body.get(body, {}).get('legacy_slot11_evidence')
            if evidence is not None:
                aliases_path = ROOT / 'Viewer/Presentation/legacy-late-action-aliases.json'
                proof = json.loads(aliases_path.read_text(encoding='utf-8'))[str(body)]
                assert evidence == proof and proof['family'] == row['family'] and proof['kind'] == row['kind']
                row['legacy_slot11_evidence'] = proof
                row['classic_action_categories'] = row.get('classic_action_categories', {}) | {'11': 'Fidget'}
        action = {'late_donors_active': (831, 'parrot_flight'),
                  'champions_active': (172, 'late_classic_actions'),
                  'devourer_lion_hiryu_active': (303, 'late_classic_actions'),
                  'aos_armed_active': (311, 'late_classic_actions'),
                  'occurrence_next_active': (302, 'hopper_horde_actions'),
                  'horde_rune_active': (776, 'hopper_horde_actions'),
                  'vampire_bat_active': (317, 'vampire_bat_actions'),
                  'late_source_active': (267, 'troglodyte_reach')}.get(args.family)
        if action and active_by_body.get(action[0], {}).get('classic_gesture_native_sha256'):
            body, batch = action
            gesture_gate = runpy.run_path(str(ROOT / 'scripts/accept-classic-gestures.py'))
            _, updated = gesture_gate['checked'](index, True, batch)
            overlay, = (row for row in updated if row['bodies'][0]['body'] == body)
            expected = [overlay if row['bodies'][0]['body'] == body else row for row in expected]
        redirects = runpy.run_path(str(ROOT / 'scripts/prepare-creature-uop-redirects.py'))
        original_by_body = {body: redirects['without_active_redirect'](row) for body, row in active_by_body.items()}
        if len(registered) != len(expected) or original_by_body != {
                int(row['bodies'][0]['body']): row for row in expected}:
            raise ValueError('Normal registry does not match the checked recovered package')
        index['entries'] = registered
        selected_kinds = {row['kind'] for row in registered}
    public=ROOT/'Viewer/Art/Creatures/index.json'
    if public.exists() and not args.prepared:index['entries']=json.loads(public.read_text(encoding='utf-8'))['entries']+index['entries']
    # Match CreatureRegistry's validated, last-record-wins precedence. A local
    # revision of a public body must produce one native fixture, not twins.
    owners={int(body['body']):entry for entry in index['entries'] if entry.get('status') in states for body in entry['bodies']}
    for entry in index['entries']:
        if entry.get('status') not in states:continue
        if coverage_classes:
            if entry['family'] != 'source_preserving':continue
        elif selected_kinds is not None:
            if entry['kind'] not in selected_kinds:continue
        elif args.family not in ['all','candidate_batch'] and entry['family']!=args.family:
            if not (args.prepared and args.family == 'late_source'):continue
        for body in entry['bodies']:
            if owners[int(body['body'])] is not entry:continue
            native_body=int(body['body'])
            assert native_body==body['body'] and 0<=native_body<=0xffff,'Native body IDs must be exact unsigned integers'
            if coverage_classes and native_body not in coverage_classes:continue
            classes=set()
            for source in body['native_sources']:
                path=ROOT/'Server/ModernUO'/source['path'].replace('\\','/')
                text=path.read_text(encoding='utf-8-sig')
                classes.update(re.findall(r'\bpublic\s+(?:(?:abstract|sealed|partial)\s+)*class\s+(\w+)',text))
            classes=sorted(classes)
            reviewed=EXPLICIT_CLASSES.get(body['body']) if entry['family'] in ['deer','serpents','ice_serpents','small_snakes','rabbits','wisps','air','fire','walking','gorillas','headless','boglings','chickens','liches','snow_elementals','frogs','amorphous','solen_workers','fluid_elementals','silver_serpents','mages','juka'] else None
            if coverage_classes:reviewed=coverage_classes[native_body]
            elif prepared_classes:reviewed=prepared_classes.get(native_body,reviewed)
            elif args.family=='recent_batch':reviewed=RECENT_CLASSES.get(int(body['body']))
            if reviewed:
                assert set(reviewed)<=set(classes),'Reviewed native class declaration changed'
                classes=reviewed
            common={'body':native_body,'classes':classes,'kind':entry['kind'],'profile':body.get('native_profile') or entry['profile'],'movement_mode':entry.get('movement_mode',''),
                'native_gait_expectations':entry.get('native_gait_expectations',{}),'source_art_status':entry['status']}
            if args.prepared and prepared_classes:
                common['presentation']=entry
                common['constructor_hues']={name:(0x515 if name=='PestilentBandage' else 0x453 if name.startswith('BlackSolen') else 0) for name in classes}
            elif args.family=='recent_batch':
                common['constructor_hues']={name:(0x480 if name=='UnfrozenMummy' else 0x901 if name=='ShadowWispFamiliar' else 0x515 if name=='PestilentBandage' else 0x453 if name.startswith('BlackSolen') else 0) for name in classes}
            if 'native_constructor_hues' in entry:
                hues = entry['native_constructor_hues']
                assert set(hues) == set(classes), 'Constructor hue declarations must match the native classes'
                assert all(type(hue) is int and 0 <= hue <= 0xffff for hue in hues.values())
                common['constructor_hues'] = hues
            if 'native_constructor_hue_ranges' in entry:
                ranges = entry['native_constructor_hue_ranges']
                if native_body == 243:
                    assert set(ranges) == set(classes) == {'Hiryu', 'LesserHiryu'}
                    assert all(values and all(low == high and 0x8000 <= low <= 0xffff
                                              for low, high in values) for values in ranges.values())
                elif native_body == 277:
                    assert set(ranges) == set(classes) == {'CuSidhe'}
                    assert all(low == high and 0 <= low < 0x8000 for low, high in ranges['CuSidhe'])
                elif native_body == 758:
                    assert set(ranges) == set(classes) == {'Provisioner'}
                    assert len(ranges['Provisioner']) == 12
                    assert all(low == high and 0x8000 < low <= 0x8071 for low, high in ranges['Provisioner'])
                elif native_body == 21:
                    assert ranges == {'GiantSerpent': [[2001, 2018]]} and classes == ['GiantSerpent']
                elif native_body == 217:
                    assert ranges == {'Dog': [[2301, 2318]]} and classes == ['Dog']
                elif native_body == 211:
                    assert ranges == {'BlackBear': [[0, 0]]} and classes == ['BlackBear']
                elif native_body == 201:
                    assert ranges == {'Cat': [[2301, 2318]]} and classes == ['Cat']
                elif native_body == 150:
                    assert set(classes) == {'DeepSeaSerpent', 'SeaSerpent'}
                    assert ranges == {'DeepSeaSerpent': [[0x8A0, 0x8A4]], 'SeaSerpent': [[0x530, 0x538]]}
                elif native_body == 14:
                    assert ranges == {'EarthElemental': [[0, 0]], 'SummonedEarthElemental': [[0, 0]],
                                      'PlagueSpawn': [[0x11, 0x1f]]}
                else:
                    assert ranges == {'TsukiWolf': [[0, 0], [1801, 1908]]} and classes == ['TsukiWolf']
                common.pop('constructor_hues', None)
                common['constructor_hue_ranges'] = ranges
            if classes and (entry.get('movement_mode')=='native_waterline' or reviewed or 'native_constructor_hues' in entry):
                for name in classes:rows.append(dict(common,classes=[name],native_class=name))
            elif classes:rows.append(common)
    assert rows,'No checked native literal bodies in this family'
    if coverage_classes:
        expected = {(body, name) for body, names in coverage_classes.items() for name in names}
        assert len(rows) == len(expected) and {(row['body'], row['native_class']) for row in rows} == expected
    target=ROOT/'work/creatures';target.mkdir(parents=True,exist_ok=True)
    (target/'live-candidates.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
    (runtime/'Data/creature-fixtures.local.json').write_text(json.dumps([{'body':row['body'],'classes':row['classes']} for row in rows],indent=2),encoding='utf-8')
    print('CREATURE NATIVE FIXTURES:',len(rows),'body identities; native constructors and explicit native state APIs')
if __name__=='__main__':main()
