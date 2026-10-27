"""Build local-only placement/label inputs from the pinned server and owned client data."""
import argparse, hashlib, json, re, struct
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
# The streamed Britain city region (704x512); PreviewWorld.cs enforces the same bound.
MAX_SIDE = 1024

def number(value):
    return int(value, 16) if value.lower().startswith('0x') else int(value)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--world', type=Path, default=ROOT/'Viewer/play-world.json')
    parser.add_argument('--data-dir', type=Path)
    parser.add_argument('--catalog-only', action='store_true')
    args = parser.parse_args()
    runtime = ROOT/'Server/runtime'
    folder = runtime/'Data/UltimaClonePreview'
    folder.mkdir(parents=True, exist_ok=True)
    if not args.catalog_only:
        world = json.loads(args.world.read_text(encoding='utf-8-sig'))
        bounds = dict(x=int(world['originX']), y=int(world['originY']), width=int(world['width']), height=int(world['height']))
        # A play-world crop names its facet; a prepared streaming index uses map id 1.
        trammel = world['facet'] == 1 if isinstance(world['facet'], int) else str(world['facet']).lower().startswith('trammel')
        if not trammel or not (0 < bounds['width'] <= MAX_SIDE and 0 < bounds['height'] <= MAX_SIDE):
            raise ValueError(f'Population requires a bounded Trammel region, at most {MAX_SIDE}x{MAX_SIDE}')
        contains = lambda x,y: bounds['x'] <= x < bounds['x']+bounds['width'] and bounds['y'] <= y < bounds['y']+bounds['height']
        placements, signs, sources = [], [], {}
        for facet in ['Britannia','Trammel']:
            for source in sorted((runtime/'Data/Decoration'/facet).glob('*.cfg')):
                header = None
                selected = []
                for line in source.read_text(encoding='utf-8-sig').splitlines():
                    text = line.strip()
                    if not text or text.startswith('#'): continue
                    match = re.match(r'^([A-Za-z][A-Za-z0-9_]*)\s+(0x[0-9A-Fa-f]+|[0-9]+)(?:\s.*)?$',text)
                    if match:
                        header, item_id = text, number(match[2])
                        continue
                    coordinate = re.match(r'^(-?\d+)\s+(-?\d+)\s+(-?\d+)(?:\s+(.*))?$', text)
                    if header and coordinate:
                        x,y,z = map(int,coordinate.group(1,2,3))
                        if contains(x,y):
                            selected.append(dict(header=header,id=item_id,x=x,y=y,z=z,extra=coordinate[4] or '',source=source.relative_to(runtime).as_posix()))
                if selected:
                    sources[source.relative_to(runtime).as_posix()] = hashlib.sha256(source.read_bytes()).hexdigest()
                    placements.extend(selected)
        source = runtime/'Data/signs.cfg'
        for line in source.read_text(encoding='utf-8-sig').splitlines():
            fields = line.split(maxsplit=5)
            if len(fields) != 6 or fields[0].startswith('#'): continue
            facet,item_id,x,y,z = map(number,fields[:5])
            if facet in [0,2] and contains(x,y): signs.append(dict(id=item_id,x=x,y=y,z=z,text=fields[5]))
        sources['Data/signs.cfg'] = hashlib.sha256(source.read_bytes()).hexdigest()
        (folder/'population.local.json').write_text(json.dumps(dict(schema=1,facet=1,bounds=bounds,placements=placements,signs=signs,sources=sources),indent=2),encoding='utf-8')
        print(f'LOCAL POPULATION PLAN: {len(placements)} decorations; {len(signs)} signs; source files unchanged')
    # Cliloc stays local and is only used to interpret native server labels/messages.
    data = args.data_dir
    if data is None:
        config = json.loads((runtime/'Configuration/modernuo.json').read_text(encoding='utf-8-sig'))
        data = next((Path(p) for p in config['dataDirectories'] if (Path(p)/'Cliloc.enu').exists()),None)
    if data and (data/'Cliloc.enu').exists():
        raw = (data/'Cliloc.enu').read_bytes(); offset = 6; labels = {}
        while offset < len(raw):
            if offset+7 > len(raw): raise ValueError('Truncated cliloc record')
            label,flag,size = struct.unpack_from('<iBH',raw,offset); offset += 7
            if offset+size > len(raw): raise ValueError('Truncated cliloc text')
            labels[str(label)] = raw[offset:offset+size].decode('utf-8'); offset += size
        (ROOT/'Viewer/cliloc.local.json').write_text(json.dumps(labels,ensure_ascii=False),encoding='utf-8')
        print(f'LOCAL LABELS: {len(labels)} client strings, excluded from Git')
    audit = folder/'audit.local.json'
    if audit.exists():
        content = json.loads(audit.read_text(encoding='utf-8'))
        (ROOT/'Viewer/item-definitions.local.json').write_text(json.dumps(content['definitions'],indent=2),encoding='utf-8')
        print(f"LOCAL ITEM DEFINITIONS: {len(content['definitions'])} server-derived ID mappings")
if __name__ == '__main__': main()
