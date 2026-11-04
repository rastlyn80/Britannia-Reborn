"""Validate the prepared Restless Soul on-foot candidate for the isolated fixture."""

import hashlib
import runpy
from pathlib import Path

HERE = Path(__file__).resolve().parent
SHARED = runpy.run_path(str(HERE / 'prepare-khaldun-actions.py'))
ROOT, ART, sha, read = (SHARED[key] for key in ('ROOT', 'ART', 'sha', 'read'))
FAMILY = 'restless_soul_actions'
SLOTS = {6, 7, 8, 9, 12, 13, 14, 15, 16, 17, 18, 19, 30, 31, 32, 33, 34}


def prepared():
    spectral, = (row for row in read(SHARED['OUTPUT'])['models'] if row['bodies'][0]['body'] == 637)
    base = read(SHARED['BASE'])['models'][1]
    row, = read(ART / FAMILY / 'preparation.json')['models']
    assert row['bodies'] == base['bodies'] and row['kind'] == base['kind']
    assert row['family'] == FAMILY and row['status'] == 'prepared'
    assert row['presentation_script'] == base['presentation_script']
    assert row['native_constructor_hues'] == base['native_constructor_hues']
    assert set(map(int, row['action_witness_frames'])) == SLOTS
    for key, value in base['classic_action_categories'].items():
        if int(key) not in SLOTS:
            assert row['classic_action_categories'][key] == value
        else:
            assert row['classic_action_categories'][key].startswith('Ghost')
    assert len({row['classic_action_categories'][str(slot)] for slot in SLOTS}) == len(SLOTS)
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    sources = {entry['group']: entry for entry in ledger['original_mul_group_candidates'] if entry['body'] == 970}
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    for slot in SLOTS:
        source = sources[slot]
        assert len(source['directions']) == 5
        with (data / source['archive']).open('rb') as archive:
            for direction in source['directions']:
                assert row['action_witness_frames'][str(slot)] == direction['frames']
                archive.seek(direction['offset'])
                assert hashlib.sha256(archive.read(direction['bytes'])).hexdigest() == direction['payload_sha256']
    for candidate in (spectral, row):
        pins = candidate['art_dependency_sha256'] | {
            candidate['presentation_script']: candidate['presentation_script_sha256'],
            **{path: candidate['asset_sha256'][treatment] for treatment, path in candidate['assets'].items()},
        }
        for path, digest in pins.items():
            resolved = (ROOT / 'Viewer' / path.removeprefix('res://')).resolve()
            assert resolved.is_relative_to(ROOT / 'Viewer') and sha(resolved) == digest
    ghost = dict(base, family=FAMILY, assets=row['assets'], asset_sha256=row['asset_sha256'],
                 classic_action_categories=row['classic_action_categories'],
                 action_witness_frames={key: int(value) for key, value in row['action_witness_frames'].items()})
    return [dict(spectral, family=FAMILY), ghost], {637: ['SpectralArmour'], 970: ['RestlessSoul']}
