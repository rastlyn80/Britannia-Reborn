"""Bounded source-first creature imports; art and source-derived tables stay local.

The archived model table supplies explicit mesh/animation links. A prepared mesh
is not activated by this tool: runtime approval requires separate pose/GPU tests.
"""
import argparse, base64, copy, hashlib, importlib.util, json, math, re, struct, subprocess, zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT/'scripts'/filename)
    result = importlib.util.module_from_spec(spec); spec.loader.exec_module(result)
    return result

helper = module('creature_helpers', 'prepare-distinct-mounts.py')
td, smooth = helper.td, helper.smooth
affine=module('creature_affine','creature-affine.py')
repairs=module('creature_source_repairs','creature-source-repairs.py')
reuse=module('creature_source_reuse','creature-source-reuse.py')
rigid=module('creature_rigid_parts','creature-rigid-parts.py')
minerals=module('creature_minerals','creature-minerals.py')
humanoid_actions=module('creature_humanoid_actions','creature-humanoid-actions.py')
OUTPUT = ROOT/'Viewer/local-art/creatures'
LABELS = {'idle':'Idle','walk':'Walk','run':'Run','attack1':'Attack','attack2':'Attack2',
          'attack3':'Attack3','gethit':'Hit','die1':'Death','die2':'Death2','fidget':'Fidget',
          'eat':'Eat','alert':'Alert','liedown':'LieDown','cast':'Cast','cast2':'Cast2',
          'cast3':'Cast3','fly':'Fly','takeoff':'TakeOff','land':'Land','gethitinair':'HitInAir',
          'attackbow':'AttackBow','attackxbow':'AttackXBow','attackthrow':'AttackThrow',
          'pillage':'Pillage','stomp':'Stomp','blockright':'BlockRight','blockleft':'BlockLeft',
          'attack':'Attack','die':'Death','spell':'Cast'}
HEIGHTS = {'bruins':1.25,'canines':.88,'deer':1.5,'felines':.9,'porcines':.72,
           'ruminants':.9,'rodents':.55,'walrus':1.05,'lizards':.75}

def digest(raw): return hashlib.sha256(raw).hexdigest()

def fold_uniform_scales(raw, model):
    """Fold exporter-only uniform bind scales into local translations.

    Reciprocal scene-root/pelvis units (notably the cats) otherwise produce
    enormous rotation arcs. Geometry/UVs/weights stay untouched, and the shared
    strict reader is unchanged. Genuine non-uniform/sheared rigs remain blocked.
    """
    matrices=[struct.unpack('<I16f',payload)[8:] for tag,payload,_ in td.chunks(raw) if tag==0xca5e0506]
    assert len(matrices)==len(model['bones'])
    scales=[]; changed=[]
    for i,matrix in enumerate(matrices):
        diagonal=[matrix[j] for j in [0,4,8]];scale=sum(diagonal)/3
        assert 1e-6<scale<1e6 and all(abs(v-scale)<max(1e-5,abs(scale)*1e-5) for v in diagonal),'Non-uniform bind scale needs full affine support'
        assert all(abs(matrix[j])<max(1e-5,abs(scale)*1e-5) for j in [1,2,3,5,6,7]),'Sheared bind matrix needs full affine support'
        if abs(scale-1.)<1e-5:scale=1.
        scales.append(scale)
        if scale!=1.:changed.append({'bone':model['bones'][i]['name'],'uniform_scale':scale})
    if not changed:return model,[]
    result=copy.deepcopy(model);global_scales={};visiting=set()
    def global_scale(i):
        if i in global_scales:return global_scales[i]
        assert i not in visiting,'Cyclic bind hierarchy'
        visiting.add(i);parent=result['bones'][i]['parent']
        value=scales[i]*(global_scale(parent) if parent!=i else 1.)
        visiting.remove(i);global_scales[i]=value;return value
    by_name={b['name']:i for i,b in enumerate(result['bones'])}
    for i,bone in enumerate(result['bones']):
        factor=global_scale(bone['parent']) if bone['parent']!=i else 1.
        bone['translation']=[v*factor for v in bone['translation']]
    for track in result['tracks']:
        i=by_name[track['name']];parent=result['bones'][i]['parent'];factor=global_scale(parent) if parent!=i else 1.
        track['translation']['values']=[[v*factor for v in value] for value in track['translation']['values']]
    return result,changed

