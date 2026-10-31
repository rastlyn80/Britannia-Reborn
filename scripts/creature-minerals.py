"""Pinned CC0 mineral surfaces on unchanged source creature UVs and rigs."""
import base64,copy,hashlib,json
from pathlib import Path

# Source ore identities remain separate; these are authored material choices.
RECIPES={
    'elementals_earth_elemental':('rock_face_03','977346',0.,.76,.98),
    'elementals_agapite_elemental':('rusty_metal_02','c89b83',.72,.34,.65),
    'elementals_bronze_elemental':('rusty_metal_02','aa7844',.78,.34,.62),
    'elementals_copper_dull_elemental':('rusty_metal_02','776953',.65,.42,.72),
    'elementals_copper_elemental':('rusty_metal_02','ba764a',.78,.34,.62),
    'elementals_iron_elemental':('rusty_metal_02','939899',.8,.34,.64),
    'elementals_valorite_elemental':('rusty_metal_02','758cba',.75,.34,.65),
    'elementals_verite_elemental':('rusty_metal_02','82996b',.72,.36,.66)
}

def digest(raw):return hashlib.sha256(raw).hexdigest()

def apply(kind,gltf,row,root,art):
    if kind not in RECIPES:return gltf
    source,colour,metal,low,high=RECIPES[kind]
    manifest=root/'Viewer/Art/Surfaces/manifest.json'
    entry=next(r for r in json.loads(manifest.read_text(encoding='utf-8'))['sets'] if r['id']==source)
    assert entry['license']=='CC0-1.0' and entry['source'].startswith('https://polyhaven.com/a/')
    assert {m['role'] for m in entry['maps']}=={'albedo','normal','roughness'}
    maps={};dependencies=row.setdefault('art_dependency_sha256',{})
    for item in entry['maps']:
        assert Path(item['file']).name==item['file']
        raw=(manifest.parent/item['file']).read_bytes()
        assert digest(raw)==item['sha256'],'Mineral map differs from its pinned CC0 input'
        target=art/'minerals'/source/item['file'];target.parent.mkdir(parents=True,exist_ok=True)
        if not target.exists() or digest(target.read_bytes())!=item['sha256']:target.write_bytes(raw)
        relative=target.relative_to(art).as_posix();maps[item['role']]=relative;dependencies[relative]=item['sha256']
    surface={'source_set':source,'source':entry['source'],'license':entry['license'],'license_url':entry['licenseUrl'],
             'authors':entry['authors'],'manifest_sha256':digest(manifest.read_bytes()),'recipe_sha256':digest(Path(__file__).read_bytes()),'maps':maps,
             'map_receipts':entry['maps'],'colour':colour,'metallic':metal,'roughness_range':[low,high],
             'normal_strength':.55,'uv_scale':1.,
             'interpretation':'Pinned photographic maps on original UVs. Authored mineral palette/metal response, not a recovered Third Dawn material. UV-space mapping follows the skinned mesh.'}
    row['mineral_surface']=surface;row['surface']='Pinned CC0 photographic mineral PBR maps'
    row['generation_mode']='CC0 photographic PBR maps; authored palette and reflectance'
    row.pop('exact_prompt',None)
    row['modern_atlas']=str((art/maps['albedo']).relative_to(root));row['atlas_sha256']=dependencies[maps['albedo']]
    result=copy.deepcopy(gltf)
    result['images'][0]['uri']='data:image/jpeg;base64,'+base64.b64encode((art/maps['albedo']).read_bytes()).decode()
    # A real normal texture makes the glTF importer generate proper tangents.
    image=len(result['images']);result['images'].append({'uri':'data:image/jpeg;base64,'+base64.b64encode((art/maps['normal']).read_bytes()).decode()})
    texture=len(result['textures']);result['textures'].append({'source':image,'sampler':0})
    srgb=[int(colour[i:i+2],16)/255 for i in [0,2,4]]
    linear=[value/12.92 if value<=.04045 else ((value+.055)/1.055)**2.4 for value in srgb]
    for material in result['materials']:
        material['normalTexture']={'index':texture,'scale':surface['normal_strength']}
        material['pbrMetallicRoughness'].update(metallicFactor=metal,roughnessFactor=(low+high)/2,
                                              baseColorFactor=[min(1.,value*3.) for value in linear]+[1.])
    return result
