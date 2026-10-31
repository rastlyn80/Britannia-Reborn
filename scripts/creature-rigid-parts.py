"""Bounded rigid-part recovery for old multi-mesh Granny actors.

Mesh object IDs resolve through the file's object table. Texture groups resolve
through declared bone ties, not the unrelated mesh/table storage orders.
The strict shared single-mesh reader remains unchanged.
"""
import base64,copy,math,re,struct

def join_parts(rig,parts,texture_tables,reader,excluded_names=()):
    result=copy.deepcopy(rig)
    result.update(points=[],normals=[],uv_sets=[[]],polygons=[],texture_polygons=[],weights=[])
    by_name={bone['name']:i for i,bone in enumerate(rig['bones'])};report=[]
    reader.require(len(by_name)==len(rig['bones']),'Ambiguous rigid skeleton')
    for part in parts:
        name=part['name'];reader.require(name in by_name,'Rigid object has no exact source joint: '+name)
        for vector in part['points']:reader.finite(vector)
        if name not in excluded_names:
            reader.require(all(vector is not None for vector in part['normals']),'Non-finite body-part normal')
            for vector in part['normals']:reader.finite(vector)
        bone=by_name[name];ties=[i for i,index in enumerate(rig['ties']) if index==bone]
        reader.require(len(ties)==1,'Rigid joint needs one declared bone tie')
        tie=ties[0];uv=part['uv_sets'][-1];faces=part['polygons'];textures=texture_tables.get(tie,[])
        reader.require(len(faces)==len(textures),'Rigid texture group does not cover the linked mesh')
        reader.require(all(max(face[:3])<len(part['points']) and max(face[3:])<len(part['normals']) for face in faces),'Rigid triangle outside its mesh')
        reader.require(all(max(face)<len(uv) for face in textures),'Rigid UV index outside its table')
        part['texture_polygons']=[list(face) for face in textures]
        report.append({'object_id':part['object_id'],'name':name,'bone':bone,'bone_tie':tie,
                       'points':len(part['points']),'triangles':len(faces),'body_included':name not in excluded_names,
                       'body_face_start':len(result['polygons']) if name not in excluded_names else None})
        if name in excluded_names:continue
        po,no,uo=len(result['points']),len(result['normals']),len(result['uv_sets'][0])
        result['points'].extend(part['points']);result['normals'].extend(part['normals']);result['uv_sets'][0].extend(uv)
        result['polygons'].extend(tuple(i+po for i in f[:3])+tuple(i+no for i in f[3:]) for f in faces)
        result['texture_polygons'].extend(tuple(i+uo for i in f) for f in textures)
        result['weights'].extend([[(tie,1.)] for _ in part['points']])
    reader.require(result['points'] and result['polygons'],'No visible rigid actor geometry')
    return result,report

def append_death_flash(gltf,parts,report):
    """Attach the recovered unlit effect to its original joint, outside body bounds."""
    flash=next(part for part in parts if part['name']=='flash_plane')
    binding=next(part for part in report if part['name']=='flash_plane')
    bone=binding['bone'];result=copy.deepcopy(gltf)
    if result['nodes'][result['skins'][0]['joints'][bone]]['name']!='flash_plane':raise ValueError('Flash joint changed during export')
    positions=[];uv=[]
    for face,tex in zip(flash['polygons'],flash['texture_polygons'],strict=True):
        for corner in range(3):
            positions.append(flash['points'][face[corner]])
            uv.append(flash['uv_sets'][-1][tex[corner]][:2])
    if not positions or not all(math.isfinite(x) for v in positions+uv for x in v):raise ValueError('Invalid recovered flash geometry')
    body=bytearray(base64.b64decode(result['buffers'][0]['uri'].split(',',1)[1]))
    def accessor(values,width,kind,component=5126):
        while len(body)%4:body.append(0)
        start=len(body);fmt='f' if component==5126 else 'H'
        body.extend(struct.pack('<'+fmt*(len(values)*width),*(x for v in values for x in v)))
        view=len(result['bufferViews']);result['bufferViews'].append({'buffer':0,'byteOffset':start,'byteLength':len(body)-start,'target':34962})
        index=len(result['accessors']);result['accessors'].append({'bufferView':view,'componentType':component,'count':len(values),'type':kind,
            'min':[min(v[i] for v in values) for i in range(width)],'max':[max(v[i] for v in values) for i in range(width)]})
        return index
    attrs={'POSITION':accessor(positions,3,'VEC3'),'TEXCOORD_0':accessor(uv,2,'VEC2'),
           'JOINTS_0':accessor([[bone,0,0,0]]*len(positions),4,'VEC4',5123),'WEIGHTS_0':accessor([[1.,0.,0.,0.]]*len(positions),4,'VEC4')}
    material=len(result['materials']);result['materials'].append({'name':'Recovered death flash','doubleSided':True,'alphaMode':'BLEND',
        'extensions':{'KHR_materials_unlit':{}},'pbrMetallicRoughness':{'baseColorTexture':{'index':0},'baseColorFactor':[1.,1.,1.,.15],'metallicFactor':0.,'roughnessFactor':1.}})
    result.setdefault('extensionsUsed',[])
    if 'KHR_materials_unlit' not in result['extensionsUsed']:result['extensionsUsed'].append('KHR_materials_unlit')
    mesh=len(result['meshes']);result['meshes'].append({'name':'RecoveredFlash','primitives':[{'attributes':attrs,'material':material,'mode':4}]})
    node=len(result['nodes']);result['nodes'].append({'name':'RecoveredFlash','mesh':mesh,'skin':0});result['nodes'][1]['children'].append(node)
    result['buffers'][0].update(byteLength=len(body),uri='data:application/octet-stream;base64,'+base64.b64encode(body).decode())
    return result,{'triangles':len(positions)//3,'source_joint':'flash_plane','bone':bone,'separate_mesh':True,
                   'uv_rect':[min(v[0] for v in uv),min(v[1] for v in uv),max(v[0] for v in uv),max(v[1] for v in uv)],
                   'normals':'Unlit surface omits normals; original invalid normal bits remain in recovered IR.','surface':'Authored additive flash interpretation on recovered geometry and original joint motion.'}

