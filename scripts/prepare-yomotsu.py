"""Build the original Warrior, Priest and Elder from pinned local sources."""
import json
import math
from pathlib import Path
import runpy
from shutil import copyfile
import struct

HERE = Path(__file__).resolve().parent
LATE = runpy.run_path(str(HERE / 'prepare-hydra.py'))
ROOT, BASE, SHA, checked = (LATE[key] for key in ('ROOT', 'BASE', 'SHA', 'checked'))
MANIFEST = HERE / 'yomotsu-inputs.json'
ART = ROOT / 'Viewer/local-art/creatures/yomotsu'
RES = 'res://local-art/creatures/yomotsu/'
WARRIOR_ZERO_WEIGHTS = (2, 56, 105)
FORMS = {245: ('yomotsu_warrior', 'YomotsuWarrior', 26),
         253: ('yomotsu_priest', 'YomotsuPriest', 25),
         255: ('yomotsu_elder', 'YomotsuElder', 25)}


def repair_warrior(raw, pipeline, parse, options):
    buffer, = [payload for tag, payload, _ in pipeline.td.chunks(raw) if tag == 0xca5e0702]
    if raw.count(buffer) != 1 or struct.unpack_from('<I', buffer)[0] != 240:
        raise ValueError('Unexpected Warrior skin buffer')
    patched = bytearray(raw)
    offset = raw.index(buffer)
    cursor = 12
    zero_weights = []
    for vertex in range(240):
        count, = struct.unpack_from('<I', buffer, cursor)
        cursor += 4
        if not 0 < count <= 4 or cursor + count * 8 > len(buffer):
            raise ValueError('Invalid Warrior skin influence count')
        pairs = [struct.unpack_from('<If', buffer, cursor + slot * 8) for slot in range(count)]
        weights = [weight for _, weight in pairs]
        if any(weight < 0 or not math.isfinite(weight) for weight in weights):
            raise ValueError('Invalid Warrior skin weights')
        if pairs == [(0, 0.0)]:
            zero_weights.append(vertex)
            struct.pack_into('<f', patched, offset + cursor + 4, 1.0)
        elif abs(sum(weights) - 1.0) >= 0.001:
            raise ValueError('Unexpected unnormalized Warrior skin')
        cursor += count * 8
    if tuple(zero_weights) != WARRIOR_ZERO_WEIGHTS or cursor != len(buffer):
        raise ValueError('Warrior zero-weight vertices changed')
    model = parse(bytes(patched), **options)
    for vertex in zero_weights:
        model['weights'][vertex] = []
    repairs = {}
    for vertex in zero_weights:
        weights, adjacent = pipeline.repairs.neighbour_weights(model, vertex)
        repairs[vertex] = {'neighbors': adjacent, 'weights': weights}
    for vertex, repair in repairs.items():
        model['weights'][vertex] = repair['weights']
    return model, repairs


def main():
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    table = checked(BASE / 'model-table/Client/Models.txt', manifest['model_table_sha256'])
    members = {name.lower(): checked(BASE / 'yomotsu-source' / name, digest)
               for name, digest in manifest['files'].items()}

    class Inputs:
        def read(self, name):
            return members[name].read_bytes()

    pipeline = LATE['TOOLS']['pipeline']()
    pipeline.helper.audit.ARCHIVE_HASH = manifest['installer_sha256']
    pipeline.OUTPUT = BASE / 'yomotsu-preview'
    warrior = next(path.read_bytes() for name, path in members.items() if name.endswith('/yomotsu_warrior_lod2.grn'))
    parse = pipeline.td.parse
    repair_notes = {}

    def parse_source(raw, **options):
        if raw == warrior and not options.get('animations_only'):
            model, repairs = repair_warrior(raw, pipeline, parse, options)
            repair_notes.update(repairs)
            return model
        return parse(raw, **options)

    pipeline.td.parse = parse_source
    humanoid_actions = pipeline.humanoid_actions
    install_humanoid_actions = humanoid_actions.install

    def install_actions(body, clips, authored, aliases, kind):
        if kind == 'yomotsu_priest' and 'Cast' not in clips:
            clips['Cast'] = humanoid_actions.gesture(body, clips['Idle'], 'Cast')
            authored['Cast'] = 'Authored casting gesture on the original Priest rig.'
        return install_humanoid_actions(body, clips, authored, aliases, kind)

    humanoid_actions.install = install_actions
    rows = pipeline.table_rows(table.read_bytes())
    _, native = pipeline.native_bodies()
    names = {name: name for name in members}
    ART.mkdir(parents=True, exist_ok=True)
    models = []
    for body, (kind, native_class, joints) in FORMS.items():
        selected = [entry for entry in rows if entry['stem'] != kind or entry['body'] == body]
        row, = pipeline.prepare('yomotsu', Inputs(), names, selected, native, selected_kinds={kind})
        if row['status'] != 'prepared':
            raise RuntimeError(f'{kind} conversion failed: {row.get("blocker")}')
        identity, = row['bodies']
        if identity['body'] != body or row['stats']['original']['bones'] != joints:
            raise ValueError(f'Unexpected source rig for {kind}')
        if body == 245:
            row['skin_repair'] = {'vertices': repair_notes,
                                  'method': 'Authored inverse-distance weights from valid source neighbors.'}
        if body == 253:
            helper = HERE / 'creature-humanoid-actions.py'
            row['authored_cast_recipe_sha256'] = SHA(helper)
        row.update(native_constructor_hues={native_class: 0}, assets={}, asset_sha256={},
                   art_dependency_sha256={})
        for variant in ('original', 'rounded', 'modern'):
            name = f'{kind}-{variant}.gltf'
            copyfile(pipeline.OUTPUT / name, ART / name)
            row['assets'][variant] = RES + name
            row['asset_sha256'][variant] = SHA(ART / name)
        models.append(row)
        print(f'{kind} {body}: {joints} joints and {len(row["clip_sources"])} recovered motions', flush=True)
    pending = ART / 'preparation.pending'
    pending.write_text(json.dumps({'models': models, 'input_manifest_sha256': SHA(MANIFEST)},
                                  indent=2) + '\n', encoding='utf-8')
    pending.replace(ART / 'preparation.json')


if __name__ == '__main__':
    main()
