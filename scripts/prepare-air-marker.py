"""Preserve and inspect the original air marker without inventing actor clips."""
import hashlib,importlib.util,json,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'work/creatures/air';OUT.mkdir(parents=True,exist_ok=True)
spec=importlib.util.spec_from_file_location('air_source',ROOT/'scripts/audit-creature-sources.py');audit=importlib.util.module_from_spec(spec);spec.loader.exec_module(audit)
archive=ROOT/'work/third-dawn/uotdb.zip'
with archive.open('rb') as source:assert hashlib.file_digest(source,'sha256').hexdigest()==audit.ARCHIVE_HASH
with zipfile.ZipFile(archive) as z:
    mesh='uotdb/uotd/Models/Monsters/elementals_air_elemental_lod2.grn';texture='uotdb/uotd/Particles/air_sparkle1.tga'
    names={n.lower():n for n in z.namelist()};texture=names[texture.lower()]
    raw=z.read(mesh);model=audit.td.parse(raw);image=z.read(texture)
    (OUT/'original-marker-ir.json').write_text(json.dumps(model,indent=2)+'\n')
    (OUT/'original-sparkle.png').write_bytes(audit.td.png_from_tga(image))
    bounds=[(min(p[i] for p in model['points']),max(p[i] for p in model['points'])) for i in range(3)]
    report={'archive_sha256':audit.ARCHIVE_HASH,'member':mesh,'mesh_sha256':hashlib.sha256(raw).hexdigest(),'texture_member':texture,'texture_sha256':hashlib.sha256(image).hexdigest(),'points':len(model['points']),'polygons':len(model['polygons']),'bones':[b['name'] for b in model['bones']],'source_bounds':bounds,'interpretation':'Retained original two-bone marker/atlas only. No actor locomotion, particle binding or original death timing established. Proprietary source data stays ignored.'}
    report['skin_weights']=len(model['weights']);report['rigid_ties']=model['ties']
    if len(model['weights'])==len(model['points']) and bounds[2][1]-bounds[2][0]>1e-8:
        report['marker_export']=audit.td.export_gltf(model,{},audit.td.png_from_tga(image),OUT/'original-marker.gltf',.2)
        report['export_interpretation']='Explicit 0.2m inspection scale; no invented Idle or other actor clips. Original quad/UV/rig retained.'
    else:
        rigid_spec=importlib.util.spec_from_file_location('air_rigid',ROOT/'scripts/creature-rigid-parts.py');rigid=importlib.util.module_from_spec(rigid_spec);rigid_spec.loader.exec_module(rigid)
        linked,parts,links=rigid.read_rigid_parts(raw,audit.td,excluded_names=())
        report['rigid_link_evidence']=links
        report['marker_export']=audit.td.export_gltf(linked,{},audit.td.png_from_tga(image),OUT/'original-marker.gltf',.2)
        report['export_interpretation']='Explicit 0.2m inspection scale. One rigid influence expresses the exact declared source object/joint/tie link; no invented source skin or actor animation. Original bind-world points/UVs retained.'
    (OUT/'original-marker-evidence.json').write_text(json.dumps(report,indent=2)+'\n');print('ORIGINAL AIR MARKER: preserved quad/UVs/declared rigid binding; no recovered actor animation; see',OUT/'original-marker-evidence.json')