def separate_materials(gltf,parts,levels):
    """Share vertex buffers; draw rigid steel and source dust with separate materials."""
    if levels not in [0,1,2]:raise ValueError('Unsupported rigid subdivision level')
    result=copy.deepcopy(gltf);primitive=result['meshes'][0]['primitives'][0]
    vertices=result['accessors'][primitive['attributes']['POSITION']]['count']
    groups=[[],[]];factor=4**levels
    for part in parts:
        if not part['body_included']:continue
        target=1 if part['name'].startswith('blade_spirit_gas_') else 0
        start=part['body_face_start']*factor*3;count=part['triangles']*factor*3
        groups[target].extend(range(start,start+count))
    if sorted(groups[0]+groups[1])!=list(range(vertices)) or not all(groups):
        raise ValueError('Rigid material ranges do not cover the exported triangles exactly')
    body=bytearray(base64.b64decode(result['buffers'][0]['uri'].split(',',1)[1]));primitives=[]
    for material,indices in enumerate(groups):
        while len(body)%4:body.append(0)
        start=len(body);width=2 if vertices<=65536 else 4;component=5123 if width==2 else 5125
        body.extend(struct.pack('<'+('H' if width==2 else 'I')*len(indices),*indices))
        view=len(result['bufferViews']);result['bufferViews'].append({'buffer':0,'byteOffset':start,'byteLength':len(body)-start,'target':34963})
        accessor=len(result['accessors']);result['accessors'].append({'bufferView':view,'componentType':component,'count':len(indices),'type':'SCALAR'})
        primitives.append(dict(primitive,indices=accessor,material=material))
    original=copy.deepcopy(result['materials'][0]);weapon=copy.deepcopy(original);dust=copy.deepcopy(original)
    weapon['name']='Rigid weapon surfaces';dust['name']='Recovered dust surfaces'
    weapon['pbrMetallicRoughness'].update(metallicFactor=.85,roughnessFactor=.4)
    dust['pbrMetallicRoughness'].update(metallicFactor=0.,roughnessFactor=.9)
    result['materials']=[weapon,dust];result['meshes'][0]['primitives']=primitives
    result['buffers'][0].update(byteLength=len(body),uri='data:application/octet-stream;base64,'+base64.b64encode(body).decode())
    return result

