# SPDX-License-Identifier: GPL-3.0-or-later
"""Build a private later Third Dawn ki-rin with its matching original colour atlas."""
import argparse
from hashlib import sha256
import json
from pathlib import Path
import runpy


HERE = Path(__file__).resolve().parent
ROOT = next(parent for parent in HERE.parents if (parent / 'scripts/prepare-distinct-mounts.py').is_file())
MODELS = ROOT / 'work/third-dawn/late-source-research/uoaos-source/Models'
CLIPS = dict(Idle='idle', Walk='walk', Run='run', Attack='attack1', Hit='gethit', Death='die1', Fidget='fidget')


def sha(data):
    return sha256(data).hexdigest()


def main(models, output_dir):
    existing = runpy.run_path(str(ROOT / 'scripts/prepare-distinct-mounts.py'))
    reader = existing['td']
    source = models / 'Monsters/kirin_kirin_lod2.grn'
    atlas = models / 'Maps/kirin_kirin.tga'
    raw, texture = source.read_bytes(), atlas.read_bytes()
    reader.require(sha(raw) == '05c05d151c68ef82ef4b136b5fcac9c4ef7c3ce1545026730beac98ab89549cb'
                   and sha(texture) == '4aa7e0efdc0b7a323314e1c2f6ebb5dfba917eccce76920121e8a6e811d59314',
                   'Unexpected later ki-rin mesh or atlas')
    model, repair = existing['audit'].repair_invalid_normals(raw)
    reader.require(model['textures'] == [atlas.name] and len(model['bones']) == 30
                   and len(model['points']) == 144 and len(model['polygons']) == 263
                   and repair['unused_indices_after_pruning'] == [25, 114, 115, 118, 119, 125],
                   'Unexpected ki-rin geometry or normal repair')
    animations, motions = {}, {}
    for clip, suffix in CLIPS.items():
        filename = f'kirin_kirin_{suffix}.grn'
        animation = (models / 'Monsters' / filename).read_bytes()
        track = reader.parse(animation, animations_only=True, scene_root_names=True)
        animations[clip], omitted = existing['match_animation'](track, model)
        motions[clip] = {'member': filename, 'sha256': sha(animation), 'omitted_unretained_subtrees': omitted}
    strengths = []
    for row in model['weights']:
        names = [model['bones'][model['ties'][tie]]['name'] for tie, weight in row if weight > .20]
        if any(part in name for name in names for part in ('foot', 'hand', 'finger', 'toe')):
            strengths.append(0.)
        elif any('head' in name for name in names):
            strengths.append(.32)
        else:
            strengths.append(.82)
    modern, refinement = existing['smooth'].refine(model, levels=2, maximum=.025,
                                                   strengths=strengths, weight_smoothing=.11)
    outputs = {}
    for name, body in [('original', model), ('modern', modern)]:
        path = output_dir / f'kirin-late-{name}.gltf'
        stats = reader.export_gltf(body, animations, reader.png_from_tga(texture), path,
                                   height=2.15, floor_sample_rate=120)
        gltf = json.loads(path.read_text(encoding='utf-8'))
        gltf['materials'][0].update(name='Original Ki-rin', alphaMode='MASK', alphaCutoff=.35)
        path.write_text(json.dumps(gltf, separators=(',', ':')), encoding='utf-8')
        outputs[name] = {'sha256': sha(path.read_bytes()), 'stats': stats}
    report = {'body': 132, 'model_sha256': sha(raw), 'atlas_sha256': sha(texture),
              'normal_repair': repair, 'motions': motions, 'refinement': refinement, 'outputs': outputs,
              'scope': 'Private source conversion. Later model UVs do not match the existing early rig.'}
    (output_dir / 'kirin-late-receipt.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print('Ki-rin: original colour and seven motions on the later 30-joint rig, 263 source triangles and 4208 refined')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--models', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, default=ROOT / 'work/magical-equines/132')
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    main(args.models, args.output_dir)
