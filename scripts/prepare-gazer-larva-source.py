"""Validate the private Gazer Larva inputs and decode its body and 21 cards."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'work/creatures/gazer-larva'
SOURCE = WORK / 'cabinet-members'
CABINETS = ROOT / 'work/third-dawn/late-source-research/uoaos-cabinets'
MANIFEST = ROOT / 'scripts/gazer-larva-inputs.json'


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def inputs():
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    for folder, files, key in ((SOURCE, manifest['files'], 'path'),
                               (CABINETS, manifest['cabinets'], 'zip_member')):
        for item in files:
            path = folder / (item[key] if key == 'path' else Path(item[key]).name)
            assert path.stat().st_size == item['bytes'] and sha(path) == item['sha256'], path
    constructor = manifest['native_class_source']
    path = ROOT / 'Server/ModernUO' / constructor['path'].replace('\\', '/')
    assert sha(path) == constructor['sha256']
    table = (SOURCE / 'Models/models.txt').read_text(encoding='latin-1')
    row, = (line.split() for line in table.splitlines() if line.startswith('778\t'))
    assert row[:3] == ['778', '0', '0'] and row[-4:] == ['1.3', '1.3', '1.3', 'swarm']
    return manifest


def pipeline():
    spec = importlib.util.spec_from_file_location('gazer_source_tools', ROOT / 'scripts/prepare-creatures.py')
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def decode(raw, names, tools, *, body_shape=(438, 782, 63), rigid_shape=(4, 2)):
    reader = tools.td
    chunks = list(reader.chunks(raw))
    rig = reader.parse(raw, animations_only=True, scene_root_names=True)
    named_ties = {rig['bones'][bone]['name']: index for index, bone in enumerate(rig['ties'])}
    assert len(names) > 1 and len(names) == len(set(names))
    card_ties = {index: named_ties[name] for index, name in enumerate(names) if index}

    def select(body):
        mesh, group = -1, None
        for tag, payload, parents in chunks:
            if tag == 0xca5e0601:
                mesh += 1
            if tag == 0xca5e0e02:
                group = int.from_bytes(payload[:4], 'little')
            if (tag == 0xca5e0601 or 0xca5e0601 in parents) and (mesh == 0) != body:
                continue
            if tag == 0xca5e0e06 and (group == 0) != body:
                continue
            # The source texture groups partition the original polygon
            # stream. The rigid reader instead expects bone-tie keys.
            if not body and tag == 0xca5e0e02:
                if group == 0:
                    continue
                payload = card_ties[group].to_bytes(4, 'little') + payload[4:]
            yield tag, payload, parents

    original_chunks = reader.chunks
    try:
        reader.chunks = lambda _: iter(select(True))
        body = reader.parse(raw, scene_root_names=True)
    finally:
        reader.chunks = original_chunks
    assert (len(body['points']), len(body['polygons']), len(body['bones'])) == body_shape
    card_reader = SimpleNamespace(chunks=lambda _: iter(select(False)), parse=reader.parse,
                                  require=reader.require, finite=reader.finite)
    cards, parts, links = tools.rigid.read_rigid_parts(raw, card_reader, excluded_names=())
    assert len(parts) == len(names) - 1
    assert all((len(part['points']), len(part['polygons'])) == rigid_shape for part in parts)
    assert {part['name'] for part in links['parts']} == set(names[1:])
    assert all(body[key] == cards[key] for key in ('bones', 'ties', 'textures'))
    assert len(body['uv_sets']) == len(cards['uv_sets']) == 1
    result = copy.deepcopy(body)
    point_offset, normal_offset, uv_offset = len(body['points']), len(body['normals']), len(body['uv_sets'][0])
    result['points'] += cards['points']
    result['normals'] += cards['normals']
    result['uv_sets'][0] += cards['uv_sets'][0]
    result['polygons'] += [tuple(index + point_offset for index in face[:3])
                           + tuple(index + normal_offset for index in face[3:]) for face in cards['polygons']]
    result['texture_polygons'] += [tuple(index + uv_offset for index in face) for face in cards['texture_polygons']]
    result['weights'] += cards['weights']
    point_count = body_shape[0] + len(parts) * rigid_shape[0]
    polygon_count = body_shape[1] + len(parts) * rigid_shape[1]
    assert (len(result['points']), len(result['polygons']), len(result['weights'])) == (point_count, polygon_count, point_count)
    result['source_scale_shear'] = [list(struct.unpack('<I16f', payload)[8:])
                                    for tag, payload, _ in chunks if tag == 0xca5e0506]
    assert len(result['source_scale_shear']) == body_shape[2]
    return result, links


def main():
    manifest = inputs()
    assert manifest['parts'][0] == 'swarm' and len(manifest['parts']) == 22
    model, cards = decode((SOURCE / 'Models/Monsters/swarm_lod2.grn').read_bytes(), manifest['parts'], pipeline())
    output = WORK / 'owned-source'
    output.mkdir(parents=True, exist_ok=True)
    (output / 'source-hybrid-raw-ir.json').write_text(
        json.dumps(model, separators=(',', ':'), allow_nan=False) + '\n', encoding='utf-8')
    (output / 'card-bindings.json').write_text(json.dumps(cards, indent=2) + '\n', encoding='utf-8')
    print('GAZER LARVA SOURCE: 63 original bones, 782 body triangles and 21 rigid cards')


if __name__ == '__main__':
    main()
