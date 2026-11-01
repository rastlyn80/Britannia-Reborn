"""Prepare selected preserved forms without activating unrelated family members.

All original inputs and derived results stay local. Acceptance is separate.
The existing strict importer, source model table and native census are retained.
"""
import argparse,hashlib,importlib.util,json,re,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('kinds',nargs='+');args=parser.parse_args()
    assert all(re.fullmatch(r'[a-z][a-z0-9_]+',k) for k in args.kinds),'Expected explicit source stems'
    assert len(set(args.kinds))==len(args.kinds),'Duplicate selected source form'
    families={k.split('_')[0] for k in args.kinds};assert len(families)==1,'One source family per bounded preparation'
    family=next(iter(families));spec=importlib.util.spec_from_file_location('selected_creature_import',ROOT/'scripts/prepare-creatures.py');pipeline=importlib.util.module_from_spec(spec);spec.loader.exec_module(pipeline)
    for index in [ROOT/'Viewer/local-art/creatures/accepted-index.json',ROOT/'Viewer/Art/Creatures/index.json']:
        if not index.exists():continue
        accepted=json.loads(index.read_text(encoding='utf-8-sig'))
        retained={r['kind'] for r in accepted['entries'] if r.get('status')=='validated' and r['family']==family}
        assert retained<=set(args.kinds),'Include existing accepted family forms to preserve their preparation evidence: '+', '.join(sorted(retained-set(args.kinds)))
    previous=pipeline.OUTPUT/family/'preparation.json'
    if previous.exists():
        raw=previous.read_bytes();digest=hashlib.sha256(raw).hexdigest()
        history=ROOT/'work/creatures/preparation-history'/family/(digest+'.json')
        if not history.exists():history.parent.mkdir(parents=True,exist_ok=True);history.write_bytes(raw)
    archive=ROOT/'work/third-dawn/uotdb.zip'
    with archive.open('rb') as file:assert hashlib.file_digest(file,'sha256').hexdigest()==pipeline.helper.audit.ARCHIVE_HASH
    with zipfile.ZipFile(archive) as z:
        names={n.lower():n for n in z.namelist()};table=z.read(names['uotdb/uotd/models/models.txt']);rows=pipeline.table_rows(table)
        assert all(any(r['stem']==kind for r in rows) for kind in args.kinds),'Selected kind lacks an explicit source model-table identity'
        selected=set(args.kinds)
        # Select exported targets while retaining donor meshes, textures and
        # clips for the unchanged source-link and explicit reuse contracts.
        _,native=pipeline.native_bodies();result=pipeline.prepare(family,z,names,rows,native,selected_kinds=selected)
    assert {r['kind'] for r in result}==selected,'Preparation must contain exactly the requested source forms'
    path=pipeline.OUTPUT/family/'preparation.json';report=json.loads(path.read_text(encoding='utf-8'))
    for record in report['models']:
        if record['kind']=='walking_dead_zombie':
            record.update(contact_kind='source_biped',head_bone='bip01 head',camera_height=1.35)
        if record['kind']=='serpents_snake_giant':
            record.update(movement_mode='ground_plane',head_bone='bip01 head',camera_height=.45,
                          pick_bounds={'position':[-2.1,-.02,-4.25],'size':[4.1,1.,7.1]},
                          pick_bounds_scope='Conservative union of measured Idle/Walk/Run source skins; not precise per-triangle picking or attack/death sweep.')
    report.update(selected_kinds=args.kinds,selection_recipe_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),selection_scope='Only the explicit requested source meshes; unmodified strict source importer/table/native mappings. Not accepted presentation or native evidence.')
    path.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    assert all(r['status']=='prepared' for r in result),'Unprepared selected source form; inspect its recorded blocker'
    print('SELECTED CREATURE CANDIDATE:',', '.join(args.kinds),'; no accepted routes installed')
if __name__=='__main__':main()
