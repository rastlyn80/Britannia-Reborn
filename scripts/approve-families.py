"""Record catalogue families whose current 3D look passed side-by-side review.

Writes graphic IDs (no artwork or names) to Viewer/Presentation/reviewed-families.json;
Presentation/ArtProvenance.gd then reports them by their real status instead of
"untested guess". Family keys come from the local catalogue (build-item-catalog.ps1).

usage: python approve-families.py KEY[,KEY...] --note "what was checked" [--sheet NAME]
       python approve-families.py --ids 1,2,3 --note "..."
"""
import argparse
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = os.path.join(ROOT, 'Viewer', 'Presentation', 'reviewed-families.json')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('keys', nargs='?', default='')
    parser.add_argument('--ids', default='')
    parser.add_argument('--note', required=True)
    parser.add_argument('--sheet', default='')
    args = parser.parse_args()
    with open(os.path.join(ROOT, 'outputs', 'item-catalog', 'catalog.js'), encoding='utf-8') as handle:
        catalog = json.loads(handle.read()[len('window.CATALOG='):].rstrip().rstrip(';'))
    families = {f['key']: f for f in catalog['families']}
    reviewed = json.load(open(TARGET, encoding='utf-8')) if os.path.exists(TARGET) else {
        'description': 'Graphic IDs whose presented 3D look was checked against the original art in side-by-side sheets (scripts/compare-items.py). IDs only; no artwork.',
        'approved': []}
    known = {i for entry in reviewed['approved'] for i in entry['ids']}
    groups = [[int(i) for i in args.ids.split(',')]] if args.ids else []
    for key in filter(None, args.keys.split(',')):
        if key not in families:
            raise SystemExit('unknown family ' + key)
        groups.append(families[key]['ids'])
    added = 0
    for ids in groups:
        fresh = sorted(set(ids) - known)
        if fresh:
            reviewed['approved'].append({'ids': fresh, 'note': args.note, 'sheet': args.sheet})
            known.update(fresh)
            added += len(fresh)
    with open(TARGET, 'w', encoding='utf-8') as handle:
        json.dump(reviewed, handle, indent=1)
        handle.write('\n')
    print(f'approved {added} graphics ({len(known)} total)')


if __name__ == '__main__':
    main()