def normalise_bind(raw,model):
    base_matrices=[struct.unpack('<I16f',payload)[8:] for tag,payload,_ in td.chunks(raw) if tag==0xca5e0506]
    by_name={b['name']:i for i,b in enumerate(model['bones'])}
    for track in model['tracks']:
        base=base_matrices[by_name[track['name']]]
        if any(max(abs(a-b) for a,b in zip(value,base))>1e-5 for value in track.get('scale_shear',{}).get('values',[])):
            return affine.neutralise(raw,model,td)
    try:return fold_uniform_scales(raw,model)
    except AssertionError as error:
        if 'Non-uniform' not in str(error) and 'Sheared' not in str(error):raise
        return affine.neutralise(raw,model,td)

def visible_vertices(model):
    used=sorted({i for face in model['polygons'] for i in face[:3]})
    omitted=sorted(set(range(len(model['points'])))-set(used))
    if not omitted:return model,[]
    result=copy.deepcopy(model);indices={old:new for new,old in enumerate(used)}
    result['points']=[model['points'][i] for i in used]
    result['weights']=[model['weights'][i] for i in used]
    result['polygons']=[tuple(indices[i] for i in face[:3])+tuple(face[3:]) for face in model['polygons']]
    return result,omitted

def authored_clip(idle, label):
    """Explicit category fallback on an existing rig, not a recovered clip."""
    result=copy.deepcopy(idle);duration=1.3 if label=='Death' else .8
    by_name={b['name']:i for i,b in enumerate(result['bones'])};global_q={}
    def orientation(i):
        if i in global_q:return global_q[i]
        b=result['bones'][i];q=td.unit(b['rotation'])
        if b['parent']!=i:q=td.qmul(orientation(b['parent']),q)
        global_q[i]=q;return q
    root_name='bip01' if 'bip01' in by_name else 'granny_master'
    for track in result['tracks']:
        name=track['name'];i=by_name[name];parent=result['bones'][i]['parent']
        pq=orientation(parent) if parent!=i else [0.,0.,0.,1.]
        inverse=[-pq[0],-pq[1],-pq[2],pq[3]]
        axis=td.rotate(inverse,[0.,1.,0.])
        for key in ['translation','rotation','scale']:
            stream=track.get(key)
            if not stream or not stream['values']:continue
            value=stream['values'][0];times=[duration*j/24 for j in range(25)]
            values=[]
            for j in range(25):
                u=j/24;amount=u*u*(3-2*u) if label=='Death' else math.sin(math.pi*u)
                angle=0.
                if name==root_name:angle=amount*(1.57079632679 if label=='Death' else -.12 if label=='Hit' else .15)
                elif label=='Attack' and 'spine2' in name:angle=amount*.22
                if key=='rotation' and angle:
                    half=angle/2;q=[v*math.sin(half) for v in axis]+[math.cos(half)]
                    values.append(list(td.qmul(q,value)))
                else:values.append(list(value))
            track[key]={'times':times,'values':values}
    return result

def body_profiles():
    source=ROOT/'Server/ModernUO/Distribution/Data/bodyTable.cfg'
    runtime=ROOT/'Server/runtime/Data/bodyTable.cfg'
    raw=source.read_bytes()
    assert raw.replace(b'\r\n',b'\n')==runtime.read_bytes().replace(b'\r\n',b'\n'),'Native body classification differs; audit the actual runtime table'
    return {int(f[0]):f[1].lower() for line in raw.decode('utf-8-sig').splitlines()
            if (f:=line.split()) and f[0].isdigit()}

def table_rows(raw):
    rows = []
    for line in raw.decode('cp1252').splitlines():
        f = line.split()
        if len(f)>=9 and f[0].isdigit() and f[1] in ['0','1','2']:
            row = {'body':int(f[0]),'type':int(f[1]),'animation_body':int(f[2]),
                   'scale':[float(v) for v in f[5:8]],'stem':f[8].lower()}
            if row not in rows: rows.append(row)
    return rows

