"""Extract and bake the hash-pinned local Restless Soul comparison motions."""

import argparse
import json
from pathlib import Path
import runpy
import subprocess

HERE = Path(__file__).resolve().parent
PREPARE = runpy.run_path(str(HERE / 'prepare-khaldun-doom.py'))
ROOT, BASE, checked = (PREPARE[key] for key in ('ROOT', 'BASE', 'checked'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--extractor', type=Path, help='Path to the reviewed local unshield CLI')
    args = parser.parse_args()
    manifest = json.loads((HERE / 'restless-soul-donor-inputs.json').read_text(encoding='utf-8'))
    source = BASE / 'restless-soul-pinned-donors'
    if args.extractor:
        cabinet = BASE / 'container'
        for name, digest in manifest['cabinet_files'].items():
            checked(cabinet / name, digest)
        source.mkdir(parents=True, exist_ok=True)
        names = [Path(entry['member']).name for entry in manifest['members']]
        subprocess.run([str(args.extractor.resolve()), '-j', '-g', 'Client', '-d', str(source),
                        'x', str(cabinet / 'data1.cab'), *names], cwd=ROOT, check=True)
    pins = json.loads(PREPARE['MANIFEST'].read_text(encoding='utf-8'))
    members = {name: checked(BASE / 'khaldun-doom-source' / name, digest)
               for name, digest in pins['files'].items()}
    pipeline = PREPARE['TOOLS']['TOOLS']['pipeline']()
    ghost, clips, _ = PREPARE['ghost_model'](pipeline, members, pins['ghost_motions'])
    atlas = pipeline.td.png_from_tga(members[PREPARE['GHOST_ATLAS']].read_bytes())
    hover = []
    for entry in manifest['members']:
        raw = checked(source / 'Client' / Path(entry['member']).name, entry['sha256']).read_bytes()
        assert len(raw) == entry['bytes'] and len(entry['repairs']) <= 1
        animation = pipeline.td.parse(raw, animations_only=True, scene_root_names=True, scale_shear_tracks=True,
                                      auxiliary_scene_leaf=next(iter(entry['repairs']), None))
        animation, _ = pipeline.normalise_bind(raw, animation)
        label = entry['label']
        assert label not in clips
        clips[label], _ = pipeline.helper.match_animation(animation, ghost)
        assert len(clips[label]['tracks']) == entry['tracks']
        if label.startswith('Horse_'):
            hover.append(label)
    out = PREPARE['ART'] / 'restless-soul-comparison-library.gltf'
    result = pipeline.td.export_gltf(ghost, clips, atlas, out, 1.8, floor_sample_rate=120,
                                     preserve_hover_clips=tuple(hover))
    assert len(result['clips']) == 42
    print('RESTLESS SOUL DONORS: 42 clips from the pinned local archive')


if __name__ == '__main__':
    main()
