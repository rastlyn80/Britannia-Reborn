"""Private head/joint rounding recipe; preserves the native rig and original inputs."""
import argparse
import copy
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('wardrobe', Path(__file__).with_name('prepare-third-dawn-human.py'))
wardrobe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wardrobe)
g = wardrobe.granny


def falloff(distance):
    t = max(0., min(1., 1. - distance))
    return t * t * (3. - 2. * t)


def anatomy_source(model):
    """Small source-specific corrections before rounding; no skeleton edits."""
    result = copy.deepcopy(model)
    for i, (x, y, z) in enumerate(model['points']):
        # The original low chest apex reads as a pointed wedge in profile.
        chest_distance = math.sqrt((x/.23)**2 + ((z-1.275)/.17)**2)
        chest = falloff(max(0., (chest_distance-.4)/.7)) if y < -.025 else 0.
        head = sum(w for tie, w in model['weights'][i]
                   if model['bones'][model['ties'][tie]]['name'].endswith(' head'))
        jaw = head * falloff(math.sqrt((x/.075)**2 + ((z-1.535)/.06)**2))
        cheek = head * falloff(math.sqrt(((abs(x)-.05)/.045)**2 + ((z-1.60)/.065)**2))
        result['points'][i] = (x + math.copysign(.004*cheek, x),
                               y + .020*chest + .004*jaw,
                               z + .024*chest + .003*jaw)
    return result


def region_strengths(model, anatomy=False):
    strengths = []
    for point, pairs in zip(model['points'], model['weights']):
        x, y, z = point
        head = sum(w for tie, w in pairs if model['bones'][model['ties'][tie]]['name'].endswith(' head'))
        # Protect the mouth/nose from excessive shrinkage; round crown and jaw.
        face = (.78 if anatomy else .35) if y < -.075 and 1.54 < z < 1.64 else 1.
        strength = head * face
        if anatomy:
            # Broader support around the pectorals avoids isolated apex dents.
            chest = math.sqrt((x/.265)**2 + ((z-1.30)/.24)**2)
            strength = max(strength, (.95 if y < .02 else .55) * falloff(max(0., (chest-.55)/.65)))
        for cx, cz, rx, rz, amount in [(.48, 1.385, .15, .12, 1.),
                                     (.105, .535, .14, .18, .85),
                                     (.205, 1.405, .13, .13, .55),
                                     (.13, .12, .12, .11, .45)]:
            d = math.sqrt(((abs(x)-cx)/rx)**2 + ((z-cz)/rz)**2)
            strength = max(strength, amount * falloff(d))
        strengths.append(strength)
    return strengths


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--archive', type=Path, required=True)
    ap.add_argument('--anatomy', action='store_true', help='Refine chest and facial transitions; retain the previous rounded variant')
    args = ap.parse_args()
    out = ROOT / 'Viewer/local-art/third-dawn'
    evidence = dict(archive_sha256=hashlib.sha256(args.archive.read_bytes()).hexdigest(), inputs=[],
                    recipe_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                    subdivision_sha256=hashlib.sha256(Path(__file__).with_name('third-dawn-subdivide.py').read_bytes()).hexdigest(),
                    licence='Proprietary-derived private experiment; no redistribution grant')
    with zipfile.ZipFile(args.archive) as archive:
        names = {n.lower(): n for n in archive.namelist()}
        def read(path):
            name = names['uotdb/uotd/models/' + path.lower()]
            raw = archive.read(name)
            evidence['inputs'].append(dict(path=name, sha256=hashlib.sha256(raw).hexdigest()))
            return g.parse(raw)
        body = read('Humans/H_Male_LOD2.grn')
        clips = {name: read('Humans/H_Male_' + suffix + '.grn') for name, suffix in
                 [('Idle', 'Idle1'), ('Walk', 'Walk'), ('Run', 'Run')]}
        texname = next(n for n in archive.namelist() if n.rsplit('/', 1)[-1].lower() == body['textures'][0])
        raw = archive.read(texname)
        evidence['inputs'].append(dict(path=texname, sha256=hashlib.sha256(raw).hexdigest()))
        texture = g.png_from_tga(raw)
        sculpted = anatomy_source(body) if args.anatomy else body
        strengths = region_strengths(sculpted, args.anatomy)
        rounded, report = wardrobe.smooth.refine(sculpted, levels=2, maximum=.04, strengths=strengths, weight_smoothing=.35)
        evidence['anatomy_pass'] = args.anatomy
        evidence['source_correction_max'] = max(math.dist(a,b) for a,b in zip(body['points'],sculpted['points']))
        evidence['source_vertex_total_max_movement'] = max(math.dist(p, rounded['points'][i]) for i,p in enumerate(body['points']))
        evidence['combined_movement_upper_bound'] = evidence['source_correction_max'] + report['measured_max_displacement']
        if args.anatomy and (out/'human-rounded.gltf').exists():
            evidence['comparison_sha256'] = hashlib.sha256((out/'human-rounded.gltf').read_bytes()).hexdigest()
        evidence['rounding'] = report
        evidence['joint_weight_smoothing'] = .35
        assert all(math.dist(p, rounded['points'][i]) < 1e-12 for i,p in enumerate(sculpted['points']) if strengths[i] == 0), 'Unselected source geometry moved'
        evidence['selected_source_vertices'] = sum(w > 0 for w in strengths)
        evidence['fixed_source_vertices'] = sum(w == 0 for w in strengths)
        evidence['source_vertex_movement'] = {str(i): math.dist(p, rounded['points'][i]) for i,p in enumerate(body['points']) if strengths[i]>0}
        scale = 1.8 / (max(p[2] for p in body['points']) - min(p[2] for p in body['points']))
        for slot in ['base', 'shirt', 'robe']:
            model = rounded if slot == 'base' else wardrobe.hidden_body(rounded, slot)[0]
            path = out / (('human-anatomy' if args.anatomy else 'human-rounded') + ('' if slot == 'base' else '-' + slot) + '.gltf')
            g.export_gltf(model, clips, texture, path, 1.8)
            data = json.loads(path.read_text())
            data['nodes'][0]['scale'] = [scale]*3
            path.write_text(json.dumps(data,separators=(',', ':')))
            evidence.setdefault('outputs',{})[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
    (out/('human-anatomy-provenance.json' if args.anatomy else 'human-rounded-provenance.json')).write_text(json.dumps(evidence,indent=2))
    print(json.dumps({k:v for k,v in evidence.items() if k in ['rounding','selected_source_vertices','fixed_source_vertices']},indent=2))

if __name__ == '__main__':
    main()
