"""Stage explicit Khaldun Classic routes without modifying either active registry."""

import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'Viewer/local-art/creatures'
BASE = ART / 'khaldun_doom/preparation.json'
OUTPUT = ART / 'khaldun_actions/preparation.json'
GHOST = {
    9: 'GhostSlashOneHand', 12: 'GhostBashTwoHand', 13: 'GhostSlashTwoHand',
    14: 'GhostPierceTwoHand', 16: 'GhostCastDirected', 17: 'GhostCastArea',
    30: 'GhostTurn', 32: 'GhostBow', 33: 'GhostSalute',
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def stage(decode=False):
    inspector = runpy.run_path(str(ROOT / 'scripts/inspect-creature-mul-frames.py')) if decode else None
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    models = read(BASE)['models']
    assert [row['bodies'][0]['body'] for row in models] == [637, 970]
    for row in models:
        body = row['bodies'][0]['body']
        actions = row['classic_action_categories']
        additions = ({int(slot): 'Death2' if slot == '22' else f'Reconstructed{slot}'
                      for slot, clip in actions.items() if not clip} if body == 637 else GHOST)
        frames = {}
        for slot, clip in additions.items():
            key = str(slot)
            assert actions[key] == ''
            source, = (item for item in ledger['original_mul_group_candidates']
                       if (item['body'], item['group']) == (body, slot) and 'matching_classic_route' in item)
            directions = {}
            with (data / source['archive']).open('rb') as archive:
                for direction in source['directions']:
                    archive.seek(direction['offset'])
                    payload = archive.read(direction['bytes'])
                    assert hashlib.sha256(payload).hexdigest() == direction['payload_sha256']
                    count = direction['frames']
                    if inspector is not None:
                        assert len(inspector['decode'](payload, count)) == count
                    directions[direction['direction']] = count
            # The installed scimitar group 11 has four stored views.
            assert set(directions) == set(range(4 if (body, slot) == (637, 11) else 5))
            count, = set(directions.values())
            assert 1 <= count <= 20
            frames[key] = count
            actions[key] = clip
        row['action_witness_frames'] = frames
        row['family'] = 'khaldun_actions'
        if body == 637:
            renderer = 'Presentation/SpectralArmourVisual.gd'
            row['art_dependency_sha256'][row['presentation_script']] = row['presentation_script_sha256']
            row['presentation_script'] = 'res://' + renderer
            row['presentation_script_sha256'] = sha(ROOT / 'Viewer' / renderer)
        for treatment, old in row['assets'].items():
            original = ROOT / 'Viewer' / old.removeprefix('res://')
            assert sha(original) == row['asset_sha256'][treatment]
            new = OUTPUT.parent / (original.stem + '.scn')
            row['assets'][treatment] = 'res://' + new.relative_to(ROOT / 'Viewer').as_posix()
            row['asset_sha256'][treatment] = sha(new)
    return {
        'input_manifest_sha256': sha(ROOT / 'scripts/khaldun-doom-inputs.json'),
        'base_preparation_sha256': sha(BASE),
        'bake_sha256': sha(ROOT / 'scripts/bake-khaldun-actions.gd'),
        'models': models,
    }


if __name__ == '__main__':
    report = stage(decode=True)
    temporary = OUTPUT.with_suffix('.pending')
    temporary.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    temporary.replace(OUTPUT)
    print('KHALDUN ACTIONS: 35 candidate routes checked against every stored Classic direction')
