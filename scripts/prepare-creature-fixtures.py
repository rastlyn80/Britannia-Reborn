"""Private native-constructor/state allow-list from checked identities."""
import argparse,hashlib,json,re,subprocess,sys
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

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def prepared_entries(family):
    assert family in ['mages','juka','juka_lord','hydra','energy_vortex','late_source','champions','fey_champions','crane','deathwatch','tsuki_wolf','kappa','vampire_bat','yomotsu','occurrence_next','horde_rune','sand_vortex','bake_kitsune','devourer_lion_hiryu','hiryu_mount','elemental_minotaur','meer_donors','captain_cu','clockwork_tokuno','aos_creatures','aos_aliases','aos_mound','recovered_late','tormented_minotaur','harrower','late_donors','gargoyle_vendor','aos_armed','aos_abysmal','candidate_batch','solen_queens',*PREPARED_FORMS],'Prepared native trial requires an explicit checked family'
    if family in ('late_source', 'champions', 'fey_champions', 'yomotsu', 'occurrence_next', 'horde_rune', 'sand_vortex', 'bake_kitsune', 'devourer_lion_hiryu', 'hiryu_mount', 'elemental_minotaur', 'meer_donors', 'captain_cu', 'clockwork_tokuno', 'aos_creatures', 'aos_aliases', 'aos_mound', 'recovered_late', 'tormented_minotaur', 'harrower', 'late_donors', 'gargoyle_vendor', 'aos_armed', 'aos_abysmal'):
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
    elif args.family in ('late_source_active', 'hydra_active', 'energy_vortex_active', 'champions_active', 'fey_champions_active', 'crane_active', 'deathwatch_active', 'tsuki_wolf_active', 'kappa_active', 'vampire_bat_active', 'yomotsu_active', 'occurrence_next_active', 'sand_vortex_active', 'bake_kitsune_active', 'horde_rune_active', 'devourer_lion_hiryu_active', 'elemental_minotaur_active', 'meer_donors_active', 'captain_cu_active', 'clockwork_tokuno_active', 'aos_creatures_active', 'aos_aliases_active', 'aos_mound_active', 'recovered_late_active', 'tormented_minotaur_active', 'harrower_active', 'late_donors_active', 'gargoyle_vendor_active', 'aos_armed_active', 'aos_abysmal_active'):
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
        if registered != [dict(row, status='validated') for row in package_rows]:
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
        if selected_kinds is not None:
            if entry['kind'] not in selected_kinds:continue
        elif args.family not in ['all','candidate_batch'] and entry['family']!=args.family:
            if not (args.prepared and args.family == 'late_source'):continue
        for body in entry['bodies']:
            if owners[int(body['body'])] is not entry:continue
            native_body=int(body['body'])
            assert native_body==body['body'] and 0<=native_body<=0xffff,'Native body IDs must be exact unsigned integers'
            classes=set()
            for source in body['native_sources']:
                path=ROOT/'Server/ModernUO'/source['path'].replace('\\','/')
                text=path.read_text(encoding='utf-8-sig')
                classes.update(re.findall(r'\bpublic\s+(?:(?:abstract|sealed|partial)\s+)*class\s+(\w+)',text))
            classes=sorted(classes)
            reviewed=EXPLICIT_CLASSES.get(body['body']) if entry['family'] in ['deer','serpents','ice_serpents','small_snakes','rabbits','wisps','air','fire','walking','gorillas','headless','boglings','chickens','liches','snow_elementals','frogs','amorphous','solen_workers','fluid_elementals','silver_serpents','mages','juka'] else None
            if prepared_classes:reviewed=prepared_classes.get(native_body,reviewed)
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
                else:
                    assert ranges == {'TsukiWolf': [[0, 0], [1801, 1908]]} and classes == ['TsukiWolf']
                common.pop('constructor_hues', None)
                common['constructor_hue_ranges'] = ranges
            if classes and (entry.get('movement_mode')=='native_waterline' or reviewed or 'native_constructor_hues' in entry):
                for name in classes:rows.append(dict(common,classes=[name],native_class=name))
            elif classes:rows.append(common)
    assert rows,'No checked native literal bodies in this family'
    target=ROOT/'work/creatures';target.mkdir(parents=True,exist_ok=True)
    (target/'live-candidates.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
    (runtime/'Data/creature-fixtures.local.json').write_text(json.dumps([{'body':row['body'],'classes':row['classes']} for row in rows],indent=2),encoding='utf-8')
    print('CREATURE NATIVE FIXTURES:',len(rows),'body identities; native constructors and explicit native state APIs')
if __name__=='__main__':main()
