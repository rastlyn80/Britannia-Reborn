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
    assert family in ['mages','juka','candidate_batch','solen_queens',*PREPARED_FORMS],'Prepared native trial requires an explicit checked family'
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
    public=ROOT/'Viewer/Art/Creatures/index.json'
    if public.exists() and not args.prepared:index['entries']=json.loads(public.read_text(encoding='utf-8'))['entries']+index['entries']
    # Match CreatureRegistry's validated, last-record-wins precedence. A local
    # revision of a public body must produce one native fixture, not twins.
    owners={int(body['body']):entry for entry in index['entries'] if entry.get('status') in states for body in entry['bodies']}
    for entry in index['entries']:
        if entry.get('status') not in states:continue
        if selected_kinds is not None:
            if entry['kind'] not in selected_kinds:continue
        elif args.family not in ['all','candidate_batch'] and entry['family']!=args.family:continue
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
            if args.prepared:reviewed=prepared_classes.get(int(body['body']),reviewed)
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
            if not args.prepared and 'native_constructor_hues' in entry:
                hues = entry['native_constructor_hues']
                assert set(hues) == set(classes), 'Constructor hue declarations must match the native classes'
                assert all(type(hue) is int and 0 <= hue <= 0xffff for hue in hues.values())
                common['constructor_hues'] = hues
            if classes and (entry.get('movement_mode')=='native_waterline' or reviewed or 'native_constructor_hues' in entry):
                for name in classes:rows.append(dict(common,classes=[name],native_class=name))
            elif classes:rows.append(common)
    assert rows,'No checked native literal bodies in this family'
    target=ROOT/'work/creatures';target.mkdir(parents=True,exist_ok=True)
    (target/'live-candidates.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
    (runtime/'Data/creature-fixtures.local.json').write_text(json.dumps([{'body':row['body'],'classes':row['classes']} for row in rows],indent=2),encoding='utf-8')
    print('CREATURE NATIVE FIXTURES:',len(rows),'body identities; native constructors and explicit native state APIs')
if __name__=='__main__':main()
