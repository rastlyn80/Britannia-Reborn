"""Stage an opt-in Ice161 candidate; never change the accepted registry."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'work/creatures/ice-elemental'
ART=ROOT/'Viewer/local-art/creatures'
KIND='elementals_ice_elemental'

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    subprocess.run([sys.executable,'-B',str(ROOT/'scripts/check-source-ice-elemental.py')],check=True,cwd=ROOT)
    prep_path=WORK/'prepared/preparation.json'
    prep=json.loads(prep_path.read_text(encoding='utf-8'))
    row=prep['models'][0]
    accepted=ART/'accepted-index.json';accepted_pin=sha(accepted)
    folder=ART/'ice_elementals';folder.mkdir(parents=True,exist_ok=True)
    files=list(prep['assets_sha256'])+[KIND+'-ground.json']
    assets={}
    for name in files:
        assert Path(name).name==name
        source=WORK/'prepared'/name;target=ART/name
        shutil.copyfile(source,target);assert sha(source)==sha(target)
        assets[name]=sha(target)
    script='res://Presentation/SourceIceElementalVisual.gd'
    row.update(presentation_script=script,presentation_script_sha256=sha(ROOT/'Viewer/Presentation'/Path(script).name),
               ground_lookup='res://local-art/creatures/'+KIND+'-ground.json',
               art_dependency_sha256={KIND+'-original-albedo.png':assets[KIND+'-original-albedo.png']},
               loop_categories=['Idle','Walk','Run','Fidget'],appearance_pose_fit=True,camera_height=1.45,
               surface_scope='Authored opaque dielectric ice coat/UV relief on original diffuse; no recovered shader, mask interpretation, refraction or rendered acceptance.',
               pending_features='Opt-in candidate only: actual saved import, avatar/actions/hues/picking/corpses, timed terrain/death, native gameplay and rendering require their own current evidence.')
    row['motion_bound_diagonal_m']=max(c['measured_max_pose_diagonal_m'] for stats in row['stats'].values() for c in stats['clips'].values())*1.1
    report={'models':[row],'source_preparation_sha256':sha(prep_path),'source_ground_sha256':assets[KIND+'-ground.json'],
            'assets_sha256':assets,'stage_recipe_sha256':sha(Path(__file__)),
            'scope':'Private staged candidate, no accepted-index edit, no original or derived artwork redistribution.'}
    (folder/'candidate.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    assert sha(accepted)==accepted_pin
    print('ICE161 CANDIDATE STAGED: source art/curves pinned; accepted registry untouched')

if __name__=='__main__':main()