def native_body_literals(text):
    """Bounded literal expressions only; never evaluate arbitrary game code."""
    text=re.sub(r'@"(?:""|[^"])*"|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|/\*.*?\*/|//[^\n]*','',text,flags=re.S)
    number=r'(?:0x[\dA-Fa-f]+|\d+)'
    assignment=r'\bBody\s*(?:=>|=(?![=>]))\s*'
    literals=re.findall(assignment+r'('+number+r')\s*;',text)
    for group in re.findall(r'\bBody\s*=\s*Utility.RandomList\(([^)]*)\)',text):
        if re.fullmatch(r'\s*'+number+r'(?:\s*,\s*'+number+r')*\s*',group):
            literals+=re.findall(number,group)
    for pair in re.findall(assignment+r'[^;?]+\?\s*('+number+r')\s*:\s*('+number+r')\s*;',text):
        literals.extend(pair)
    literals+=re.findall(r':\s*base\(\s*('+number+r')\s*,\s*0x3[Ee][\dA-Fa-f]{2}\b',text)
    return {int(value,16) if value.lower().startswith('0x') else int(value) for value in literals}

def native_bodies():
    server = ROOT/'Server/ModernUO'
    pin = json.loads((ROOT/'Server/dependencies.json').read_text())['modernuo']['revision']
    assert subprocess.check_output(['git','-C',str(server),'rev-parse','HEAD'],text=True).strip()==pin
    bodies = {}
    for path in (server/'Projects/UOContent/Mobiles').rglob('*.cs'):
        raw = path.read_bytes(); text = raw.decode('utf-8-sig',errors='replace')
        for body in sorted(native_body_literals(text)):
            bodies.setdefault(body,[]).append({'path':str(path.relative_to(server)), 'sha256':digest(raw)})
    return pin,bodies

def refreshed_identities(row,table,native,profiles):
    # Preserve explicit authored identities (for example the brown bear) when
    # refreshing a census; only declared native-alias recipes rebuild the list.
    identities=reuse.identities(row['kind'],table) if reuse.RECIPES.get(row['kind'],{}).get('native_aliases') else copy.deepcopy(row['bodies'])
    assert identities,'Metadata refresh lost an explicit source identity'
    for identity in identities:
        identity['native_sources']=native.get(identity['body'],[])
        identity['native_profile']=profiles.get(identity['body'],'')
    return identities

