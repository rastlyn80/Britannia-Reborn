"""Private native-constructor/state allow-list from validated identities."""
import argparse,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
# Reviewed shared-file declarations, each also verified by its real constructor.
EXPLICIT_CLASSES={237:['Hind','EnragedHind'],234:['GreatHart','EnragedHart']}
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('family');parser.add_argument('--runtime',type=Path,required=True);args=parser.parse_args()
    runtime=args.runtime.resolve();assert runtime.is_relative_to(ROOT/'work'),'Disposable runtime must stay under work/'
    index=json.loads((ROOT/'Viewer/local-art/creatures/accepted-index.json').read_text(encoding='utf-8'));rows=[]
    public=ROOT/'Viewer/Art/Creatures/index.json'
    if public.exists():index['entries']=json.loads(public.read_text(encoding='utf-8'))['entries']+index['entries']
    # Match CreatureRegistry's validated, last-record-wins precedence. A local
    # revision of a public body must produce one native fixture, not twins.
    owners={int(body['body']):entry for entry in index['entries'] if entry.get('status')=='validated' for body in entry['bodies']}
    for entry in index['entries']:
        if entry.get('status')!='validated':continue
        if args.family!='all' and entry['family']!=args.family:continue
        for body in entry['bodies']:
            if owners[int(body['body'])] is not entry:continue
            classes=set()
            for source in body['native_sources']:
                path=ROOT/'Server/ModernUO'/source['path'].replace('\\','/')
                text=path.read_text(encoding='utf-8-sig')
                classes.update(re.findall(r'\bpublic\s+(?:(?:abstract|sealed|partial)\s+)*class\s+(\w+)',text))
            classes=sorted(classes)
            reviewed=EXPLICIT_CLASSES.get(body['body']) if entry['family']=='deer' else None
            if reviewed:
                assert set(reviewed)<=set(classes),'Reviewed native class declaration changed'
                classes=reviewed
            common={'body':body['body'],'classes':classes,'kind':entry['kind'],'profile':body.get('native_profile') or entry['profile'],'movement_mode':entry.get('movement_mode',''),
                'native_gait_expectations':entry.get('native_gait_expectations',{})}
            if classes and (entry.get('movement_mode')=='native_waterline' or reviewed):
                for name in classes:rows.append(dict(common,classes=[name],native_class=name))
            elif classes:rows.append(common)
    assert rows,'No validated native literal bodies in this family'
    target=ROOT/'work/creatures';target.mkdir(parents=True,exist_ok=True)
    (target/'live-candidates.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
    (runtime/'Data/creature-fixtures.local.json').write_text(json.dumps([{'body':row['body'],'classes':row['classes']} for row in rows],indent=2),encoding='utf-8')
    print('CREATURE NATIVE FIXTURES:',len(rows),'body identities; native constructors and explicit native state APIs')
if __name__=='__main__':main()
