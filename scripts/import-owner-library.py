"""Convert owner-purchased Dexsoft and Arteria3d pack models into a local prop library.

The packs stay outside Git; models are converted to GLB in the ignored
Viewer/local-art/library/<slot>/ folder with catalog.json. Presentation/LocalLibrary.gd
uses them for item families assigned to these slots; without the library the
client keeps its CC0 and procedural looks.

usage: python import-owner-library.py [EXTRACTED_PACKS_DIR] [--only slot,slot]
EXTRACTED_PACKS_DIR (default local-art/extracted/packs) holds each pack archive
unpacked into its own folder (7-Zip), named as in SLOTS below.
"""
import glob
import hashlib
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT = os.path.join(ROOT, 'Viewer', 'local-art', 'library')
ME = 'arteria-middle-east-pack/Arteria3d - Middle East Pack/'
CAVE = 'arteria-cave-construction-kit/Arteria3d - Cave Construction Kit/'
WB = 'arteria-medieval-world-builder/Arteria3d - Medieval World Builder/Other Models/furniture_pack/'
VIK = 'arteria-viking-pack-for-unity/Arteria3d - Viking Pack for Unity/Assets/Arteria3d Viking Pack/props/'
INT = 'dexsoft-fantasy-interior/Fantasy Interior/'
MKT = 'dexsoft-fantasy-marketplace/Fantasy Marketplace/'
OUT = 'dexsoft-fantasy-outdoor/Fantasy Outdoor/'
TAV = 'dexsoft-medieval-tavern/Dexsoft Medieval Tavern/'
TMP = 'dexsoft-temple-interior-construction-kit/'
# slot -> (triangle budget, [source globs relative to the extracted packs folder])
SLOTS = {
    'palm': (9000, [ME + 'palms/Model Formats/FBX/palm[1-4].fbx']),
    'palm_small': (5000, [ME + 'palms/Model Formats/FBX/floorpalm[12].fbx']),
    'tropical_plant': (4000, [ME + 'plants/plant1.fbx', OUT + 'Plant01/plant01.obj']),
    'cypress': (6000, ['arteria-roman-pack/roman_pack/Trees/cypress/cypress.obj']),
    'skull': (1500, [CAVE + 'misc/bones/skull[1-3].obj']),
    'bone': (1500, [CAVE + 'misc/bones/bone.obj']),
    'gravestone': (2000, ['arteria-medieval-church/MedievalChurch/OBJ/gravestone[A-K].obj']),
    'mushroom': (2000, [CAVE + 'misc/toadstools/toadstool1_[a-d].obj']),
    'stalagmite': (2500, [CAVE + 'CaveElements/stalag[1-5].obj']),
    'rock': (3000, ['dexsoft-rocks-model-pack/**/rock_0[01][0-9].obj']),
    'candle': (1200, [INT + 'candle/candle.obj', TAV + '**/tavern_candle.obj']),
    'candlestick': (2500, [INT + 'candle_stick/candle_stick.obj', WB + 'candlestick[12]/candlestick[12].obj']),
    'lantern': (2500, [TAV + '**/tavern_lamp[12].obj']),
    'chair': (3000, [TAV + '**/tavern_chair.obj', TAV + '**/tavern_chair3.obj', INT + 'chair/chair.obj', WB + 'chair1/chair1.obj']),
    'stool': (2000, [INT + 'stool/stool.obj', WB + 'stool/stool.obj']),
    'table': (4000, [TAV + '**/tavern_table.obj', TAV + '**/tavern_table2.obj', INT + 'table/table.obj', WB + 'table1/table1.obj']),
    'bench': (3000, [TAV + '**/tavern_bench.obj', OUT + 'bench/bench.obj']),
    'bed': (5000, [TAV + '**/tavern_bed.obj', INT + 'bed01/bed01.obj']),
    'shelf': (5000, [INT + 'shelf/shelf.obj', INT + 'shelf2/shelf2.obj', TAV + '**/tavern_shelf1.obj']),
    'chest': (3000, [INT + 'chest2/chest2.obj', INT + 'chest3/chest3.obj', MKT + 'chest/chest.obj', WB + 'Chests/chest[12].obj']),
    'bottle': (1200, [MKT + 'bottle/bottle.obj', TAV + '**/tavern_bottle.obj']),
    'cup': (1200, [MKT + 'cup/cup.obj', TAV + '**/tavern_cup.obj', TAV + '**/tavern_cup2.obj', WB + 'tankard/ec_tankard.obj', WB + 'goblet/ec_goblet.obj']),
    'plate': (1200, [INT + 'plate/plate.obj', TAV + '**/tavern_plate.obj', WB + 'plate/ec_plate.obj']),
    'jug': (1500, [WB + 'jug/ec_jug1.obj', WB + 'milkjug/ec_milkjug.obj']),
    'book': (1200, [MKT + 'book/book.obj', MKT + 'book2/book2.obj']),
    'book_open': (1500, [MKT + 'book_open/book_open.obj', MKT + 'book_open2/book_open2.obj', WB + 'open_book/ec_openbook.obj']),
    'scroll': (1200, [INT + 'scroll/scroll.obj', INT + 'scroll2/scroll2.obj', INT + 'parchment/parchment.obj']),
    'fruit': (1500, [MKT + 'apple/apple.obj', MKT + 'guava/guava.obj', MKT + 'strawberry/strawberry.obj', ME + 'props/Model Formats/OBJ/fruit_veg[1-7].obj']),
    'bread': (1500, [ME + 'props/Model Formats/OBJ/bread.obj']),
    'sack': (2000, [MKT + 'sack/sack.obj', ME + 'props/Model Formats/OBJ/grainsack[2-6].obj']),
    'basket': (2000, [ME + 'props/Model Formats/OBJ/basket.obj']),
    'vase': (2000, [MKT + 'vase/vase.obj', ME + 'props/Model Formats/OBJ/amphora*.obj', 'arteria-roman-pack/roman_pack/props/pot 1.obj']),
    'sword': (1500, ['dexsoft-fantasy-weapons/**/sword*.obj']),
    'axe': (1500, ['dexsoft-fantasy-weapons/**/axe2*.obj']),
    'shield': (2000, ['dexsoft-fantasy-weapons/**/shield*.obj']),
    'coin': (800, [MKT + 'coin/coin.obj', MKT + 'coin2/coin2.obj']),
    'gem': (800, [MKT + 'gem*/gem*.obj']),
    'well': (6000, [OUT + 'well/well.obj', VIK + 'well/well.obj']),
    'signpost': (2000, [OUT + 'signpost*/signpost*.obj']),
    'market_stall': (6000, [MKT + 'market_booth/market_booth.obj', MKT + 'canopy*/canopy*.obj']),
    'cart': (6000, ['arteria-medieval-world-builder/Arteria3d - Medieval World Builder/Props/carts/cart[1-4].obj']),
    'fireplace': (5000, [TAV + '**/tavern_fireplace.obj']),
    'anvil': (2000, [VIK + 'anvil/anvil.obj']),
    'logs': (3000, [VIK + 'logs/logs.obj', OUT + 'log/log.obj', OUT + 'log2/log2.obj']),
    'haystack': (3000, [VIK + 'hay_stack/hay_stack.obj']),
    'statue': (8000, [TMP + '**/Guardianstatue.obj', 'arteria-roman-pack/roman_pack/monuments/robed senate/male_statue.obj']),
    'altar': (5000, [TMP + '**/altar.obj']),
    'chandelier': (4000, [TMP + '**/Chandelier.obj', TMP + '**/chandelier2.obj']),
    'brazier': (3000, [TMP + '**/RockstandFirebowl.obj', TMP + '**/Incensary.obj']),
    'bucket': (1500, [INT + 'bucket/bucket.obj']),
    'box': (1500, [MKT + 'wood_box/wood_box.obj', MKT + 'box_open/box_open.obj', TAV + '**/tavern_box.obj']),
    'gallows': (6000, ['arteria-medieval-world-builder/Arteria3d - Medieval World Builder/Other Models/gallows/base model/gallows.obj']),
    'guillotine': (6000, ['arteria-medieval-world-builder/Arteria3d - Medieval World Builder/Other Models/guillotine/base model/guillotine.obj']),
    'meat': (2000, [VIK + 'meat/meat.obj']),
    'painting': (800, [TAV + '**/painting[1-9].obj']),
    'pot': (2000, [VIK + 'pot/pot.obj']),
}


