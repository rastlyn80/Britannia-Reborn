"""Bulk candidate search for open item families (art coverage worklist).

Reads outputs/item-catalog/open-work.json (written by scripts/build-item-catalog.ps1),
searches Sketchfab for each open family name, keeps downloadable CC0 / CC-BY 4.0
models that exist in the public Objaverse 1.0 mirror (so scripts/add-objaverse.py
can pin them with verified provenance) and are light enough to reduce, and
writes review sheets: the original art beside each candidate's thumbnail, with a
letter per candidate. Nothing is downloaded except thumbnails; approved letters
go to scripts/pin-picks.py.

usage: python source-candidates.py --label NAME [--top 48] [--skip 0]
         [--category "nature"] [--match REGEX] [--exclude REGEX] [--per 5]
Outputs (ignored, local): outputs/sourcing/NAME/candidates.json, sheet-NN.png
"""
import argparse
import gzip
import io
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = os.path.join(ROOT, 'outputs', 'item-catalog')
INDEX = os.path.join(os.environ.get('TEMP', '/tmp'), 'objv', 'object-paths.json.gz')
INDEX_URL = 'https://huggingface.co/datasets/allenai/objaverse/resolve/main/object-paths.json.gz'
AGENT = {'User-Agent': 'BritanniaReborn-asset-sourcing/0.1'}
LICENCES = {'CC0 Public Domain': 'CC0', 'CC Attribution': 'CC-BY'}
# Families drawn by the code builders (walls, floors, roofs, ground) rather than models.
CONSTRUCTION = r'wall|window|floor|roof|stair|step|arch|pillar|column|doorway|unnamed|nodraw|no draw|^dirt|^grass|^sand|^water|^lava|cave|edging|wasteland|breakbrick|serpentdesign|ruin|parapet|battlement|crenel|rope|blood'
DIRECTIONS = r'\b(east|west|north|south|ne|nw|se|sw|n|s|e|w|corner|left|right|top|bottom|middle|end|center|centre|part|piece)\b'


def fetch(url, timeout=60):
    with urllib.request.urlopen(urllib.request.Request(url, headers=AGENT), timeout=timeout) as response:
        return response.read()


def objaverse_index():
    if not os.path.exists(INDEX):
        os.makedirs(os.path.dirname(INDEX), exist_ok=True)
        with open(INDEX, 'wb') as handle:
            handle.write(fetch(INDEX_URL, 600))
    paths = json.load(gzip.open(INDEX))
    return paths


def query_for(name):
    text = re.sub(r'%[^%]*%', '', name.lower())
    text = re.sub(DIRECTIONS, ' ', text)
    text = re.sub(r'[^a-z ]', ' ', text)
    return ' '.join(text.split())


def search(query):
    url = 'https://api.sketchfab.com/v3/search?' + urllib.parse.urlencode(
        {'type': 'models', 'q': query, 'downloadable': 'true', 'count': 24, 'sort_by': '-likeCount'})
    for attempt in range(4):
        try:
            return json.loads(fetch(url)).get('results', [])
        except Exception as error:  # rate limit or transient failure
            time.sleep(5 * (attempt + 1))
            last = error
    print('search failed', query, last, file=sys.stderr)
    return []


def candidates_for(query, index, per, max_mb, max_faces):
    found, seen = [], set()
    stems = [word.rstrip('s') for word in query.split() if len(word) > 2]
    for text in (query, query + ' medieval'):
        for result in search(text):
            uid = result['uid']
            if uid in seen:
                continue
            seen.add(uid)
            # Relevance: a query word (singular) must name the model, as a whole word.
            words = set(re.findall(r'[a-z]+', (result['name'] + ' ' + ' '.join(t['name'] for t in result.get('tags', []))).lower()))
            if stems and not any(stem in words or stem + 's' in words or stem + 'es' in words for stem in stems):
                continue
            licence = LICENCES.get((result.get('license') or {}).get('label', ''))
            glb = (result.get('archives') or {}).get('glb') or {}
            if not licence or uid not in index:
                continue
            if (glb.get('size') or 0) > max_mb * 1e6 or (result.get('faceCount') or 0) > max_faces:
                continue
            images = sorted(result['thumbnails']['images'], key=lambda i: abs(i['width'] - 256))
            found.append({'uid': uid, 'path': index[uid].removeprefix('glbs/'), 'title': result['name'],
                          'author': (result.get('user') or {}).get('displayName', ''), 'licence': licence,
                          'faces': result.get('faceCount'), 'mb': round((glb.get('size') or 0) / 1e6, 1),
                          'likes': result.get('likeCount'), 'thumb': images[0]['url']})
            if len(found) >= per:
                return found
        time.sleep(1)
    return found


