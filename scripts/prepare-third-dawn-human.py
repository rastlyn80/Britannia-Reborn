"""Prepare a private human material/wardrobe experiment from a local ZIP.

Keeps the original skeleton, UVs and body scale. The separately generated
modern atlas must already exist locally; it is never downloaded by this tool.
"""
import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('granny_import', Path(__file__).with_name('import-third-dawn.py'))
granny = importlib.util.module_from_spec(spec)
spec.loader.exec_module(granny)
smooth_spec = importlib.util.spec_from_file_location('granny_smooth', Path(__file__).with_name('third-dawn-subdivide.py'))
smooth = importlib.util.module_from_spec(smooth_spec)
smooth_spec.loader.exec_module(smooth)


def hidden_body(model, region):
    """Explicit prototype coverage masks in the original undeformed rig.

    These are coarse garment-specific masks, not a universal clothing solver.
    Keep head/hands/feet; mask the torso/limbs that the selected garment covers.
    """
    hidden = []
    for i, point in enumerate(model['points']):
        bone_names = [(model['bones'][model['ties'][tie]]['name'], weight)
                      for tie, weight in model['weights'][i]]
        covered = 0.0
        for name, weight in bone_names:
            parts = ('pelvis', 'spine', 'clavicle', 'upperarm', 'forearm')
            if region == 'robe':
                parts += ('thigh', 'calf')
            if any(part in name for part in parts):
                covered += weight
        hide = covered > .45
        if region == 'shirt':
            hide = hide and point[2] > .795 and abs(point[0]) < .715
        # Both source garments have open collars: the neck/chest wedge must
        # remain beneath them instead of becoming a dark hole above the seam.
        if point[2] > 1.35 and abs(point[0]) < .095:
            hide = False
        hidden.append(hide)
    selected = [i for i, p in enumerate(model['polygons']) if sum(hidden[j] for j in p[:3]) < 2]
    result = copy.deepcopy(model)
    result['polygons'] = [model['polygons'][i] for i in selected]
    result['texture_polygons'] = [model['texture_polygons'][i] for i in selected]
    return result, len(model['polygons']) - len(selected)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--archive', type=Path, required=True)
    args = ap.parse_args()
    output = ROOT / 'Viewer/local-art/third-dawn'
    output.mkdir(parents=True, exist_ok=True)
    texture = output / 'human-modern-albedo.png'
    granny.require(texture.exists(), 'Missing local generated human-modern-albedo.png')
    evidence = dict(archive_sha256=hashlib.sha256(args.archive.read_bytes()).hexdigest(),
                    recipe_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                    subdivision_code_sha256=hashlib.sha256(Path(__file__).with_name('third-dawn-subdivide.py').read_bytes()).hexdigest(),
                    texture_sha256=hashlib.sha256(texture.read_bytes()).hexdigest(),
                    texture_source='Built-in ImageGen edit of the original UV atlas; layout kept as a generation constraint, verified on model',
                    generated_image='exec-982f0350-9a07-432e-b835-313de5a97a64.png',
                    licence='Proprietary-derived private experiment; no redistribution grant',
                    inputs=[], variants={})
    prompt = output / 'human-modern-albedo.prompt.txt'
    if prompt.exists():
        evidence['generation_prompt'] = prompt.read_text()
        evidence['generation_prompt_sha256'] = hashlib.sha256(prompt.read_bytes()).hexdigest()
    with zipfile.ZipFile(args.archive) as archive:
        names = {n.lower(): n for n in archive.namelist()}

        def read(path):
            name = names['uotdb/uotd/models/' + path.lower()]
            raw = archive.read(name)
            evidence['inputs'].append(dict(path=name, sha256=hashlib.sha256(raw).hexdigest()))
            return granny.parse(raw)

        def albedo(model):
            granny.require(len(set(model['textures'])) == 1, 'Expected one texture')
            name = next(n for n in archive.namelist() if n.rsplit('/', 1)[-1].lower() == model['textures'][0])
            raw = archive.read(name)
            evidence['inputs'].append(dict(path=name, sha256=hashlib.sha256(raw).hexdigest()))
            return granny.png_from_tga(raw)

        body = read('Humans/H_Male_LOD2.grn')
        clips = {name: read('Humans/H_Male_' + suffix + '.grn') for name, suffix in
                 [('Idle', 'Idle1'), ('Walk', 'Walk'), ('Run', 'Run')]}
        body_texture = albedo(body)
        body_names = {b['name'] for b in body['bones']}
        body_scale = 1.8 / (max(p[2] for p in body['points']) - min(p[2] for p in body['points']))
        refined_body, refined_report = smooth.refine(body, levels=2, maximum=.018)
        evidence['subdivision'] = refined_report
        granny.export_gltf(refined_body, clips, body_texture, output / 'human-smooth.gltf', 1.8)

        def fit_scale(path):
            data = json.loads(path.read_text())
            data['nodes'][0]['scale'] = [body_scale] * 3
            path.write_text(json.dumps(data, separators=(',', ':')))

        fit_scale(output / 'human-smooth.gltf')
        for slot, source in [('shirt', 'H_MALE_Armor_Chain_Shirt_LOD2.grn'),
                             ('robe', 'H_MALE_Robe_cowldown_LOD2.grn')]:
            garment = read('Others/' + source)
            used = {garment['bones'][garment['ties'][index]]['name'] for pairs in garment['weights'] for index, w in pairs if w > 0}
            granny.require(not used - body_names, 'Garment has unmatched weighted bones')
            span = max(p[2] for p in garment['points']) - min(p[2] for p in garment['points'])
            report = granny.export_gltf(garment, {}, albedo(garment), output / ('gear-' + slot + '.gltf'), span * body_scale)
            masked, hidden = hidden_body(body, slot)
            # Retain the original full-body points/weights for floor fitting.
            result = granny.export_gltf(masked, clips, body_texture, output / ('human-' + slot + '.gltf'), 1.8)
            # Export scaling must always be based on the *whole* body, even
            # when the remaining visible triangles no longer include the crown.
            data = json.loads((output / ('human-' + slot + '.gltf')).read_text())
            data['nodes'][0]['scale'] = [body_scale] * 3
            (output / ('human-' + slot + '.gltf')).write_text(json.dumps(data, separators=(',', ':')))
            evidence['variants'][slot] = dict(garment_triangles=report['triangles'], weighted_bones=len(used),
                                              hidden_body_triangles=hidden, body_triangles=result['triangles'])
            refined_masked, refined_hidden = hidden_body(refined_body, slot)
            granny.export_gltf(refined_masked, clips, body_texture, output / ('human-smooth-' + slot + '.gltf'), 1.8)
            fit_scale(output / ('human-smooth-' + slot + '.gltf'))
            refined_garment, garment_report = smooth.refine(garment, levels=1, maximum=.009)
            granny.export_gltf(refined_garment, {}, albedo(garment), output / ('gear-smooth-' + slot + '.gltf'), span * body_scale)
            evidence['variants'][slot]['subdivision'] = garment_report
            evidence['variants'][slot]['refined_hidden_body_triangles'] = refined_hidden
    for path in output.glob('*.gltf'):
        evidence.setdefault('outputs', {})[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
    (output / 'human-wardrobe-provenance.json').write_text(json.dumps(evidence, indent=2))
    print(json.dumps(evidence['variants'], indent=2))


if __name__ == '__main__':
    main()
