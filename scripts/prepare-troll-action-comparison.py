#!/usr/bin/env python3
"""Export an archived Troll comparison for Attack and Fidget2."""

import argparse
import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'work/creatures/late-client-inputs/troll-action-trial'
FIDGET2_SHA = '387142caf0dd1af9e1f731948f9438a4bff32ccbaac3d519cf96dc23562d9fb9'
FORMS = {53: 'trolls_troll', 55: 'trolls_troll_frost'}
CLIPS = {
    'Idle': 'idle', 'Walk': 'walk', 'Run': 'run', 'Attack': 'attack1',
    'Hit': 'gethit', 'Death': 'die1', 'Fidget': 'fidget', 'Fidget2': 'fidget2',
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='Local extracted Third Dawn Models directory')
    source = parser.parse_args().source
    importer = runpy.run_path(str(ROOT / 'scripts/import-third-dawn.py'))
    pins = {}

    def read(member):
        data = (source / member).read_bytes()
        pins[member] = hashlib.sha256(data).hexdigest()
        return data

    clips = {}
    for clip, stem in CLIPS.items():
        member = f'Monsters/trolls_troll_{stem}.grn'
        data = read(member)
        if clip == 'Fidget2' and pins[member] != FIDGET2_SHA:
            raise ValueError('Unexpected archived Fidget2 member')
        clips[clip] = importer['parse'](data, animations_only=True)

    OUTPUT.mkdir(parents=True, exist_ok=True)
    report = {}
    for body, kind in FORMS.items():
        mesh = importer['parse'](read(f'Monsters/{kind}_lod2.grn'))
        atlas, = mesh['textures']
        texture = importer['png_from_tga'](read(f'Maps/{atlas}'))
        if len(mesh['bones']) != 38:
            raise ValueError(f'Unexpected source rig for Troll body {body}')
        z = [vertex[2] for vertex in mesh['points']]
        height = 1.2 * (max(z) - min(z))
        report[body] = importer['export_gltf'](
            mesh, clips, texture, OUTPUT / f'troll-{body}.gltf', height, floor_sample_rate=120)
        fit = report[body]['clips']['Fidget2']
        if fit['matched_tracks'] != 35 or fit['missing']:
            raise ValueError(f'Archived Fidget2 did not fully match Troll body {body}')
    (OUTPUT / 'source-proof.json').write_text(json.dumps({'inputs': pins, 'bodies': report}, indent=2) + '\n')
    print('Troll comparison: 35 Fidget2 tracks matched both original 38-joint rigs.')


if __name__ == '__main__':
    main()
