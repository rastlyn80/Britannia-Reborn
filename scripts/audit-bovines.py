"""Read-only native bovine body and interaction audit against the server pin."""
import hashlib,json,re,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SERVER=ROOT/'Server/ModernUO'
def main():
    revision=subprocess.check_output(['git','-C',str(SERVER),'rev-parse','HEAD'],text=True).strip()
    assert revision==json.loads((ROOT/'Server/dependencies.json').read_text())['modernuo']['revision']
    registry=(ROOT/'Viewer/Presentation/AnimalVisual.gd').read_text();sources={};rows=[]
    for cls,ids in [('Cow',[0xd8,0xe7]),('Bull',[0xe8,0xe9])]:
        path=SERVER/f'Projects/UOContent/Mobiles/Animals/Cows/{cls}.cs';raw=path.read_bytes();text=raw.decode('utf-8-sig')
        assert re.search(r'class '+cls+r'\s*:\s*BaseCreature',text)
        match=re.search(r'Body = Utility.RandomList\((0x[\dA-Fa-f]+), (0x[\dA-Fa-f]+)\);',text)
        assert match and [int(v,0) for v in match.groups()]==ids
        for body in ids:
            assert '0x%x:'%body in registry
            rows.append({'class':cls,'body':body,'mount_item':None,'ridable':False})
        sources[str(path.relative_to(SERVER))]=hashlib.sha256(raw).hexdigest()
        if cls=='Cow':
            assert 'Animate(8, 0, 3, true, false, 0);' in text
            assert 'Milk = 4;' in text
    output=ROOT/'outputs/bovines';output.mkdir(exist_ok=True)
    (output/'native-identities.json').write_text(json.dumps({'server_revision':revision,'source_sha256':sources,'rows':rows,'scope':'Four exact native loose body IDs, no mounted mapping; native Cow.Tip signature and four-serving stock identified. Actual appearance, owning-player serving/exhaustion tests and gameplay eligibility are separate.'},indent=2),encoding='utf-8')
    print('BOVINE AUDIT: four native bodies; unrideable classes; Cow.Tip signature and native serving count identified')
if __name__=='__main__':main()