def prepare(family, z, names, rows, native):
    family_output = OUTPUT/family; family_output.mkdir(parents=True,exist_ok=True)
    members = sorted(n for n in names if n.endswith('_lod2.grn') and '/models/' in n
                    and any('/'+folder+'/' in n for folder in ['animals','monsters','seacreatures'])
                    and Path(n).name.split('_')[0]==family)
    meshes=[(n,Path(n).name.removesuffix('_lod2.grn')) for n in members]
    for kind,recipe in reuse.RECIPES.items():
        if kind.split('_')[0]!=family or 'source_stem' not in recipe:continue
        member=next(n for n in members if n.endswith('/'+recipe['source_stem']+'_lod2.grn'))
        meshes.append((member,kind))
    by_body = {r['body']:r for r in rows}; result = []; templates = {};profiles=body_profiles()
    for member,stem in meshes:
        source_stem=Path(member).name.removesuffix('_lod2.grn');recipe=reuse.RECIPES.get(stem,{})
        row = {'kind':stem,'family':family,'status':'blocked','inputs':[]}
        inputs = row['inputs']
        def read(name):
            key = names[name.lower()]; raw = z.read(key)
            record = {'member':key,'sha256':digest(raw)}
            if record not in inputs: inputs.append(record)
            return raw
        try:
            records = reuse.identities(stem,rows)
            if recipe:row['authored_source_reuse']=dict(recipe,method='Authored reuse of preserved source geometry/material/clip inputs; not a recovered intended model-table assignment.')
            if stem=='bruins_bear_brown': records = [{'body':167,'type':2,'animation_body':211,'scale':[1.2]*3,'stem':stem}]
            row['bodies'] = [dict(r,native_sources=native.get(r['body'],[]),native_profile=profiles.get(r['body'],'')) for r in records]
            assert records, 'No explicit model-table identity; needs an authored mapping'
            raw = read(member)
            try:
                if stem=='spirits_blade_spirit':
                    body,rigid_parts,row['rigid_import']=rigid.read_rigid_parts(raw,td)
                    part_path=family_output/(stem+'-rigid-parts.json')
                    part_path.write_text(json.dumps({'source_sha256':digest(raw),'parts':rigid_parts,'report':row['rigid_import']},indent=2,allow_nan=False))
                    row['recovered_rigid_parts']=str(part_path.relative_to(ROOT))
                    row['separate_source_effect']='Recovered flash-plane geometry/joint attached as a separate unlit death effect; actor floor/bounds exclude the effect'
                else:body = td.parse(raw,scene_root_names=True)
                row['normal_repair'] = None
            except ValueError as error:
                if stem=='ettins_ettin' and str(error)=='Unnormalised skin weights':
                    body,row['skin_weight_repair']=repairs.repair_one_unweighted_vertex(raw,td)
                    row['normal_repair']=None
                elif 'single-mesh' in str(error):
                    body=td.parse(raw,scene_root_names=True,skip_unskinned_helpers=True)
                    row['omitted_untextured_helper_boxes']=sum(tag==0xca5e0601 for tag,_,_ in td.chunks(raw))-1
                    row['normal_repair']=None
                else:body,row['normal_repair'] = helper.audit.repair_invalid_normals(raw,allow_coincident_seams=stem=='flails_swamp_tentacles')
            body,row['bind_scale_normalisation']=normalise_bind(raw,body)
            # Unreferenced exporter vertices are invisible but can sit below the
            # paws; they must not dictate the visible mesh's floor correction.
            body,row['omitted_unreferenced_vertices']=visible_vertices(body)
            donor=None
            if 'contract_stem' in recipe:
                reference=next(n for n in names if n.endswith('/'+recipe['contract_stem']+'_lod2.grn'))
                donor_raw=read(reference);donor=td.parse(donor_raw,scene_root_names=True)
                donor,_=normalise_bind(donor_raw,donor);donor,_=visible_vertices(donor)
                row['source_reuse_contract']=reuse.assert_exact_contract(body,donor)
            assert len(set(body['textures']))==1, 'Multiple source materials need a dedicated importer'
            if recipe.get('modern_atlas_stem'):
                assert donor is not None and len(set(donor['textures']))==1
                reference_atlas=next(n for n in names if n.endswith('/'+donor['textures'][0].lower()))
                reference_png=td.png_from_tga(read(reference_atlas))
                reference_path=OUTPUT/(stem+'-modern-reference-albedo.png');reference_path.write_bytes(reference_png)
                row['modern_atlas_reference']={'member':names[reference_atlas],'path':str(reference_path.relative_to(ROOT)),
                    'sha256':digest(reference_png),'contract_stem':recipe['modern_atlas_stem'],
                    'interpretation':'Authored fully feather-covered surface using an exact matching stone-harpy mesh/UV/rig donor; not a recovered living-harpy material. Original source atlas remains the comparison baseline.'}
            texture = next((n for n in names if n.endswith('/'+body['textures'][0].lower())),None)
            if texture:
                original = td.png_from_tga(read(texture))
                (OUTPUT/(stem+'-original-albedo.png')).write_bytes(original)
                row['source_atlas_status']='Recovered original atlas'
                if family in ['dragons','daemons','gargoyles','harpies','rat','lizard'] or stem=='spirits_blade_spirit':
                    row['source_alpha_texture']=stem+'-original-albedo.png'
                    row['art_dependency_sha256']={row['source_alpha_texture']:digest(original)}
                    if family=='rat':row['source_alpha_scope']='fine_edges'
            else:
                row['missing_source_atlas']=body['textures'][0]
                replacement=OUTPUT/(stem+'-albedo-v1.png')
                if 'atlas_stem' in recipe:
                    assert donor is not None and len(set(donor['textures']))==1
                    reference_atlas=next(n for n in names if n.endswith('/'+donor['textures'][0].lower()))
                    original=td.png_from_tga(read(reference_atlas))
                    row['atlas_reference']={'member':names[reference_atlas],'contract_stem':recipe['contract_stem']}
                    row['source_atlas_status']='Source map absent; exact-UV donor atlas used as a diagnostic baseline, not a recovered original map'
                    (OUTPUT/(stem+'-reference-albedo.png')).write_bytes(original)
                    if family=='daemons':
                        row['source_alpha_texture']=stem+'-reference-albedo.png'
                        row['art_dependency_sha256']={row['source_alpha_texture']:digest(original)}
                else:
                    assert replacement.exists(), 'Missing source atlas: '+body['textures'][0]
                    original=replacement.read_bytes()
                    assert original[:8]==b'\x89PNG\r\n\x1a\n','Expected authored replacement PNG'
                    row['source_atlas_status']='Source atlas absent; authored replacement used in all geometry comparisons, not a recovered original map'
            animation_stem = by_body.get(records[0]['animation_body'],records[0])['stem']
            clips, clip_sources, omitted, static_poses, rejected = {}, {}, {}, [], {}
            row['rejected_source_clips']=rejected
            row['clip_sources']=clip_sources
            for suffix,label in LABELS.items():
                stems=list(dict.fromkeys([stem,source_stem,recipe.get('clip_stem',animation_stem),animation_stem]))
                for seed in [stem,animation_stem]:
                    parts=seed.split('_')
                    for end in range(len(parts)-1,1,-1):
                        parent='_'.join(parts[:end])
                        if parent not in stems:stems.append(parent)
                candidates = [member.rsplit('/',1)[0]+'/'+s+'_'+suffix+'.grn' for s in stems]
                shared={'bruins':'bruins_bear_black','felines':'felines_panther'}
                if family in shared:candidates.append(member.rsplit('/',1)[0]+'/'+shared[family]+'_'+suffix+'.grn')
                if stem=='imps_shadow_fiend':
                    candidates.append(member.rsplit('/',1)[0]+'/imps_imp_'+suffix+'.grn')
                    row['authored_animation_reuse']='Explicit imp-clip reuse; rig-name/parent matching required, not an original model-table link'
                match = next((n for n in candidates if n in names),None)
                if match is None: continue
                animation_raw=read(match)
                try:
                    animation = td.parse(animation_raw,animations_only=True,scene_root_names=True,scale_shear_tracks=True,
                                         retained_bone_names=[b['name'] for b in body['bones']] if stem=='flails_reaper' else None)
                    animation,scale_repairs=normalise_bind(animation_raw,animation)
                except (ValueError,AssertionError,KeyError) as error:
                    rejected[label]={'member':names[match],'error':str(error)}
                    continue
                if not animation['tracks'] and label=='Idle':
                    # Some source idle files contain only the posed skeleton.
                    # Hold that documented source pose; do not invent idle motion.
                    animation['tracks']=[{'name':b['name'],
                        'translation':{'times':[0.,2.],'values':[b['translation'],b['translation']]},
                        'rotation':{'times':[0.,2.],'values':[b['rotation'],b['rotation']]}}
                        for b in animation['bones']]
                    static_poses.append(label)
                clips[label],omitted[label] = helper.match_animation(animation,body)
                if family=='dragons' and label in ['Death','Death2'] and stem not in ['dragons_dragon_asian','dragons_wyvern']:
                    clips[label],conversion=reuse.rescale_translation_units(clips[label],body)
                    row.setdefault('clip_unit_conversions',{})[label]=conversion
                assert clips[label]['tracks'], 'No matched animation tracks: '+match
                clip_sources[label] = names[match]
            aliases = {}
            if 'Idle' not in clips:
                source=next((key for key in ['Fidget','Walk','Run'] if key in clips),None)
                assert source,'No usable source resting/locomotion pose'
                clips['Idle']=authored_clip(clips[source],'Idle');aliases['Idle']='held first pose of '+source
            if 'Walk' not in clips:
                source='Run' if 'Run' in clips else 'Idle';clips['Walk']=copy.deepcopy(clips[source]);aliases['Walk']=source
            authored={}
            for label in ['Attack','Hit','Death']:
                if label not in clips:
                    clips[label]=authored_clip(clips['Idle'],label)
                    authored[label]='Authored bounded source-rig recoil/lunge/side-fall category from the source idle pose; not recovered original choreography'
            for target,source in [('Run','Walk'),('Fidget','Idle')]:
                if target not in clips: clips[target] = copy.deepcopy(clips[source]); aliases[target] = source
            if humanoid_actions.install(body,clips,authored,aliases,stem):
                row['authored_action_recipe']={'path':'scripts/creature-humanoid-actions.py','sha256':digest((ROOT/'scripts/creature-humanoid-actions.py').read_bytes())}
                row['new_action_categories']={'2':'Hit','5':'Fidget','14':'Pillage'}
            if family in ['dragons','lizards'] and 'Eat' not in clips:
                feeding=copy.deepcopy(clips['Idle']);by_name={b['name']:i for i,b in enumerate(feeding['bones'])};orientations={}
                def global_orientation(i):
                    if i not in orientations:
                        bone=feeding['bones'][i];q=td.unit(bone['rotation'])
                        orientations[i]=td.qmul(global_orientation(bone['parent']),q) if bone['parent']!=i else q
                    return orientations[i]
                necks=max(1,sum('neck' in b['name'] for b in feeding['bones']))
                for track in feeding['tracks']:
                    name=track['name'];q=global_orientation(by_name[name]);axis=td.rotate([-q[0],-q[1],-q[2],q[3]],[1.,0.,0.])
                    for key in ['translation','rotation']:
                        stream=track[key]
                        if not stream['values']:continue
                        value=stream['values'][0];times=[2.4*j/48 for j in range(49)];values=[]
                        for j in range(49):
                            u=j/48;amount=math.sin(math.pi*u)**2;angle=amount*(.3/necks if 'neck' in name else .05 if 'head' in name else 0.)
                            half=angle/2;delta=[v*math.sin(half) for v in axis]+[math.cos(half)]
                            values.append(list(td.qmul(value,delta)) if key=='rotation' else list(value))
                        track[key]={'times':times,'values':values}
                clips['Eat']=feeding;authored['Eat']='Authored source-rig neck/head feeding bend with deformed-mesh floor correction; not original choreography'
            height = HEIGHTS.get(family,(max(p[2] for p in body['points'])-min(p[2] for p in body['points']))*records[0]['scale'][2])
            if stem in ['bruins_bear_grizzly','bruins_bear_polar']: height = 1.45
            scale = height/(max(p[2] for p in body['points'])-min(p[2] for p in body['points']))
            strengths = []
            for pairs in body['weights']:
                labels = [body['bones'][body['ties'][tie]]['name'].lower() for tie,w in pairs if w>.2]
                strengths.append(0. if stem=='spirits_blade_spirit' and any(n.startswith('weapon_') for n in labels)
                                 else .05 if any(' foot' in n or ' hand' in n or 'finger' in n for n in labels)
                                 else .3 if any('head' in n or 'ponytail' in n for n in labels) else .8)
            levels = 2 if len(body['polygons'])<600 else 1
            refined, refinement = smooth.refine(body,levels=levels,maximum=min(.04,.035/scale),strengths=strengths,weight_smoothing=.12)
            modern_path = OUTPUT/(stem+'-albedo-v1.png')
            modern = modern_path.read_bytes() if modern_path.exists() else original
            if modern_path.exists():
                prompt_path=modern_path.with_suffix('.prompt.txt')
                assert prompt_path.exists(),'Authored atlas requires its exact saved prompt'
                row['exact_prompt']=prompt_path.read_text(encoding='utf-8-sig')
                row['generation_mode']='built-in imagegen exact-UV donor atlas edit' if row.get('atlas_reference') or row.get('modern_atlas_reference') else 'built-in imagegen technical UV guide replacement' if not texture else 'built-in imagegen source atlas edit'
                if not texture and not row.get('atlas_reference'):
                    guide=OUTPUT/(stem+'-uv-template.png')
                    assert guide.exists(),'Missing source map replacement needs its saved technical guide'
                    row['technical_guide']={'path':str(guide.relative_to(ROOT)),'sha256':digest(guide.read_bytes())}
            # Colour variants with exactly equal geometry, UVs, rigs and clips can
            # share computed deformation streams; atlas pixels remain independent.
            key = digest(json.dumps({'body':{k:v for k,v in body.items() if k!='textures'},'clips':clips,'height':height},sort_keys=True).encode())
            if family in ['gazers','genies']:
                row['movement_mode']='source_hover'
                row['hover_reference_m']=min(p[2] for p in body['points'])*scale
                row['hover_policy']='Source positive Z clearance retained; only ground penetration lifted. Death ends at its original negative underside and settles on the floor. Not arbitrary-terrain volume clearance.'
            stats = {}
            for treatment, mesh in [('original',body),('rounded',refined)]:
                output = OUTPUT/(stem+'-'+treatment+'.gltf')
                cache_key = (key,treatment)
                if cache_key in templates:
                    gltf, stats[treatment] = templates[cache_key]; gltf = copy.deepcopy(gltf)
                    gltf['images'][0]['uri'] = 'data:image/png;base64,'+base64.b64encode(original).decode()
                    output.write_text(json.dumps(gltf,separators=(',',':')))
                else:
                    stats[treatment] = td.export_gltf(mesh,clips,original,output,height,
                        floor_sample_rate=120 if family in ['dragons','daemons','lizards','gargoyles','gazers','genies','harpies'] or stem in ['flails_swamp_tentacles','centaurs_centaur','mongbats_mongbat','spirits_blade_spirit'] else 30,
                        preserve_vertical_clips=['Fly','TakeOff','Land','HitInAir'],
                        preserve_hover_clips=list(clips) if family in ['gazers','genies'] else ())
                    templates[cache_key] = (json.loads(output.read_text()),stats[treatment])
                stats[treatment]['bind_diagonal_m']=math.sqrt(sum(((max(p[i] for p in mesh['points'])-min(p[i] for p in mesh['points']))*scale)**2 for i in range(3)))
                if row.get('source_alpha_texture') or row.get('rigid_import'):
                    masked=json.loads(output.read_text())
                    if row.get('rigid_import'):masked=rigid.separate_materials(masked,row['rigid_import']['parts'],0 if treatment=='original' else levels)
                    for material in masked['materials']:material.update(alphaMode='MASK',alphaCutoff=.12)
                    if row.get('rigid_import'):
                        masked,row['death_effect']=rigid.append_death_flash(masked,rigid_parts,row['rigid_import']['parts'])
                    output.write_text(json.dumps(masked,separators=(',',':')))
            gltf = json.loads((OUTPUT/(stem+'-rounded.gltf')).read_text())
            gltf['images'][0]['uri'] = 'data:image/png;base64,'+base64.b64encode(modern).decode()
            (OUTPUT/(stem+'-modern.gltf')).write_text(json.dumps(gltf,separators=(',',':')))
            row.update(status='recovered_trial' if row.get('pending_render_feature') else 'prepared',stats=stats,refinement=refinement,clip_sources=clip_sources,
                       category_aliases=aliases,authored_replacements=authored,rejected_source_clips=rejected,static_source_poses=static_poses,omitted_animation_bones=omitted,
                       modern_atlas=str(modern_path.relative_to(ROOT)) if modern_path.exists() else None,
                       atlas_sha256=digest(modern),profile=profiles.get(records[0]['body']) or ('animal' if records[0]['type']==2 else 'sea' if records[0]['type']==1 else 'monster'),
                       surface='generated atlas' if modern_path.exists() else 'source atlas; new surface shader only')
            modern_gltf=OUTPUT/(stem+'-modern.gltf')
            modern_material=minerals.apply(stem,json.loads(modern_gltf.read_text(encoding='utf-8')),row,ROOT,OUTPUT)
            if row.get('mineral_surface'):modern_gltf.write_text(json.dumps(modern_material,separators=(',',':')),encoding='utf-8')
            print(stem,'RECOVERED TRIAL / pending material/effects' if row.get('pending_render_feature') else 'PREPARED',stats['rounded']['triangles'],'triangles',flush=True)
        except (ValueError,AssertionError,KeyError,IndexError,StopIteration) as error:
            row['blocker'] = str(error); print(stem,'BLOCKED:',error,flush=True)
        result.append(row)
        (family_output/'preparation.json').write_text(json.dumps({'family':family,'models':result,'archive_sha256':helper.audit.ARCHIVE_HASH,
            'recipe_sha256':digest(Path(__file__).read_bytes()),'scope':'Prepared source trials, not accepted/live coverage; proprietary-derived local art, no redistribution grant.'},indent=2),encoding='utf-8')
    return result

