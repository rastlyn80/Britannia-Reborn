"""Read-only catalogue closure: native equines versus client-only artwork.

No client data or extracted frames are written into tracked files. Evidence is
local, hash-pinned and deliberately does not promote DEF fallbacks to species.
"""
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / 'Server/ModernUO'
CONTENT = SERVER / 'Projects/UOContent'


def main():
    revision = subprocess.check_output(['git', '-C', str(SERVER), 'rev-parse', 'HEAD'], text=True).strip()
    assert revision == json.loads((ROOT/'Server/dependencies.json').read_text())['modernuo']['revision']
    data = Path(json.loads((ROOT/'Server/runtime/Configuration/modernuo.json').read_text())['dataDirectories'][0])
    inputs = json.loads((ROOT/'scripts/equine-compatibility-inputs.json').read_text())
    texts = {}
    for name, digest in inputs['sha256'].items():
        raw = (data/name).read_bytes()
        assert hashlib.sha256(raw).hexdigest() == digest, f'Client reference changed: {name}; re-audit before updating pins'
        texts[name] = raw.decode('utf-8-sig', errors='replace')
    registry = (ROOT/'Viewer/Presentation/EquineRegistry.gd').read_text()
    section = registry.split('const COMPATIBILITY := {')[1].split('\n}')[0]
    routes = {int(body,16): (int(fallback,0),int(hue,0)) for body,fallback,hue in re.findall(
        r'(0x[\da-f]+):\["[^"]+","[^"]+",0,(0x[\da-f]+|0),(0x[\da-f]+|\d+)\]', section)}
    assert len(routes) == 9
    definitions = {}
    for body,group,hue in re.findall(r'^\s*(\d+)\s+\{([^}]+)\}\s+(\d+)',texts['body.def'],re.M):
        candidates = [int(n.strip()) for n in group.split(',')]
        definitions[int(body)] = (candidates[2] if len(candidates)>=3 else candidates[0],int(hue))
    sources = {}; rows = []
    # Structural body assignments/constructor pairs, not arbitrary matching
    # numbers (sound IDs, damage, colours and clilocs use the same integers).
    content_bodies = set()
    for path in CONTENT.rglob('*.cs'):
        text = path.read_text(encoding='utf-8-sig',errors='replace')
        for value in re.findall(r'\bBody\s*(?:=|=>)\s*(0x[\dA-Fa-f]+|\d+)\s*;',text):
            content_bodies.add(int(value,0))
        for value in re.findall(r':\s*base\(\s*(0x[\dA-Fa-f]+|\d+)\s*,\s*0x3[Ee][\dA-Fa-f]{2}\b',text):
            content_bodies.add(int(value,0))
    labels = {0x11c:'Mondains Steed',0x57f:'Horse_Unicorn_RB',0x580:'Horse_Palomino'}
    for body,(fallback,hue) in routes.items():
        assert body not in content_bodies, f'Client-only status needs reconsidering: {body:#x}'
        if fallback:
            assert definitions[body] == (fallback,hue), f'DEF mismatch: {body:#x}'
            evidence = 'explicit Body.def horse fallback; source may have its own animation'
        else:
            assert labels[body] in texts['mobtypes.txt']
            assert re.search(r'^\s*'+str(body)+r'\s+ANIMAL\b',texts['mobtypes.txt'],re.M)
            assert re.search(r'^\s*'+str(body)+r'\s+',texts['bodyconv.def'],re.M)
            evidence = 'named ANIMAL row and Bodyconv target; modern category interpretation'
        rows.append({'body':body,'body_hex':hex(body),'status':'client-only compatibility artwork',
                     'fallback_body':fallback or None,'artwork_default_hue':hue,'mount_item':None,
                     'native_class_found':False,'evidence':evidence})
    # Broader native class census includes ethics/faction modules and derived
    # boss/mare classes, which share existing wire appearances.
    native = [
        ('Engines/Ethics/Hero/Mobiles/HolySteed.cs',0x75,0x3ea8,'Ethic.Hero'),
        ('Engines/Ethics/Evil/Mobiles/UnholySteed.cs',0x74,0x3ea7,'Ethic.Evil'),
        ('Engines/Factions/Mobiles/FactionWarHorse.cs',0xe2,0x3ea0,'pl.Rank.Rank < 2'),
    ]
    for name,body,item,restriction in native:
        raw=(CONTENT/name).read_bytes();text=raw.decode('utf-8-sig')
        assert re.search(r'base\(0x%X, 0x%X\b'%(body,item),text)
        assert restriction in text
        sources[name]=hashlib.sha256(raw).hexdigest()
    for name,parent in [
        ('Mobiles/Animals/Mounts/GrizzledMare.cs','HellSteed'),
        ('Mobiles/Monsters/ML/Bedlam/RedDeath.cs','SkeletalMount')]:
        raw=(CONTENT/name).read_bytes();assert re.search(r'class \w+\s*:\s*'+parent,raw.decode('utf-8-sig'))
        sources[name]=hashlib.sha256(raw).hexdigest()
    ethereal=(CONTENT/'Mobiles/Animals/Mounts/Ethereals.cs').read_text()
    match=re.search(r'class EtherealKirin\b.*?:\s*base\((0x[\dA-Fa-f]+),\s*(0x[\dA-Fa-f]+)\)',ethereal,re.S)
    assert match and tuple(int(x,0) for x in match.groups())==(0x25a0,0x3e9c)
    # Unlike living Kirin, this Item subclass inherits EtherealMount and has
    # no female-rider restriction. Both sexes require actual live evidence.
    block=ethereal.split('class EtherealKirin')[1].split('[SerializationGenerator')[0]
    assert 'AllowFemaleRider' not in block
    report={'server_revision':revision,'client_reference_sha256':inputs['sha256'],
            'compatibility_routes':rows,'extra_native_source_sha256':sources,
            'indexed_body_routes':26,'native_body_routes':17,'compatibility_body_routes':9,
            'ethereal_equine_items':[0x3eaa,0x3e9b,0x3e9c],
            'scope':'26 indexed body presentations = 17 native identities + 9 explicit compatibility categories. Three additional item-only ethereal equines. No invented mount items or claim that fallback bodies are active server species. SeaHorse (0x90/0x3EB3) is an aquatic creature outside the terrestrial equine catalogue; other mount families remain separate.'}
    output=ROOT/'outputs/equines';output.mkdir(parents=True,exist_ok=True)
    (output/'completion-audit.json').write_text(json.dumps(report,indent=2))
    print('EQUINE COMPLETION AUDIT: 17 native + 9 compatibility body identities / 3 item-only ethereals')


if __name__ == '__main__':main()
