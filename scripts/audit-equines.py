"""Read-only audit of client equine mappings against the pinned server source.

No proprietary client files are needed. Output is ignored local evidence.
This checks native IDs; it does not infer gameplay eligibility from mesh coverage.
"""
import hashlib, json, re, subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / 'Server/ModernUO'
MOUNTS = SERVER / 'Projects/UOContent/Mobiles/Animals/Mounts'
REGISTRY = ROOT / 'Viewer/Presentation/EquineRegistry.gd'

def number(text):
    return int(text, 16 if text.lower().startswith('0x') else 10)

def main():
    pins = json.loads((ROOT / 'Server/dependencies.json').read_text())
    revision = subprocess.check_output(['git', '-C', str(SERVER), 'rev-parse', 'HEAD'], text=True).strip()
    assert revision == pins['modernuo']['revision'], 'Unexpected authoritative server revision'
    registry = REGISTRY.read_text()
    routes = {number(body): {'body':number(body), 'name':name, 'style':style, 'mount_item':number(item)}
              for body,name,style,item in re.findall(r'^\s*(0x[\da-f]+):\["([^"]+)","([^"]+)",(0x[\da-f]+|0)\]', registry, re.M)}
    assert len(routes) == 15
    rows, sources = [], {}

    def source(relative):
        path = (MOUNTS / relative).resolve()
        sources[str(path.relative_to(SERVER)).replace('\\','/')] = hashlib.sha256(path.read_bytes()).hexdigest()
        return path.read_text()

    def accept(body, item, relative, kind='mobile'):
        assert routes[body]['mount_item'] == item, (body,item,routes.get(body))
        rows.append(dict(routes[body], source=str((MOUNTS/relative).resolve().relative_to(SERVER)).replace('\\','/'), kind=kind))

    horse = source('Horse.cs')
    native_horses = sorted({(number(a),number(b)) for a,b in re.findall(r'(0x[\dA-Fa-f]+),\s*(0x[\dA-Fa-f]+)', horse)})
    assert set(native_horses) == {(200,0x3e9f),(226,0x3ea0),(228,0x3ea1),(204,0x3ea2)}
    for body,item in native_horses:accept(body,item,'Horse.cs')
    for relative in ['SilverSteed.cs','FireSteed.cs','Unicorn.cs','War Horses/TBWarHorse.cs','War Horses/CoMWarHorse.cs','War Horses/MinaxWarHorse.cs','War Horses/SLWarHorse.cs']:
        text = source(relative)
        match = re.search(r':\s*base\(\s*(0x[\dA-Fa-f]+|\d+)\s*,\s*(0x[\dA-Fa-f]+|\d+)', text)
        assert match, relative
        accept(number(match[1]),number(match[2]),relative)
    nightmare = source('Nightmare.cs')
    native_nightmares = [(number(a),number(b)) for a,b in re.findall(r'Body\s*=\s*(\d+);\s*ItemID\s*=\s*(\d+)', nightmare)]
    assert set(native_nightmares) == {(116,0x3ea7),(178,0x3ea9),(179,0x3eb7)}
    for body,item in native_nightmares:accept(body,item,'Nightmare.cs')
    pack = source('../Misc/PackHorse.cs')
    assert re.search(r'class PackHorse\s*:\s*BaseCreature', pack) and re.search(r'Body\s*=\s*291;',pack)
    accept(291,0,'../Misc/PackHorse.cs','unrideable mobile')
    assert len(rows) == 15 and len({row['body'] for row in rows}) == 15
    ethereal = source('Ethereals.cs')
    ethereals = []
    for cls,statue,mount,proxy in [('EtherealHorse',0x20dd,0x3eaa,200),('EtherealUnicorn',0x25ce,0x3e9b,122)]:
        match = re.search(r'class '+cls+r'\b.*?:\s*base\((0x[\dA-Fa-f]+),\s*(0x[\dA-Fa-f]+)\)',ethereal,re.S)
        assert match and (number(match[1]),number(match[2])) == (statue,mount)
        assert re.search(r'0x%x:\[0x%x,' % (mount,proxy),registry)
        ethereals.append({'class':cls,'statuette_item':statue,'mount_item':mount,'renderer_body_proxy':proxy,'loose_mobile_body':None})
    assert 'public virtual int EtherealHue => 0x4001;' in ethereal
    assert 'public override bool AllowMaleRider => false;' in source('Unicorn.cs')
    # This audit covers only the original horse-rig subset. Distinct rigs and
    # compatibility identities have separate completion audits and runtime routes.
    for cls in ['Kirin.cs','SkeletalMount.cs','HellSteed.cs']:source(cls)
    output = ROOT/'outputs/equines';output.mkdir(parents=True,exist_ok=True)
    report = {'server_revision':revision,'source_sha256':sources,'registry_sha256':hashlib.sha256(REGISTRY.read_bytes()).hexdigest(),'mobile_routes':rows,'ethereal_item_routes':ethereals,'scope':'Original subset: 15 native horse-rig body identities and two item-only mount routes. completion-audit.json covers the full 26-ID presentation catalogue and third ethereal. Shared category artwork; exact native cuts/manes and choreography are separate.'}
    (output/'native-identities.json').write_text(json.dumps(report,indent=2))
    print('EQUINE NATIVE AUDIT: 15 body routes / 2 ethereal item routes, pinned source matches')

if __name__ == '__main__':main()