def main():
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--families',nargs='+',default=['bruins']); parser.add_argument('--refresh-atlases',action='store_true'); parser.add_argument('--refresh-metadata',action='store_true'); parser.add_argument('--skip-index',action='store_true'); parser.add_argument('--index-only',action='store_true'); args = parser.parse_args()
    OUTPUT.mkdir(parents=True,exist_ok=True)
    if args.refresh_metadata:
        profiles=body_profiles();pin,native=native_bodies()
        table=json.loads((OUTPUT/'source-index.json').read_text())['rows']
        for family in args.families:
            path=OUTPUT/family/'preparation.json';report=json.loads(path.read_text());before=copy.deepcopy(report)
            for row in report['models']:
                if 'bodies' not in row:continue
                row['bodies']=refreshed_identities(row,table,native,profiles)
                if row['status']=='prepared':row['profile']=profiles.get(row['bodies'][0]['body']) or row['profile']
            report['body_table_sha256']=digest((ROOT/'Server/ModernUO/Distribution/Data/bodyTable.cfg').read_bytes())
            if report!=before:path.write_text(json.dumps(report,indent=2),encoding='utf-8')
        return
    if args.refresh_atlases:
        for family in args.families:
            path=OUTPUT/family/'preparation.json'; report=json.loads(path.read_text())
            for row in report['models']:
                atlas=OUTPUT/(row['kind']+'-albedo-v1.png')
                if row['status']!='prepared' or not atlas.exists():continue
                raw=atlas.read_bytes();assert raw[:8]==b'\x89PNG\r\n\x1a\n'
                width,height=struct.unpack_from('>II',raw,16);assert width==height and 512<=width<=4096
                gltf=json.loads((OUTPUT/(row['kind']+'-rounded.gltf')).read_text())
                gltf['images'][0]['uri']='data:image/png;base64,'+base64.b64encode(raw).decode()
                (OUTPUT/(row['kind']+'-modern.gltf')).write_text(json.dumps(gltf,separators=(',',':')))
                row.update(modern_atlas=str(atlas.relative_to(ROOT)),atlas_sha256=digest(raw),surface='generated atlas',
                           exact_prompt=atlas.with_suffix('.prompt.txt').read_text(encoding='utf-8-sig'),
                           generation_mode='built-in imagegen exact-UV donor atlas edit' if row.get('atlas_reference') or row.get('modern_atlas_reference') else 'built-in imagegen technical UV guide replacement' if row.get('missing_source_atlas') else 'built-in imagegen source atlas edit')
            path.write_text(json.dumps(report,indent=2),encoding='utf-8')
        return
    archive = ROOT/'work/third-dawn/uotdb.zip'
    with archive.open('rb') as f: assert hashlib.file_digest(f,'sha256').hexdigest()==helper.audit.ARCHIVE_HASH
    pin,native = native_bodies()
    with zipfile.ZipFile(archive) as z:
        names = {n.lower():n for n in z.namelist()}
        table = z.read(names['uotdb/uotd/models/models.txt']); rows = table_rows(table)
        if not args.skip_index:
            (OUTPUT/'source-index.json').write_text(json.dumps({'archive_sha256':helper.audit.ARCHIVE_HASH,'table_sha256':digest(table),'server_pin':pin,'native_profiles':body_profiles(),
                'rows':rows,'native_literal_bodies':native,'native_scope':'Literal Body assignments, RandomList calls, simple conditional literal branches and base-mount constructors in Mobiles source; not exhaustive dynamic behavior.'},indent=2),encoding='utf-8')
        if args.index_only:return
        for family in args.families: prepare(family,z,names,rows,native)

if __name__=='__main__': main()
