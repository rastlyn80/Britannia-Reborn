"""Explicit authored source reuse; no guessed archive identity is called recovered."""
import copy,math,statistics

RECIPES={
    'dragons_dragon_blasted':{'identity_stem':'dragons_dragon_retro_grey','clip_stem':'dragons_wyrm_ancient','contract_stem':'dragons_wyrm_ancient'},
    'dragons_dragon_blasted_red':{'source_stem':'dragons_dragon_blasted','identity_stem':'dragons_dragon_retro_red','clip_stem':'dragons_wyrm_ancient','contract_stem':'dragons_wyrm_ancient'},
    'dragons_dragon_ice':{'identity_stem':'dragons_wyrm_retro_white','clip_stem':'dragons_wyrm_ancient','contract_stem':'dragons_wyrm_ancient','native_aliases':[180]},
    'daemons_daemon_exodus':{'atlas_stem':'daemons_daemon','contract_stem':'daemons_daemon'},
    'harpies_harpy':{'modern_atlas_stem':'harpies_harpy_stone','contract_stem':'harpies_harpy_stone'},
    'serpents_snake_giant':{'clip_stem':'serpents_snake_giant_silver','motion_contract_stem':'serpents_snake_giant_silver',
        'unbound_label_aliases':[['serpents_snake_giant','serpents_snake_giant_silver']]}
}
CONTRACT_FIELDS=['points','normals','polygons','texture_polygons','uv_sets','weights','ties','bones']

def identities(kind,table):
    stem=RECIPES.get(kind,{}).get('identity_stem',kind)
    result=copy.deepcopy([row for row in table if row['stem']==stem])
    for body in RECIPES.get(kind,{}).get('native_aliases',[]):
        if not result or any(row['body']==body for row in table):raise ValueError('Native alias needs an explicit missing-table identity')
        result.append(dict(copy.deepcopy(result[0]),body=body,identity_note='Authored reuse for the alternate native WhiteWyrm constructor body; not an original archive model-table row.'))
    return result

def assert_exact_contract(model,reference):
    for field in CONTRACT_FIELDS:
        if model[field]!=reference[field]:
            raise ValueError('Source reuse requires an exact mesh/rig/UV contract: '+field)
    return {'fields':CONTRACT_FIELDS.copy(),'method':'Exact equality after declared bind normalisation and removal of unreferenced mesh points; material filename alone may differ.'}

def assert_motion_contract(model,reference,unbound_label_aliases):
    """Validate source motion reuse without replacing a variant's UV atlas.

    A named, unweighted scene label may differ only when it is not an ancestor
    of any weighted joint. All skin geometry and skeletal transforms stay exact.
    """
    fields=['points','normals','polygons','texture_polygons','weights','ties']
    for field in fields:
        if model[field]!=reference[field]:raise ValueError('Motion reuse needs exact source skin geometry: '+field)
    if len(model['bones'])!=len(reference['bones']):raise ValueError('Motion reuse needs matching source bone counts')
    active=set()
    for vertex in model['weights']:
        for slot,weight in vertex:
            if weight<=0.:continue
            index=model['ties'][slot];seen=set()
            while index not in seen:
                seen.add(index);active.add(index);parent=model['bones'][index]['parent']
                if parent==index:break
                index=parent
    allowed={tuple(pair) for pair in unbound_label_aliases};renamed=[]
    for index,(bone,other) in enumerate(zip(model['bones'],reference['bones'])):
        if {k:v for k,v in bone.items() if k!='name'}!={k:v for k,v in other.items() if k!='name'}:
            raise ValueError('Motion reuse needs exact source rest hierarchy/transforms: '+bone['name'])
        if bone['name']==other['name']:continue
        if index in active or (bone['name'],other['name']) not in allowed:
            raise ValueError('Motion reuse cannot rename a weighted/ancestor or undeclared source joint: '+bone['name'])
        renamed.append({'index':index,'source':bone['name'],'reference':other['name']})
    return {'fields':fields,'bone_count':len(model['bones']),'weighted_ancestor_count':len(active),'unbound_label_aliases':renamed,
        'uv_policy':'Own UV coordinates and atlas retained; no UV equality or replacement claimed.',
        'method':'Exact skin geometry, weights/ties, rest hierarchy/transforms and all weighted/ancestor joint names. Only explicit unbound scene labels may differ; source motion reuse is an authored decision.'}

def rescale_translation_units(animation,body):
    """Explicit large-unit clip conversion; rotations/timing stay unchanged.

    Only used for declared old dragon death clips, after spelling/hierarchy
    matching. The bones' relative lengths must demonstrate one common unit
    factor. Differences in posed root/pelvis offsets are recorded, not called
    an exact bind contract or a faithful scale/shear reconstruction.
    """
    target={b['name']:b for b in body['bones']};ratios=[]
    for bone in animation['bones']:
        match=target.get(bone['name'])
        if match is None:raise ValueError('Unit conversion needs matched source bones')
        source_length=math.sqrt(sum(v*v for v in bone['translation']))
        target_length=math.sqrt(sum(v*v for v in match['translation']))
        if min(source_length,target_length)>.001:ratios.append(target_length/source_length)
    if len(ratios)<20:raise ValueError('Insufficient measured bone lengths for unit conversion')
    factor=statistics.median(ratios)
    if not .001<factor<.02 or sum(abs(v/factor-1.)<.01 for v in ratios)<len(ratios)*.85:
        raise ValueError('No consistent large-unit source rig conversion')
    result=copy.deepcopy(animation)
    for bone in result['bones']:bone['translation']=[v*factor for v in bone['translation']]
    for track in result['tracks']:
        track['translation']['values']=[[v*factor for v in value] for value in track['translation']['values']]
    return result,{'translation_factor':factor,'measured_bones':len(ratios),'ratio_range':[min(ratios),max(ratios)],
                   'method':'Median matched local bone-length unit conversion. All bone and track translations scaled together; source orientations and times retained. Posed offsets are not exact neutral bind equivalence.'}
