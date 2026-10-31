"""Pin runtime body/item identities to the authoritative server source."""
import hashlib,json,re,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SERVER=ROOT/'Server/ModernUO'
DIRECTORY=SERVER/'Projects/UOContent/Mobiles/Animals/Mounts'
def main():
    revision=subprocess.check_output(['git','-C',str(SERVER),'rev-parse','HEAD'],text=True).strip()
    assert revision==json.loads((ROOT/'Server/dependencies.json').read_text())['modernuo']['revision']
    registry=(ROOT/'Viewer/Presentation/MountVisual.gd').read_text();sources={};rows=[]
    def source(name):
        path=DIRECTORY/name;raw=path.read_bytes();sources[str(path.relative_to(SERVER))]=hashlib.sha256(raw).hexdigest();return raw.decode('utf-8-sig')
    for name,body,item in [('DesertOstard.cs',0xd2,0x3ea3),('ForestOstard.cs',0xdb,0x3ea5),('FrenziedOstard.cs',0xda,0x3ea4),('Kirin.cs',0x84,0x3ead),('SkeletalMount.cs',0x319,0x3ebb),('HellSteed.cs',0x319,0x3ebb),('RidableLlama.cs',0xdc,0x3ea6)]:
        text=source(name)
        match=re.search(r':\s*base\(\s*(0x[\da-fA-F]+|\d+)\s*,\s*(0x[\da-fA-F]+|\d+)',text)
        assert match and tuple(int(x,0) for x in match.groups())==(body,item),name
        assert ('0x%x'%body) in registry and ('0x%x'%item) in registry
        rows.append({'class':name[:-3],'body':body,'mount_item':item})
        if name=='Kirin.cs':assert 'public override bool AllowFemaleRider => false;' in text
    pack=source('../Misc/PackLlama.cs');assert 'Body = 292;' in pack and 'class PackLlama : BaseCreature' in pack
    assert re.search(r'0x124:\["llama",0\]',registry)
    ethereal=source('Ethereals.cs')
    for cls,statue,item,proxy in [('EtherealOstard',0x2135,0x3eac,0xd2),('EtherealLlama',0x20f6,0x3eab,0xdc)]:
        match=re.search(r'class '+cls+r'\b.*?:\s*base\((0x[\da-fA-F]+),\s*(0x[\da-fA-F]+)\)',ethereal,re.S)
        assert match and tuple(int(x,0) for x in match.groups())==(statue,item)
        assert re.search(r'if item==0x%x:return 0x%x'%(item,proxy),registry)
        rows.append({'class':cls,'body':None,'renderer_proxy':proxy,'mount_item':item,'statuette':statue})
    assert 'public virtual int EtherealHue => 0x4001;' in ethereal
    output=ROOT/'outputs/ostard-riding';output.mkdir(parents=True,exist_ok=True)
    (output/'native-identities.json').write_text(json.dumps({'server_revision':revision,'source_sha256':sources,'rows':rows,'pack_llama_body':292,'pack_llama_rideable':False,'scope':'Exact native body/mount items and upstream restrictions. Artwork and live behaviour verified separately.'},indent=2))
    print('DISTINCT MOUNT NATIVE AUDIT:',len(rows),'class/item routes + unrideable pack llama')
if __name__=='__main__':main()
