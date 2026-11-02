"""Private native-constructor/state allow-list from validated identities."""
import argparse,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
# Reviewed native declarations, each verified by its real constructor.
EXPLICIT_CLASSES={124:['EvilMage'],125:['EvilMageLord'],126:['EvilMageLord'],92:['SilverSerpent'],158:['AcidElemental'],162:['PoisonElemental'],237:['Hind','EnragedHind'],234:['GreatHart','EnragedHart'],21:['GiantSerpent'],89:['IceSerpent'],52:['Snake','IceSnake','LavaSnake'],208:['Chicken'],205:['JackRabbit','Rabbit'],58:['Wisp','CrystalWisp'],13:['AirElemental','SummonedAirElemental','CrystalVortex'],15:['FireElemental','SummonedFireElemental'],153:['Ghoul','Bogle'],29:['Gorilla'],31:['HeadlessOne'],779:['Bogling'],24:['Lich'],78:['AncientLich','DarkGuardian'],79:['LichLord'],163:['SnowElemental'],80:['GiantToad'],81:['BullFrog'],51:['Slime','CorrosiveSlime','Jwilson'],775:['PlagueBeast','PlagueBeastLord'],781:['RedSolenWorker'],805:['BlackSolenWorker']}
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('family');parser.add_argument('--prepared',action='store_true');parser.add_argument('--runtime',type=Path,required=True);args=parser.parse_args()
    runtime=args.runtime.resolve();assert runtime.is_relative_to(ROOT/'work'),'Disposable runtime must stay under work/'
    index=json.loads((ROOT/'Viewer/local-art/creatures/accepted-index.json').read_text(encoding='utf-8'));rows=[]
    states={'validated'}
    if args.prepared:
        assert args.family=='mages','Prepared native trial is explicitly bounded to the independently checked mage forms'
        import subprocess,sys
        subprocess.run([sys.executable,'-B',str(ROOT/'scripts/check-source-mages.py')],check=True)
        index={'entries':json.loads((ROOT/'Viewer/local-art/creatures/mages/preparation.json').read_text(encoding='utf-8'))['models']}
        states={'prepared'}
    public=ROOT/'Viewer/Art/Creatures/index.json'
    if public.exists() and not args.prepared:index['entries']=json.loads(public.read_text(encoding='utf-8'))['entries']+index['entries']
    # Match CreatureRegistry's validated, last-record-wins precedence. A local
    # revision of a public body must produce one native fixture, not twins.
    owners={int(body['body']):entry for entry in index['entries'] if entry.get('status') in states for body in entry['bodies']}
    for entry in index['entries']:
        if entry.get('status') not in states:continue
        if args.family!='all' and entry['family']!=args.family:continue
        for body in entry['bodies']:
            if owners[int(body['body'])] is not entry:continue
            classes=set()
            for source in body['native_sources']:
                path=ROOT/'Server/ModernUO'/source['path'].replace('\\','/')
                text=path.read_text(encoding='utf-8-sig')
                classes.update(re.findall(r'\bpublic\s+(?:(?:abstract|sealed|partial)\s+)*class\s+(\w+)',text))
            classes=sorted(classes)
            reviewed=EXPLICIT_CLASSES.get(body['body']) if entry['family'] in ['deer','serpents','ice_serpents','small_snakes','rabbits','wisps','air','fire','walking','gorillas','headless','boglings','chickens','liches','snow_elementals','frogs','amorphous','solen_workers','fluid_elementals','silver_serpents','mages'] else None
            if reviewed:
                assert set(reviewed)<=set(classes),'Reviewed native class declaration changed'
                classes=reviewed
            common={'body':body['body'],'classes':classes,'kind':entry['kind'],'profile':body.get('native_profile') or entry['profile'],'movement_mode':entry.get('movement_mode',''),
                'native_gait_expectations':entry.get('native_gait_expectations',{}),'source_art_status':entry['status']}
            if classes and (entry.get('movement_mode')=='native_waterline' or reviewed):
                for name in classes:rows.append(dict(common,classes=[name],native_class=name))
            elif classes:rows.append(common)
    assert rows,'No validated native literal bodies in this family'
    target=ROOT/'work/creatures';target.mkdir(parents=True,exist_ok=True)
    (target/'live-candidates.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
    (runtime/'Data/creature-fixtures.local.json').write_text(json.dumps([{'body':row['body'],'classes':row['classes']} for row in rows],indent=2),encoding='utf-8')
    print('CREATURE NATIVE FIXTURES:',len(rows),'body identities; native constructors and explicit native state APIs')
if __name__=='__main__':main()
