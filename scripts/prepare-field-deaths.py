"""Pin the separately fitted Classic Hind and Rat collapses."""

import argparse
import hashlib
import json
from pathlib import Path
import runpy
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
FAMILY = 'field_deaths'
CLASSES = {237: ['Hind', 'EnragedHind'], 238: ['Rat']}
VISUAL = 'Presentation/FieldClassicCollapseVisual.gd'
RAT_SOURCE = 'ae58cfc3162b428e452aa56466d7973470ab692db962ab55fcea13d3162a108a'
RAT_BASE_ASSET = 'Art/Creatures/Rat/rat-fidgets.scn'
RAT_PUBLIC_ASSET = 'Art/Creatures/Rat/rat-deaths.scn'
REFERENCES = {
    237: {8: '8d014d2b1c7ebfd8f3f6bac17af119cb847def1aa95bfedf8f28d39375845cc8',
          12: '50ca5361851f93ec6e748697a4a010ca3749353ae7c90b4a710ae2d0504c1644'},
    238: {8: '863cd3c69f79471d85550b252decc3ae5bb8b470db8acee348c3839161944c7c',
          12: '1f026bcde688d7cb26f5524b48b29809a1e92b9782db44e391db7a43b6842aaa'},
}


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepared(private=None):
    if private is None:
        private = read(VIEWER / 'local-art/creatures/accepted-index.json')['entries']
    public = read(VIEWER / 'Art/Creatures/index.json')['entries']
    hind, = (row for row in private if row['kind'] == 'deer_doe' and row['status'] == 'validated')
    rat, = (row for row in public if row['kind'] == 'rat_ordinary' and row['status'] == 'validated')
    installed = rat['assets'] == {'modern': 'res://' + RAT_PUBLIC_ASSET}
    assert hind['classic_gesture_native_sha256'] and (installed or rat['assets'] == {'modern': 'res://' + RAT_BASE_ASSET})
    bake = read(VIEWER / 'local-art/creatures/field-death-bake.json')
    assert bake['recipe'] == sha(ROOT / 'scripts/bake-field-deaths.gd')
    assert bake['solver'] == sha(VIEWER / 'Presentation/WaterElementalFidgets.gd')
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    candidates = []
    for body, base in ((237, hind), (238, rat)):
        assert (body == 238 and installed) or not base['classic_action_categories'].keys() & {'8', '12'}
        evidence = {str(slot): reference(ledger, body, slot, ('anim.mul', body, 6, digest))
                    for slot, digest in REFERENCES[body].items()}
        assets, scenes = {}, {}
        for treatment in ('original', 'rounded', 'modern'):
            name = treatment if body == 237 else 'modern'
            source = VIEWER / (base['assets'][name].removeprefix('res://') if body == 237 else RAT_BASE_ASSET)
            source_hash = sha(source)
            assert source_hash == (base['asset_sha256'][name] if body == 237 else RAT_SOURCE)
            output = f'local-art/creatures/field-death-{body}-{name}.scn'
            scenes[treatment] = sha(VIEWER / output)
            assert bake['bodies'][str(body)][name] == {'source': source_hash, 'scene': scenes[treatment]}
            assets[treatment] = 'res://' + output
        routes = {'8': 'Death2', '12': 'Death'} if body == 237 else {'8': 'Death', '12': 'Death2'}
        description = ('Rear and settled roll fitted from Classic group 8' if body == 237
                       else 'Low front collapse fitted from Classic group 12')
        candidates.append(dict(base, family=FAMILY, status='prepared', assets=assets,
                               presentation_script='res://' + VISUAL, collapse_renderer_sha256=sha(VIEWER / VISUAL),
                               authored_action_scene_sha256=scenes, authored_action_reference=evidence['8'],
                               classic_motion_references=evidence, native_extra_classic_actions=[8, 12],
                               classic_action_categories=base['classic_action_categories'] | routes,
                               authored_replacements=base['authored_replacements'] | {'Death2': description}))
    return candidates, CLASSES


def write_rat_bundle(public, row, native_hash=None):
    asset = public / 'Rat/rat-deaths.scn'
    provenance = public / 'Rat/deaths-provenance.json'
    index = public / 'index.json'
    assert not asset.exists() and not provenance.exists()
    source = VIEWER / row['assets']['modern'].removeprefix('res://')
    digest = row['authored_action_scene_sha256']['modern']
    assert sha(source) == digest and row['kind'] == 'rat_ordinary'
    previous = index.read_bytes()
    data = read(index)
    old, = (entry for entry in data['entries'] if entry['kind'] == 'rat_ordinary')
    assert old['assets'] == {'modern': 'res://' + RAT_BASE_ASSET}
    installed = dict(row, status='validated', family=old['family'], assets={'modern': 'res://' + RAT_PUBLIC_ASSET})
    for field in ('native_extra_classic_actions', 'authored_action_scene_sha256', 'authored_action_reference'):
        del installed[field]
    data['entries'][data['entries'].index(old)] = installed
    newline = '\r\n' if b'\r\n' in previous else '\n'
    next_index = (json.dumps(data, indent=2) + '\n').replace('\n', newline).encode()
    pending = index.with_suffix('.rat-deaths.pending')
    try:
        shutil.copyfile(source, asset)
        assert sha(asset) == digest
        provenance.write_text(json.dumps({
            'license': 'GPL-3.0-or-later; underlying br-n518 Rat assets CC0-1.0',
            'predecessor': 'provenance.json',
            'scene_sha256': digest,
            'source_sha256': RAT_SOURCE,
            'renderer_sha256': row['collapse_renderer_sha256'],
            'native_receipt_sha256': native_hash,
            'classic_references': row['classic_motion_references'],
            'interpretation': 'Authored low collapse on the licensed rig from visual reference. No original game artwork is included.',
        }, indent=2) + '\n', encoding='utf-8')
        assert index.read_bytes() == previous
        pending.write_bytes(next_index)
        pending.replace(index)
        if native_hash is not None:
            subprocess.run([sys.executable, '-B', str(ROOT / 'scripts/test-rat-distribution.py')], check=True)
    except (Exception, KeyboardInterrupt):
        if index.read_bytes() == next_index:
            pending.write_bytes(previous)
            pending.replace(index)
        asset.unlink(missing_ok=True)
        provenance.unlink(missing_ok=True)
        raise


def install_rat():
    gate = runpy.run_path(str(ROOT / 'scripts/accept-classic-gestures.py'))
    index = read(gate['INDEX'])
    baseline, _ = gate['checked'](index, True, FAMILY)
    rows, _ = prepared(baseline)
    rat, = (row for row in rows if row['kind'] == 'rat_ordinary')
    native = ROOT / 'work/creatures' / FAMILY / 'accepted-native/live.json'
    write_rat_bundle(VIEWER / 'Art/Creatures', rat, sha(native))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--install-rat', action='store_true', required=True)
    parser.parse_args()
    install_rat()
