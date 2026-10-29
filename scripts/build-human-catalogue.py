"""Build a local human wearable/action worklist without copying source artwork.

Run CharacterCoverage.gd first. Raw MUL availability is recorded separately
from DEF/UOP resolution and from modern mesh/animation quality.
"""
import argparse,json,re,csv,struct,hashlib,html,collections,importlib.util
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def sha(path):
 with path.open('rb') as source:return hashlib.file_digest(source,'sha256').hexdigest()
def number(s):return int(s,0) if s.lower().startswith('0x') else int(s)
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--data-dir',type=Path);args=ap.parse_args()
 data=args.data_dir
 if data is None:data=Path(json.loads((ROOT/'Server/runtime/Configuration/modernuo.json').read_text())['dataDirectories'][0])
 out=ROOT/'outputs/human-catalogue';out.mkdir(parents=True,exist_ok=True)
 coverage=json.loads((ROOT/'outputs/third-dawn/character-port-coverage.json').read_text())
 registry=json.loads((ROOT/'Viewer/Presentation/human-animation-catalogue.json').read_text())
 groups=registry['groups'];assert [r['id'] for r in groups]==list(range(35))
 actions=coverage['server_action_playback']['classic_replacements']
 horse_ready=bool(coverage.get('horse_mounts',{}).get('available',False))
 for row in groups:
  row['replacement']=actions.get(str(row['id']),'')
  row['playback']='connected category' if row['replacement'] else 'pending'
  if 23<=row['id']<=29:row['playback']=('connected horse-mounted category' if horse_ready else 'deferred mounted rider; human clip prepared') if row['replacement'] else 'deferred mounted rider'
 equipconv={}
 conv=data/'equipconv.def'
 if conv.exists():
  for line in conv.read_text(errors='replace').splitlines():
   fields=line.split('#')[0].strip(' "\t').split()
   try:
    if len(fields)>=3:equipconv[(number(fields[0]),number(fields[1]))]=number(fields[2])
   except ValueError:pass
 equipment_types=set()
 for line in (data/'mobtypes.txt').read_text(errors='replace').splitlines():
  fields=line.split('#')[0].split()
  if len(fields)>=2 and fields[1]=='EQUIPMENT':equipment_types.add(int(fields[0]))
 idx=(data/'anim.idx').read_bytes();mul=data/'anim.mul';mul_size=mul.stat().st_size
 def slots(body,group):
  result=[]
  if body not in {400,401}|equipment_types:return result
  with mul.open('rb') as source:
   for direction in range(5):
    entry=35000+(body-400)*175+group*5+direction
    if entry<0 or entry*12+12>len(idx):continue
    position,length,extra=struct.unpack_from('<iiI',idx,entry*12)
    if position<0 or length<516 or position+length>mul_size:continue
    source.seek(position+512);count=struct.unpack('<I',source.read(4))[0]
    if 0<count<=2000 and 516+count*4<=length:result.append({'direction':direction,'frames':count})
  return result
 wearables=[];matrix=[]
 def family(name):
  name=name.lower()
  for key,terms in [('headwear',['hat','cap','helmet','helm','bandana','bonnet','skullcap']),('shirts_and_torso',['shirt','doublet','tunic','surcoat','chest','bustier','bodice','vest']),('skirts_and_robes',['skirt','kilt','robe','dress','gown']),('legwear',['pants','legging','shorts','hakama']),('footwear',['shoe','boot','sandal','thigh boot']),('cloaks',['cloak','cape']),('hands_and_arms',['glove','gauntlet','sleeve','arm']),('neck_and_jewellery',['neck','gorget','bracelet','ring','earring']),('shields',['shield','buckler']),('ranged',['bow','crossbow']),('weapons_and_tools',['sword','blade','axe','hammer','spear','staff','sceptre','mace','dagger','pitchfork','pole','knife','halberd','cleaver','club']),('hair_and_beards',['hair','beard','moustache'])]:
   if any(t in name for t in terms):return key
  return 'needs_classification'
 for record in coverage['wearables']['records']:
  row=dict(record)
  for field in ['id','source_animation_reference']:row[field]=int(row[field])
  row['family']=family(row['name']);row['scope']='human candidate; race restrictions need class audit'
  if any(t in row['name'].lower() for t in ['gargish','gargoyle','wing armor']):row['scope']='non-human; excluded from current implementation'
  row['replacement']='category mesh' if row['status']=='category replacement' else 'pending'
  row['priority']=1 if row['replacement']=='pending' and row['scope'].startswith('human') else 2
  row['male_anim_ref']=equipconv.get((400,row['source_animation_reference']),row['source_animation_reference'])
  row['female_anim_ref']=equipconv.get((401,row['source_animation_reference']),row['source_animation_reference'])
  wearables.append(row)
 cache={}
 for row in wearables:
  for group in groups:
   references=[row['male_anim_ref'],row['female_anim_ref']]
   native=[]
   for ref in references:
    key=ref,group['id']
    if key not in cache:cache[key]=slots(*key)
    native.append(cache[key])
   matrix.append({'graphic':row['id'],'name':row['name'],'family':row['family'],'group':group['id'],'action':group['native_group'],'scope':row['scope'],'mesh':row['replacement'],'current_parts':row['current_parts'],'motion':group['replacement'] or 'pending','primary_mul_male_directions':len(native[0]),'primary_mul_female_directions':len(native[1]),'validation':'pending per-item/action review; family pose checks are not individual item fidelity'})
 files=[]
 for path in sorted(data.iterdir()):
  if re.fullmatch(r'(anim[2-5]?\.(idx|mul)|Animation(Frame\d+|Sequence)\.uop|bodyconv\.def|equipconv\.def|Anim[12]\.def|mobtypes\.txt)',path.name,re.I):files.append({'name':path.name,'bytes':path.stat().st_size,'sha256':sha(path)})
 body_slots=[{'body':body,'group':g['id'],'directions':slots(body,g['id'])} for body in [400,401] for g in groups]
 spec=importlib.util.spec_from_file_location('human_sequences',ROOT/'scripts/uo-human-sequences.py');seq=importlib.util.module_from_spec(spec);spec.loader.exec_module(seq)
 # Tile animation references are not automatically human equipment. Restrict
 # the UOP scan to the installed client's declared equipment type and bodies.
 candidate_refs={row['male_anim_ref'] for row in wearables}|{row['female_anim_ref'] for row in wearables}
 allowed={400,401}|(candidate_refs & equipment_types)
 sequences=seq.inspect(data/'AnimationSequence.uop',allowed) if (data/'AnimationSequence.uop').exists() else []
 extended=[]
 for record in sequences:
  for mode in record['modes']:
   for action in mode['new_protocol_actions']:
    replacement=coverage['server_action_playback']['new_replacements'].get('%d:%d'%(action['type'],action['subaction']),'')
    extended.append({'animation_ref':record['animation_ref'],'mode':mode['mode'],'fallback_mode':mode['fallback_mode'],'type':action['type'],'subaction':action['subaction'],'native_groups':'|'.join(map(str,action['groups'])),'replacement':replacement,'status':'generic type/subaction mapping; mode/variation fidelity needs review' if replacement else 'pending'})
 (out/'human-uop-sequences.json').write_text(json.dumps({'records':sequences,'scope':'Embedded human/equipment references; no monster or animal families. Unknown or unsupported tails remain explicit parse blockers.'},indent=2))
 report={'scope':registry['scope'],'source_catalog':coverage['source_catalog'],'reference':registry['reference'],'archives':files,'human_actions':groups,'body_primary_mul':body_slots,'wearables':wearables,'matrix_rows':len(matrix),'counts':{'indexed_wearables':len(wearables),'category_mapped':sum(r['replacement']!='pending' for r in wearables),'human_classic_groups':35,'connected_groups':sum(r['playback'].startswith('connected') for r in groups),'groups_with_replacements':sum(bool(r['replacement']) for r in groups),'mounted_groups_deferred':0 if horse_ready else 7,'mounted_groups_connected':7 if horse_ready else 0,'mounted_replacement_clips':sum(23<=r['id']<=29 and bool(r['replacement']) for r in groups),'on_foot_groups':28,'on_foot_connected':sum(not 23<=r['id']<=29 and bool(r['replacement']) for r in groups),'mount_gameplay':'native ordinary horses' if horse_ready else 'deferred','uop_sequence_records':len(sequences),'uop_sequence_parse_blockers':sum('parse_blocker' in row or row['unparsed_bytes']!=0 for row in sequences)},'limits':['Primary MUL slot counts are structural evidence, not the final DEF/UOP precedence result.','AnimationSequence metadata is separately decoded; unknown tails stay explicit. AnimationFrame UOP archives are inventoried, not claimed as converted.','Indexed wearable graphics are not a complete census of server item classes or racial eligibility.','No monster/animal action families are catalogued or replaced here.','Category mesh, per-item fidelity, native playback and garment/contact QA are separate work states.']}
 report['extended_actions']=extended
 report['counts']['replacement_group_percent']=100*report['counts']['groups_with_replacements']/35
 report['counts']['on_foot_percent']=100*report['counts']['on_foot_connected']/28
 report['counts']['wearable_percent']=100*report['counts']['category_mapped']/len(wearables)
 report['counts']['uop_mode_action_rows']=len(extended)
 report['counts']['uop_body_action_rows']=sum(r['animation_ref'] in [400,401] for r in extended)
 report['counts']['uop_equipment_action_rows']=sum(r['animation_ref'] not in [400,401] for r in extended)
 report['equipment_categories']=coverage['equipment_categories']
 report['counts']['equipment_categories']=len(report['equipment_categories'])
 report['limits'].append('Opaque sequence fields remain uninterpreted. Mode/fallback meanings follow reference comments; generic playback does not establish mode/variation fidelity.')
 (out/'human-port-catalogue.json').write_text(json.dumps(report,indent=2))
 def save(name,rows):
  with (out/name).open('w',newline='',encoding='utf-8-sig') as f:
   writer=csv.DictWriter(f,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
 save('human-animation-groups.csv',groups);save('human-wearables.csv',wearables);save('wearable-action-matrix.csv',matrix)
 if extended:save('human-extended-actions.csv',extended)
 esc=lambda s:html.escape(str(s))
 def table(rows,columns):return '<table><thead><tr>'+''.join('<th>'+esc(c.replace('_',' ').title())+'</th>' for c in columns)+'</tr></thead><tbody>'+''.join('<tr>'+''.join('<td>'+esc(r.get(c,''))+'</td>' for c in columns)+'</tr>' for r in rows)+'</tbody></table>'
 page='<!doctype html><html><meta charset="utf-8"><title>Britannia Reborn - Human port catalogue</title><style>body{font:16px system-ui;margin:30px;background:#f4f1e9;color:#182f3b}h1,h2{font-weight:650}table{border-collapse:collapse;width:100%;background:white}th,td{text-align:left;vertical-align:top;padding:9px;border-bottom:1px solid #ddd}th{position:sticky;top:0;background:#203b49;color:white}input{font:inherit;padding:12px;width:95%;margin:14px 0}.limits{max-width:1100px}nav a{margin-right:24px}tr[hidden]{display:none}</style><h1>Human wearables and animation worklist</h1><p>Players and human NPCs. Native references and hues stay authoritative. Category art does not mean an exact original-item replacement.</p><nav><a href="#actions">35 human action groups</a><a href="#extended">Extended actions</a><a href="#wearables">Wearables</a><a href="wearable-action-matrix.csv">Full per-item/action CSV</a><a href="human-port-catalogue.json">Evidence JSON</a></nav><h2 id="actions">Original human animation groups</h2>'+table(groups,['id','label','replacement','playback','quality','note'])+'<h2 id="extended">Installed human sequence mode/type/subaction rows</h2><p>These are native metadata rows, not separate converted motion clips. Generic playback mappings still need mode and variation review.</p>'+table(extended,['animation_ref','mode','type','subaction','native_groups','replacement','status'])+'<h2 id="wearables">Indexed wearable graphics</h2><input id="filter" placeholder="Filter by name, family, graphic or status"><section id="items">'+table(wearables,['id','name','family','layer','replacement','current_parts','scope','male_anim_ref','female_anim_ref'])+'</section><h2>Scope and evidence limits</h2><ul class="limits">'+''.join('<li>'+esc(x)+'</li>' for x in report['limits'])+'</ul><script>document.querySelector("#filter").addEventListener("input",e=>{let q=e.target.value.toLowerCase();for(let row of document.querySelectorAll("#items tbody tr"))row.hidden=!row.textContent.toLowerCase().includes(q)})</script></html>'
 page=page.replace('<h1>Human wearables and animation worklist</h1>','<h1>Human wearables and animation worklist</h1><p><strong>%d / %d indexed graphics mapped • %d equipment categories • %d / 35 classic groups connected</strong></p>'%(report['counts']['category_mapped'],len(wearables),len(report['equipment_categories']),report['counts']['connected_groups']))
 page=page.replace('%d / 35 classic groups connected'%report['counts']['connected_groups'],'%d / 35 prepared human replacements; %d / 28 on-foot groups connected; %d mounted actions connected'%(report['counts']['groups_with_replacements'],report['counts']['on_foot_connected'],report['counts']['mounted_groups_connected']))
 (out/'index.html').write_text(page,encoding='utf-8');print('HUMAN CATALOGUE',json.dumps(report['counts']),len(matrix),'item/action rows')
if __name__=='__main__':main()
