"""Pin the split robe and seven exact mounted Classic slots for the local trial."""

import hashlib
import json
from pathlib import Path
import runpy

HERE = Path(__file__).resolve().parent
FOOT = runpy.run_path(str(HERE / 'prepare-restless-soul-actions.py'))
ROOT, ART, read, sha = (FOOT[key] for key in ('ROOT', 'ART', 'read', 'sha'))
FAMILY = 'restless_soul_mounted'
OUTPUT = ART / FAMILY / 'preparation.json'
SLOTS = {
    23: 'Horse_Walk', 24: 'Horse_Run', 25: 'Horse_Idle', 26: 'Horse_Attack1h_Slashright',
    27: 'Horse_Attackbow', 28: 'Horse_Attackcrossbow', 29: 'GhostUrgeMount',
}


def stage():
    rows, classes = FOOT['prepared']()
    spectral, ghost = rows
    ghost['family'] = FAMILY
    ghost['action_witness_frames'] = {}
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    sources = {row['group']: row for row in ledger['original_mul_group_candidates'] if row['body'] == 970}
    source_dir = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    for slot, label in SLOTS.items():
        source = sources[slot]
        frames, = {row['frames'] for row in source['directions']}
        assert len(source['directions']) == 5 and not ghost['classic_action_categories'][str(slot)]
        with (source_dir / source['archive']).open('rb') as archive:
            for row in source['directions']:
                archive.seek(row['offset'])
                payload = archive.read(row['bytes'])
                assert hashlib.sha256(payload).hexdigest() == row['payload_sha256']
        ghost['classic_action_categories'][str(slot)] = label
        ghost['action_witness_frames'][str(slot)] = frames
    mounted = {
        treatment: f'res://local-art/creatures/khaldun_doom/restless-soul-mounted-robe{suffix}-review.scn'
        for treatment, suffix in (('original', ''), ('rounded', '-rounded'), ('modern', '-rounded'))
    }
    ghost['mounted_assets'] = mounted
    ghost['mounted_asset_sha256'] = {name: sha(ROOT / 'Viewer' / path.removeprefix('res://'))
                                      for name, path in mounted.items()}
    ghost['art_dependency_sha256'][ghost['presentation_script']] = ghost['presentation_script_sha256']
    renderer = 'Presentation/RestlessSoulMountedVisual.gd'
    ghost['presentation_script'] = 'res://' + renderer
    ghost['presentation_script_sha256'] = sha(ROOT / 'Viewer' / renderer)
    return [dict(spectral, family=FAMILY), ghost], classes


def prepared():
    models, classes = stage()
    assert models == read(OUTPUT)['models'], 'Mounted robe or source inputs changed'
    return models, classes


if __name__ == '__main__':
    models, _ = stage()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    pending = OUTPUT.with_suffix('.pending')
    pending.write_text(json.dumps({'models': models}, indent=2) + '\n', encoding='utf-8')
    pending.replace(OUTPUT)
    print('RESTLESS SOUL MOUNTED: seven source slots and all three asset treatments pinned')