def font(size):
    for name in ('segoeui.ttf', 'arial.ttf', 'DejaVuSans.ttf'):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def sheet(rows, per, path):
    cell_w, cell_h, art_w, head = 240, 150, 170, 22
    image = Image.new('RGB', (art_w + per * cell_w, len(rows) * (cell_h + head + 24)), (30, 26, 21))
    draw, small, big = ImageDraw.Draw(image), font(13), font(16)
    for r, row in enumerate(rows):
        y = r * (cell_h + head + 24)
        draw.text((6, y + 2), '%s  [%s]  %s placements, %d graphics' % (row['name'], row['key'], f"{row['placements']:,}", len(row['ids'])), fill=(236, 226, 204), font=big)
        art = os.path.join(CATALOG, 'art', '%d.png' % row['ids'][0])
        if os.path.exists(art):
            original = Image.open(art).convert('RGBA')
            scale = max(1, min(4, int(min((art_w - 10) / original.width, cell_h / original.height))))
            original = original.resize((original.width * scale, original.height * scale), Image.NEAREST)
            original.thumbnail((art_w - 10, cell_h))
            image.paste(original, (5, y + head + cell_h - original.height), original)
        for c, candidate in enumerate(row['candidates']):
            x = art_w + c * cell_w
            try:
                thumb = Image.open(io.BytesIO(fetch(candidate['thumb']))).convert('RGB')
                thumb.thumbnail((cell_w - 8, cell_h))
                image.paste(thumb, (x + 4, y + head))
            except Exception:
                draw.text((x + 10, y + head + 60), 'no thumbnail', fill=(200, 90, 90), font=small)
            draw.text((x + 6, y + head + 2), chr(65 + c), fill=(255, 200, 60), font=big)
            caption = '%s %s %sk tris %sMB' % (candidate['licence'], candidate['title'][:18], round((candidate['faces'] or 0) / 1000), candidate['mb'])
            draw.text((x + 4, y + head + cell_h + 3), caption, fill=(168, 151, 122), font=small)
    image.save(path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--label', required=True)
    parser.add_argument('--top', type=int, default=48)
    parser.add_argument('--skip', type=int, default=0)
    parser.add_argument('--per', type=int, default=5)
    parser.add_argument('--category', default='')
    parser.add_argument('--match', default='')
    parser.add_argument('--exclude', default=CONSTRUCTION)
    parser.add_argument('--max-mb', type=float, default=80)
    parser.add_argument('--max-faces', type=int, default=400000)
    args = parser.parse_args()
    families = json.load(open(os.path.join(CATALOG, 'open-work.json'), encoding='utf-8'))['families']
    pinned = json.load(open(os.path.join(ROOT, 'Viewer', 'Presentation', 'prop-replacements.json'), encoding='utf-8'))['items']
    chosen, seen_names = [], set()
    for family in families:
        name = query_for(family['name'])
        if not name or name in seen_names or family['name'].lower() in pinned:
            continue
        if args.category and family['category'] != args.category:
            continue
        if args.match and not re.search(args.match, family['name'].lower()):
            continue
        if args.exclude and re.search(args.exclude, family['name'].lower()):
            continue
        seen_names.add(name)
        chosen.append(family)
    chosen = chosen[args.skip:args.skip + args.top]
    index = objaverse_index()
    out = os.path.join(ROOT, 'outputs', 'sourcing', args.label)
    os.makedirs(out, exist_ok=True)
    rows = []
    for family in chosen:
        row = dict(family, query=query_for(family['name']))
        row['candidates'] = candidates_for(row['query'], index, args.per, args.max_mb, args.max_faces)
        rows.append(row)
        print('%-28s %2d candidates' % (row['query'], len(row['candidates'])))
    with open(os.path.join(out, 'candidates.json'), 'w', encoding='utf-8') as handle:
        json.dump(rows, handle, indent=1)
    for n in range(0, len(rows), 6):
        sheet(rows[n:n + 6], args.per, os.path.join(out, 'sheet-%02d.png' % (n // 6 + 1)))
    print('wrote', out)


if __name__ == '__main__':
    main()
