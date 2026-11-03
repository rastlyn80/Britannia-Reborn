"""Stage distinct native identities sharing an already accepted original asset."""
import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT/'Viewer/local-art/creatures'
TABLE = ROOT/'work/creatures/late-client-inputs/model-table/Client/Models.txt'
OUTPUT = ART/'source_reused_variants/preparation.json'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def expected():
    spec = importlib.util.spec_from_file_location('reuse_source', ROOT/'scripts/prepare-creatures.py')
    pipeline = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(pipeline)
    pin, native = pipeline.native_bodies()
    rows = pipeline.table_rows(TABLE.read_bytes())
    target = next(row for row in rows if row['body'] == 189)
    donor = next(row for row in json.loads((ART/'accepted-index.json').read_text())['entries'] if row['kind'] == target['stem'])
    assert donor['status'] == 'validated' and target['animation_body'] == 138
    row = copy.deepcopy(donor)
    for name in list(row):
        if name.startswith(('validation_', 'gpu_', 'import_')):row.pop(name)
    row.update(kind='orcs_orc_brute',family='orcs',status='prepared',
               presentation_script='res://Presentation/SourceScaledCreatureVisual.gd',
               asset_base_scale=donor['bodies'][0]['scale'],
               assets={treatment:pipeline_asset(donor,treatment) for treatment in ['original','rounded','modern']},
               bodies=[dict(target,native_profile=pipeline.body_profiles()[189],native_sources=native[189])],
               source_interpretation='Original Third Dawn model table189 explicitly reuses orcs_orc_lord and animation138. The accepted source mesh, atlas, rig and clips are shared unchanged; native target3.5/3/3.5 is applied relative to the baked donor1.2/1.2/1.2. This is not a newly recovered distinct brute mesh.',
               native_validation='Actual isolated constructor body189 checked separately; no native-live/AI/combat/loot certification.',
               remaining_fidelity=['Native throw/spawn-minion/combat/loot behaviour','Continuous cadence/terrain/spawn and final art/LOD/crowds'])
    row['presentation_script_sha256'] = sha(ROOT/'Viewer/Presentation/SourceScaledCreatureVisual.gd')
    report={'family':'source_reused_variants','models':[row],'server_pin':pin,
            'model_table_sha256':sha(TABLE),'preparer_sha256':sha(Path(__file__)),
            'donor_record_sha256':hashlib.sha256(json.dumps(donor,sort_keys=True).encode()).hexdigest(),
            'asset_sha256':{path:sha(ROOT/'Viewer'/path.removeprefix('res://')) for path in row['assets'].values()},
            'scope':'Private prepared native189 reuse; no accepted route, source asset modification or new native-live witness.'}
    return report


def pipeline_asset(donor,treatment):
    return donor.get('assets',{}).get(treatment,'res://local-art/creatures/'+donor['kind']+'-'+treatment+'.gltf')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check-prepared',action='store_true')
    args = parser.parse_args()
    report = expected()
    if args.check_prepared:
        assert json.loads(OUTPUT.read_text()) == report, 'Reused-source candidate is stale'
    else:
        OUTPUT.parent.mkdir(parents=True,exist_ok=True)
        OUTPUT.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('SOURCE REUSE: native189 uses its declared original donor with explicit baked/target scales; donor unchanged')


if __name__ == '__main__':
    main()