def main():
    packs = os.path.join(ROOT, 'local-art', 'extracted', 'packs')
    only = None
    for arg in sys.argv[1:]:
        if arg.startswith('--only='):
            only = set(arg[7:].split(','))
        elif not arg.startswith('--'):
            packs = arg
    jobs, owners = [], {}
    for slot, (budget, patterns) in SLOTS.items():
        if only and slot not in only:
            continue
        sources = []
        for pattern in patterns:
            sources += sorted(p for p in glob.glob(os.path.join(packs, pattern), recursive=True)
                              if 'lod' not in os.path.basename(p).lower() and '/._' not in p.replace('\\', '/'))
        for number, source in enumerate(dict.fromkeys(sources)):
            name = f'{slot}_{number + 1:02d}'
            output = os.path.join(OUTPUT, slot, name + '.glb')
            pack_dir = os.path.join(packs, os.path.relpath(source, packs).split(os.sep)[0])
            jobs.append({'source': source, 'output': output, 'search': [pack_dir], 'max_triangles': budget})
            owners[output] = (slot, name, os.path.relpath(source, packs).replace('\\', '/'))
    os.makedirs(OUTPUT, exist_ok=True)
    job_file = os.path.join(OUTPUT, 'jobs.local.json')
    report_file = os.path.join(OUTPUT, 'report.local.json')
    json.dump(jobs, open(job_file, 'w', encoding='utf-8'), indent=1)
    blender = glob.glob(os.path.join(ROOT, '.tools', 'blender', '*', 'blender.exe'))[0]
    subprocess.run([blender, '-b', '--factory-startup', '--python', os.path.join(ROOT, 'scripts', 'blender-library-convert.py'),
                    '--', job_file, report_file], check=True, stdout=subprocess.DEVNULL)
    report = json.load(open(report_file, encoding='utf-8'))
    catalog_path = os.path.join(OUTPUT, 'catalog.json')
    catalog = json.load(open(catalog_path, encoding='utf-8')) if os.path.exists(catalog_path) else {
        'licence': 'Owner-purchased Dexsoft and Arteria3d model packs; local use only, never committed.', 'slots': {}}
    for slot in {owners[o][0] for o in owners}:
        catalog['slots'][slot] = []
    failures = 0
    for output, (slot, name, source) in owners.items():
        result = report.get(output, {'error': 'not converted'})
        if 'error' in result or result.get('materials_textured', 0) == 0:
            failures += 1
            print('SKIP', name, source, result.get('error', 'no texture found'))
            continue
        catalog['slots'][slot].append({'name': name, 'file': f'{slot}/{name}.glb', 'source': source,
                                       'triangles': result['triangles'], 'size': [round(v, 3) for v in result['size']],
                                       'sha256': hashlib.sha256(open(output, 'rb').read()).hexdigest()})
    catalog['slots'] = {k: v for k, v in sorted(catalog['slots'].items()) if v}
    json.dump(catalog, open(catalog_path, 'w', encoding='utf-8'), indent=1)
    total = sum(len(v) for v in catalog['slots'].values())
    print(f'LOCAL LIBRARY: {total} models in {len(catalog["slots"])} slots ({failures} skipped) -> {OUTPUT}')


if __name__ == '__main__':
    main()