def read_rigid_parts(raw,reader,excluded_names=('flash_plane',)):
    entries=list(reader.chunks(raw));texts=[];objects=[];key=None;meshes=[];current=None;tables={};texture_group=None
    for tag,payload,parents in entries:
        root=parents[0] if parents else None
        if tag==0xca5e0200:
            reader.require(len(payload)>=8,'Truncated rigid string table')
            count=struct.unpack_from('<I',payload)[0];strings=payload[8:].split(b'\0')
            reader.require(count<len(strings),'Unterminated rigid string table')
            texts.append([v.decode('latin1').lower() for v in strings[:count]])
        elif tag==0xca5e0f00 and root==0xca5e0f03:objects.append({})
        elif tag==0xca5e0f01 and root==0xca5e0f03:
            reader.require(len(payload)==4,'Invalid rigid object key');key=struct.unpack('<I',payload)[0]
        elif tag==0xca5e0f02 and root==0xca5e0f03:
            reader.require(len(payload)==8 and objects and key is not None,'Invalid rigid object property')
            objects[-1][key]=struct.unpack('<II',payload)[1]
        if tag==0xca5e0601:
            current={'points':[],'normals':[],'uv_sets':[],'polygons':[],'object_id':None};meshes.append(current)
        if 0xca5e0601 in parents:
            reader.require(current is not None,'Rigid data without mesh')
            if tag in [0xca5e0801,0xca5e0802,0xca5e0803]:
                vector_data=payload
                if tag==0xca5e0803:
                    reader.require(len(payload)>=4 and struct.unpack_from('<I',payload)[0]==3,'Unsupported rigid vector width')
                    vector_data=payload[4:]
                reader.require(len(vector_data)%12==0,'Truncated rigid vectors')
                vectors=list(struct.iter_unpack('<3f',vector_data))
                if tag==0xca5e0802:
                    invalid={str(i):list(struct.unpack_from('<3I',vector_data,i*12)) for i,v in enumerate(vectors) if not all(math.isfinite(x) for x in v)}
                    if invalid:
                        current['invalid_normal_bits']=invalid
                        vectors=[None if str(i) in invalid else v for i,v in enumerate(vectors)]
                else:
                    for vector in vectors:reader.finite(vector)
                if tag==0xca5e0803:current['uv_sets'].append(vectors)
                else:
                    slot='points' if tag==0xca5e0801 else 'normals'
                    reader.require(not current[slot],'Duplicate rigid vector table');current[slot]=vectors
            elif tag==0xca5e0901:
                reader.require(len(payload)%24==0,'Truncated rigid faces')
                current['polygons'].extend(struct.iter_unpack('<6I',payload))
            elif tag==0xca5e0702:
                reader.require(payload==bytes(12),'Dedicated rigid reader does not accept skinned meshes')
                current['rigid_header']=True
            elif tag==0xca5e0f04:
                reader.require(len(payload)==4 and current['object_id'] is None,'Ambiguous rigid mesh object')
                current['object_id']=struct.unpack('<I',payload)[0]
        if tag==0xca5e0e02:
            reader.require(len(payload)==8,'Invalid rigid texture group')
            texture_group,count=struct.unpack('<II',payload);reader.require(count==1,'Multiple rigid texture materials need a separate adapter')
        elif tag==0xca5e0e06:
            reader.require(texture_group is not None and len(payload)>=4,'Rigid texture faces have no group')
            count=struct.unpack_from('<I',payload)[0]
            reader.require(count>0 and len(payload)-4 in [count*16,count*28],'Unsupported rigid texture-face layout')
            width=(len(payload)-4)//count//4
            tables.setdefault(texture_group,[]).extend(tuple(row[2::2] if width==7 else row[1:]) for row in struct.iter_unpack('<'+'I'*width,payload[4:]))
    reader.require(len(texts)==2,'Expected two rigid source string tables')
    strings=texts[1]
    reader.require(all(k<len(strings) and v<len(strings) for obj in objects for k,v in obj.items()),'Rigid object string outside table')
    params=[{strings[k]:strings[v] for k,v in obj.items()} for obj in objects]
    for mesh in meshes:
        object_id=mesh['object_id']
        reader.require(object_id is not None and 1<=object_id<=len(params),'Rigid object ID outside source table')
        reader.require(mesh.get('rigid_header') and mesh['uv_sets'],'Incomplete rigid mesh')
        reader.require('__objectname' in params[object_id-1],'Rigid mesh object has no name')
        mesh['name']=re.sub(r'[^a-z0-9_ -]','_',params[object_id-1]['__objectname'])
        reader.require(not mesh.get('invalid_normal_bits') or mesh['name'] in excluded_names,'Non-finite normal in a retained rigid body part')
    rig=reader.parse(raw,animations_only=True,scene_root_names=True,scale_shear_tracks=True)
    reader.require(len(set(rig['textures']))==1,'Rigid actor needs one traced atlas')
    model,report=join_parts(rig,meshes,tables,reader,excluded_names)
    return model,meshes,{'parts':report,'excluded_from_body':list(excluded_names),
        'scope':'All rigid meshes recovered. Explicit object-name/joint and bone-tie/texture-group links. Source bind-world points retained and assigned one rigid influence. Excluded effect parts remain in the recovered IR; this alone is not animated/render/native acceptance.'}
