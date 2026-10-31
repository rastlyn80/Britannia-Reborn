"""Private native-constructor/state allow-list from validated identities."""
import argparse,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('family');parser.add_argument('--runtime',type=Path,required=True);args=parser.parse_args()
    runtime=args.runtime.resolve();assert runtime.is_relative_to(ROOT/'work'),'Disposable runtime must stay under work/'
    index=json.loads((ROOT/'Viewer/local-art/creatures/accepted-index.json').read_text());rows=[]
    for entry in index['entries']:
        if args.family!='all' and entry['family']!=args.family:continue
        for body in entry['bodies']:
            classes=set()
            for source in body['native_sources']:
                path=ROOT/'Server/ModernUO'/source['path'].replace('\\','/')
                text=path.read_text(encoding='utf-8-sig')
                classes.update(re.findall(r'\bpublic\s+(?:(?:abstract|sealed|partial)\s+)*class\s+(\w+)',text))
            classes=sorted(classes)
            if classes:rows.append({'body':body['body'],'classes':classes,'kind':entry['kind'],'profile':body.get('native_profile') or entry['profile']})
    assert rows,'No validated native literal bodies in this family'
    target=ROOT/'work/creatures';target.mkdir(parents=True,exist_ok=True)
    (target/'live-candidates.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
    (runtime/'Data/creature-fixtures.local.json').write_text(json.dumps([{'body':row['body'],'classes':row['classes']} for row in rows],indent=2),encoding='utf-8')
    print('CREATURE NATIVE FIXTURES:',len(rows),'body identities; native constructors and explicit native state APIs')
if __name__=='__main__':main()
