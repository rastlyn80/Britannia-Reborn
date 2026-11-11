# SPDX-License-Identifier: GPL-3.0-or-later
"""Prepare both original Third Dawn spectral mounts for local comparison."""
import argparse
from hashlib import sha256
from io import BytesIO
import json
from pathlib import Path
import runpy

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = next(parent for parent in HERE.parents if (parent / 'scripts/prepare-distinct-mounts.py').is_file())
MODELS = ROOT / 'work/third-dawn/late-source-research/uoaos-source/Models'
CLIPS = dict(Idle='idle', Walk='walk', Run='run', Attack='attack1', Hit='gethit', Death='die1', Fidget='fidget')
FORMS = {
    191: {
        'study': 132, 'item': 0x3e9c, 'stem': 'kirin_kirin_ethereal',
        'source': 'd2ad26a67780494b2117852413f06117ade91dcb1191dda1304c6df70d9549ed',
        'atlas': '539aac8ddbab228cf60d96ab803058c5ca78635df4b49d7443f41acb72b18625',
        'shape': (144, 263, 30), 'normal_count': 6, 'height': 2.15,
        'donor': 'Monsters/kirin_kirin',
    },
    192: {
        'study': 122, 'item': 0x3e9b, 'stem': 'equines_unicorn_ethereal',
        'source': '2a0228b5952bbae4e0c67ed2393f8007132a68cd42f1b5ec556e55ba60f00a19',
        'atlas': '6e84566bc11e181fc789881d2a8ae47892db95a7f257b31670b6888ffcfe1df7',
        'shape': (230, 451, 35), 'normal_count': 10, 'height': 2.18,
        'donor': 'Animals/equines_horse_dappled_brown',
    },
}


def digest(data):
    return sha256(data).hexdigest()


def spectral_atlas(existing, body, mesh, raw, models):
    if body != 191:
        return existing['td'].png_from_tga(raw), {}
    living_mesh = (models / 'Monsters/kirin_kirin_lod2.grn').read_bytes()
    living_atlas = (models / 'Maps/kirin_kirin.tga').read_bytes()
    if (digest(living_mesh) != '05c05d151c68ef82ef4b136b5fcac9c4ef7c3ce1545026730beac98ab89549cb'
            or digest(living_atlas) != '4aa7e0efdc0b7a323314e1c2f6ebb5dfba917eccce76920121e8a6e811d59314'):
        raise ValueError('The original registered ki-rin cutout source changed.')
    reference, _ = existing['audit'].repair_invalid_normals(living_mesh)
    registration = ('polygons', 'uv_sets', 'texture_polygons')
    if not all(reference[key] == mesh[key] for key in registration):
        raise ValueError('The spectral ki-rin does not share the original cutout registration.')
    colour = Image.open(BytesIO(raw)).convert('RGBA')
    mask = Image.open(BytesIO(living_atlas)).convert('RGBA').getchannel('A')
    if colour.size != mask.size or colour.getchannel('A').getextrema() != (255, 255):
        raise ValueError('The original spectral ki-rin alpha contract changed.')
    colour.putalpha(mask)
    output = BytesIO()
    colour.save(output, 'PNG')
    return output.getvalue(), {'alpha_from_living_atlas_sha256': digest(living_atlas), 'same_uv_registration': True}


def main(models, output_dir):
    existing = runpy.run_path(str(ROOT / 'scripts/prepare-distinct-mounts.py'))
    reader = existing['td']
    pack = runpy.run_path(str(HERE / 'recover-pack-llama.py'))
    for body, form in FORMS.items():
        raw = (models / 'Animals' / (form['stem'] + '_lod2.grn')).read_bytes()
        atlas = (models / 'Maps' / (form['stem'] + '.tga')).read_bytes()
        reader.require(digest(raw) == form['source'] and digest(atlas) == form['atlas'],
                       f'Unexpected original spectral asset for body {body}')
        model, repair = existing['audit'].repair_invalid_normals(raw, allow_coincident_seams=True)
        shape = tuple(len(model[key]) for key in ('points', 'polygons', 'bones'))
        reader.require(model['textures'] == [form['stem'] + '.tga']
                       and shape == form['shape'] and repair['count'] == form['normal_count'],
                       f'Unexpected spectral rig or normal repair for body {body}')
        motions, provenance = {}, {}
        for label, suffix in CLIPS.items():
            filename = f'{form["donor"]}_{suffix}.grn'
            data = (models / filename).read_bytes()
            source = reader.parse(data, animations_only=True, scene_root_names=True)
            motions[label], omitted = existing['match_animation'](source, model)
            provenance[filename] = {'sha256': digest(data), 'omitted_unretained_subtrees': omitted}
        modern, refinement = pack['refine_body'](model)
        folder = output_dir / str(form['study'])
        folder.mkdir(parents=True, exist_ok=True)
        path = folder / 'ethereal-original.gltf'
        pixels, cutout = spectral_atlas(existing, body, model, atlas, models)
        stats = reader.export_gltf(modern, motions, pixels, path, height=form['height'],
                                   floor_sample_rate=120)
        receipt = {'historical_body': body, 'native_mount_item': form['item'], 'model_sha256': form['source'],
                   'atlas_sha256': form['atlas'], 'normal_repair': repair, 'source_motions': provenance,
                   'spectral_cutout': cutout,
                   'refinement': refinement, 'mesh': stats, 'gltf_sha256': digest(path.read_bytes()),
                   'scope': 'Private Third Dawn original spectral rig and atlas. ModernUO uses the native mount item only.'}
        (folder / 'ethereal-source.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
        print(body, 'original spectral mesh', shape, 'verified motions', len(motions), 'refined triangles', stats['triangles'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--models', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, default=ROOT / 'work/magical-equines/')
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    main(args.models, args.output_dir)
