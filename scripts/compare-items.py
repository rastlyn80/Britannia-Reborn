"""Side-by-side review sheets: original item art next to this client's render.

Local reference only (original art). Reads outputs/item-catalog (from
scripts/build-item-catalog.ps1), renders the chosen graphics with
Viewer/Presentation/ItemCompare.gd and writes contact sheets to
outputs/item-catalog/compare/.

usage: python compare-items.py [--status original,guess] [--top 96] [--skip 0]
       [--ids 1,2,3] [--families key1,key2] [--label NAME]
Requires Pillow.
"""
import argparse
import glob
import json
import os
import subprocess

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'outputs', 'item-catalog')


def load(name, prefix):
    with open(os.path.join(OUT, name), encoding='utf-8') as handle:
        return json.loads(handle.read()[len(prefix):].rstrip().rstrip(';'))


def lead(family, items):
    return max(family['ids'], key=lambda i: (items[i]['world'], -i))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--status', default='original,guess')
    parser.add_argument('--top', type=int, default=96)
    parser.add_argument('--skip', type=int, default=0)
    parser.add_argument('--ids', default='')
    parser.add_argument('--families', default='')
    parser.add_argument('--label', default='review')
    parser.add_argument('--detail', default='', help='only looks whose detail contains this text')
    args = parser.parse_args()
    catalog = load('catalog.js', 'window.CATALOG=')
    looks = load('current.js', 'window.CURRENT=')['looks']
    items = {i['id']: i for i in catalog['items']}
    wanted = set(args.status.split(','))
    if args.ids:
        chosen = [int(i) for i in args.ids.split(',')]
    else:
        families = catalog['families']
        if args.families:
            keys = args.families.split(',')
            families = [f for f in families if f['key'] in keys]
        else:
            families = [f for f in families if f['world'] > 0 and looks[str(lead(f, items))]['status'] in wanted
                        and args.detail in looks[str(lead(f, items))]['detail']]
        chosen = [lead(f, items) for f in families[args.skip:args.skip + args.top]]
    renders = os.path.join(OUT, 'compare', 'renders')
    os.makedirs(renders, exist_ok=True)
    godot = glob.glob(os.path.join(ROOT, '.tools', 'godot', '*console.exe'))[0]
    env = dict(os.environ, APPDATA=os.path.join(ROOT, '.godot-user'), LOCALAPPDATA=os.path.join(ROOT, '.godot-user'))
    subprocess.run([godot, '--path', os.path.join(ROOT, 'Viewer'), '--script', 'res://Presentation/ItemCompare.gd', '--',
                    '--catalog=' + os.path.join(OUT, 'catalog.js'), '--out=' + renders, '--ids=' + ','.join(map(str, chosen))],
                   env=env, check=True, stdout=subprocess.DEVNULL)
    cell, columns = (300, 190), 4
    font = ImageFont.load_default()
    pages = [chosen[i:i + 24] for i in range(0, len(chosen), 24)]
    for number, page in enumerate(pages):
        rows = (len(page) + columns - 1) // columns
        sheet = Image.new('RGB', (cell[0] * columns, cell[1] * rows), (24, 21, 17))
        draw = ImageDraw.Draw(sheet)
        for n, item_id in enumerate(page):
            x, y = (n % columns) * cell[0], (n // columns) * cell[1]
            original = Image.open(os.path.join(OUT, 'art', f'{item_id}.png')).convert('RGBA')
            scale = max(1, min(3, 140 // max(original.size)))
            original = original.resize((original.width * scale, original.height * scale), Image.NEAREST)
            original.thumbnail((140, 150), Image.NEAREST)
            sheet.paste(original, (x + 5 + (140 - original.width) // 2, y + 5 + (150 - original.height)), original)
            path = os.path.join(renders, f'{item_id}.png')
            if os.path.exists(path):
                render = Image.open(path).convert('RGB').resize((150, 150))
                sheet.paste(render, (x + 147, y + 5))
            item, look = items[item_id], looks[str(item_id)]
            draw.text((x + 5, y + 158), f"{item_id} {item['name']}"[:46], fill=(236, 226, 204), font=font)
            draw.text((x + 5, y + 172), f"{item['world']:,} placed · {look['status']}: {look['detail']}"[:50], fill=(168, 151, 122), font=font)
        target = os.path.join(OUT, 'compare', f"{args.label}-{number + 1:02d}.png")
        sheet.save(target)
        print(target)


if __name__ == '__main__':
    main()
