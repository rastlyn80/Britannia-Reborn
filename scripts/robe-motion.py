"""Bake eight garment-only skirt controls from evaluated native leg motion.

Executed by prepare-free-equipment.py inside Blender. Native bones and tracks
are preserved. Cloth clearance is an envelope fit, not a physics simulation.
"""
import bpy,math
from mathutils import Vector,Matrix

LEVELS=(.88,.65,.40,.18)

def leg_vertices(body):
    # Height alone includes fingertips in the body's A bind pose. Those
    # fingers later move at thigh height and must never widen a skirt.
    return [v.index for v in body.data.vertices if .16<(body.matrix_world@v.co).z<.94 and sum(g.weight for g in v.groups if body.vertex_groups[g.group].name.startswith(('pelvis','thigh','calf','foot','ball')))>.5]

def fit_silhouette(garment,body,rig):
    """Refit flared lower cloth to the fixed body's anatomical cross sections.

    Preserve folds, UVs, weights and the waist join; remove the source hoop
    silhouette before fitting motion. Sleeves never participate in the fit.
    """
    inverse=rig.matrix_world.inverted();cloth_transform=inverse@garment.matrix_world
    body_transform=inverse@body.matrix_world
    def sleeve(ob,v):return any(g.weight>1e-7 and ob.vertex_groups[g.group].name.startswith(('upperarm','lowerarm','hand','clavicle')) for g in v.groups)
    skin=[body_transform@v.co for v in body.data.vertices if sum(g.weight for g in v.groups if body.vertex_groups[g.group].name.startswith(('pelvis','thigh','calf','foot','ball')))>.5]
    cloth=[cloth_transform@v.co for v in garment.data.vertices if not sleeve(garment,v)]
    levels=[.95,.88,.80,.70,.65,.50,.40,.25,.15]
    profiles=[]
    for z in levels:
        near=[p for p in skin if abs(p.z-z)<.04]
        old=[p for p in cloth if abs(p.z-z)<.055]
        if not near or not old:continue
        old_width=max(abs(p.x) for p in old)
        ease=.025+.025*max(0.,min(1.,(.7-z)/.55))
        width=max(abs(p.x) for p in near)+ease
        front=min(p.y for p in near)-ease;back=max(p.y for p in near)+ease
        profiles.append((z,old_width,min(p.y for p in old),max(p.y for p in old),width,front,back))
    changed=0
    for vertex in garment.data.vertices:
        if sleeve(garment,vertex):continue
        co=cloth_transform@vertex.co
        if co.z>=.95:continue
        a=b=profiles[-1]
        if co.z>=profiles[0][0]:a=b=profiles[0]
        else:
            for upper,lower in zip(profiles,profiles[1:]):
                if upper[0]>=co.z>=lower[0]:a,b=upper,lower;break
        t=0. if a[0]==b[0] else (a[0]-co.z)/(a[0]-b[0])
        values=[x+(y-x)*t for x,y in zip(a[1:],b[1:])]
        old_width,old_front,old_back,width,front,back=values
        weight=max(0.,min(1.,(.95-co.z)/.07));weight=weight*weight*(3-2*weight)
        old_middle=(old_front+old_back)*.5;old_depth=max(.025,(old_back-old_front)*.5)
        nx=co.x/max(.05,old_width);ny=(co.y-old_middle)/old_depth
        # A rounded rectangle wraps two thighs without requiring a broad
        # circular hoop to enclose the front/outside corners of both legs.
        # Compress deep source folds without collapsing distinct radial
        # layers onto the same surface (which would cause self intersections).
        angle=math.atan2(ny,nx);pleat=1.+.15*(math.hypot(nx,ny)-1.)
        cosine=math.cos(angle);sine=math.sin(angle)
        new_x=width*math.copysign(abs(cosine)**.5,cosine)*pleat
        new_y=(front+back)*.5+(back-front)*.5*math.copysign(abs(sine)**.5,sine)*pleat
        co.x+=(new_x-co.x)*weight;co.y+=(new_y-co.y)*weight
        vertex.co=cloth_transform.inverted()@co;changed+=1
    garment.data.update()
    return {'method':'body section fit, 25-50 mm ease, preserved waist and sleeve geometry','vertices':changed,'profiles':profiles}

def bake_envelopes(rig,body,garments,actions):
    """Fit shared controls in pelvis space, including turning/wide stances.

    Use the most restrictive cross section of robe, skirt and kilt. The old
    axial bake assumed a forward-facing pelvis and one ankle-length garment.
    No body triangles are hidden to solve a clothing intersection.
    """
    inverse=rig.matrix_world.inverted()
    leg_ids=leg_vertices(body)
    foot_ids=[v.index for v in body.data.vertices if (body.matrix_world@v.co).z<.16]
    bands=[]
    for z in LEVELS:
        widths=[];fronts=[];backs=[]
        for garment in garments:
            transform=inverse@garment.matrix_world
            points=[]
            for vertex in garment.data.vertices:
                if any(garment.vertex_groups[g.group].name.startswith(('upperarm','lowerarm','hand','clavicle')) and g.weight>1e-7 for g in vertex.groups):continue
                co=transform@vertex.co
                if abs(co.z-z)<.1:points.append(co)
            if points:
                widths.append(max(abs(p.x) for p in points));fronts.append(min(p.y for p in points));backs.append(max(p.y for p in points))
        assert widths
        bands.append((min(widths),max(fronts),min(backs)))
    evidence={}
    for action in actions:
        rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
        start,end=map(int,action.frame_range);max_scale=1.;max_shift=0.
        for frame in range(start,end+1):
            bpy.context.scene.frame_set(frame);bpy.context.view_layer.update()
            deps=bpy.context.evaluated_depsgraph_get();evaluated=body.evaluated_get(deps)
            pelvis=rig.pose.bones['pelvis'];skin=pelvis.matrix@rig.data.bones['pelvis'].matrix_local.inverted();unpose=skin.inverted()
            convert=unpose@inverse@evaluated.matrix_world
            points=[convert@evaluated.data.vertices[i].co for i in leg_ids]
            feet=[(convert@evaluated.data.vertices[i].co,evaluated.matrix_world@evaluated.data.vertices[i].co) for i in foot_ids]
            hem=rig.matrix_world@skin@Vector((0,0,.16))
            lift={side:min(.46,max(0.,max((world.z for local,world in feet if sign*local.y>.08),default=.1)+.075-hem.z)) for side,sign in [('front',-1),('back',1)]}
            for i,z in enumerate(LEVELS):
                width,front,back=bands[i]
                factor=(LEVELS[0]-z)/(LEVELS[0]-LEVELS[-1])
                vertical=(lift['front']+lift['back'])*.5*factor
                sample_z=z+(unpose.to_3x3()@inverse.to_3x3()@Vector((0,0,vertical))).z
                near=[point for point in points if abs(point.z-sample_z)<.075]
                lo=min(front,min((p.y for p in near),default=front)-.045)
                hi=max(back,max((p.y for p in near),default=back)+.045)
                left=min((p.x for p in near),default=-width);right=max((p.x for p in near),default=width)
                centre=(left+right)*.5
                middle=(lo+hi)*.5;depth=max(.05,(hi-lo)*.5)
                scale=.70
                for p in near:
                    axial=(p.y-middle)/depth
                    scale=max(scale,(abs(p.x-centre)+.08)/(max(.05,width)*max(.03,1-abs(axial)**4)**.25))
                for side in ['front','back']:
                    name=f'robe_{side}_{i}';pose=rig.pose.bones[name];rest=rig.data.bones[name].matrix_local
                    delta=lo-front if side=='front' else hi-back
                    y=-.18 if side=='front' else .13
                    desired=skin@rest
                    desired.translation=skin@Vector((centre,y+delta,z))
                    factor=(LEVELS[0]-z)/(LEVELS[0]-LEVELS[-1])
                    vertical=(lift[side]+max(0.,.10-hem.z))*factor
                    desired.translation+=inverse.to_3x3()@Vector((0,0,vertical))
                    desired.col[0]*=scale
                    pose.matrix=desired
                    pose.keyframe_insert(data_path='location',frame=frame,group='Garment envelope')
                    pose.keyframe_insert(data_path='rotation_quaternion',frame=frame,group='Garment envelope')
                    pose.keyframe_insert(data_path='scale',frame=frame,group='Garment envelope')
                    max_scale=max(max_scale,scale);max_shift=max(max_shift,abs(delta))
        evidence[action.name]={'frames':end-start+1,'max_lateral_scale':max_scale,'max_panel_translation_m':max_shift}
    rig.animation_data.action=None
    for pose in rig.pose.bones:pose.matrix_basis=Matrix.Identity(4)
    return {'method':'anatomical pelvis/leg-only rounded-rectangle envelope; retain all body geometry','leg_vertices':len(leg_ids),'clips':evidence}

def control_weights(co):
    z=co.z
    if z>=.95:return None
    if z>=LEVELS[0]:
        k=(.95-z)/(.95-LEVELS[0]);levels=[('pelvis',1-k),(0,k)]
    elif z<=LEVELS[-1]:levels=[(len(LEVELS)-1,1.)]
    else:
        i=next(i for i in range(len(LEVELS)-1) if LEVELS[i]>=z>=LEVELS[i+1])
        t=(LEVELS[i]-z)/(LEVELS[i]-LEVELS[i+1]);levels=[(i,1-t),(i+1,t)]
    # Smooth cross-section blending avoids a centre seam between the legs.
    f=max(0.,min(1.,(-.025-co.y)/.04));f=f*f*(3-2*f)
    result={}
    for level,w in levels:
        if level=='pelvis':result['pelvis']=w
        else:
            result[f'robe_front_{level}']=w*f
            result[f'robe_back_{level}']=w*(1-f)
    return result

def bake(rig,body,robe):
    actions=[tr.strips[0].action for tr in rig.animation_data.nla_tracks]
    leg_ids=leg_vertices(body)
    foot_ids=[v.index for v in body.data.vertices if (body.matrix_world@v.co).z<.16]
    bpy.context.view_layer.objects.active=rig
    bpy.ops.object.mode_set(mode='EDIT')
    for i,z in enumerate(LEVELS):
        for side,y in [('front',-.18),('back',.13)]:
            b=rig.data.edit_bones.new(f'robe_{side}_{i}')
            b.head=(0,y,z);b.tail=(0,y,z+.06);b.parent=rig.data.edit_bones['pelvis']
    bpy.ops.object.mode_set(mode='OBJECT')
    # Replace only the skirt weights; sleeves/torso remain on the native rig.
    preserved_sleeve_vertices=0
    for v in robe.data.vertices:
        # A shorter body puts the cuffs below the skirt's fixed height cutoff.
        # Keep authored arm influences so cuffs follow hands rather than hips.
        arm_weight=sum(g.weight for g in v.groups if robe.vertex_groups[g.group].name.startswith(('upperarm','lowerarm','hand','clavicle')))
        if arm_weight>1e-7:
            preserved_sleeve_vertices+=1
            continue
        ws=control_weights(v.co)
        if ws is None:continue
        for g in list(v.groups):robe.vertex_groups[g.group].remove([v.index])
        for name,w in ws.items():
            if w<=1e-7:continue
            group=robe.vertex_groups.get(name) or robe.vertex_groups.new(name=name)
            group.add([v.index],w,'REPLACE')
    bands=[]
    for z in LEVELS:
        points=[v.co for v in robe.data.vertices if abs(v.co.z-z)<.10]
        bands.append((min(p.y for p in points),max(p.y for p in points)))
    evidence={}
    for action in actions:
        rig.animation_data.action=action
        # Imported glTF actions have a single armature slot.
        rig.animation_data.action_slot=action.slots[0]
        start,end=map(int,action.frame_range);samples=[]
        for frame in range(start,end+1):
            bpy.context.scene.frame_set(frame);bpy.context.view_layer.update()
            deps=bpy.context.evaluated_depsgraph_get();ev=body.evaluated_get(deps)
            # Feet/toes belong outside an ankle-length hem. Including toes in
            # the clearance envelope makes the robe balloon along the floor.
            points=[ev.matrix_world@ev.data.vertices[i].co for i in leg_ids]
            feet=[ev.matrix_world@ev.data.vertices[i].co for i in foot_ids]
            pelvis=rig.pose.bones['pelvis'];skin=pelvis.matrix@rig.data.bones['pelvis'].matrix_local.inverted()
            hem=skin@Vector((0,0,.16))
            foot_lift={}
            for side,sign in [('front',-1),('back',1)]:
                foot_height=max((p.z for p in feet if sign*(p.y-hem.y)>.08),default=.10)
                foot_lift[side]=min(.46,max(0.,foot_height+.075-hem.z))
            shifts=[]
            for i,z in enumerate(LEVELS):
                ref=skin@Vector((0,0,z))
                front,back=bands[i]
                # Enclose both moving legs rather than attaching half a skirt
                # to each calf (which tears the centre or creates trouser tubes).
                for side,y in [('front',-.18),('back',.13)]:
                    name=f'robe_{side}_{i}';p=rig.pose.bones[name]
                    rest=rig.data.bones[name].matrix_local
                    inherited=skin@rest
                    # Lift the opening above a raised heel, rather than letting
                    # it protrude through closed fabric. Spread this lift up
                    # the panel so adjacent rings never fold over each other.
                    factor=(LEVELS[0]-z)/(LEVELS[0]-LEVELS[-1])
                    lift=(foot_lift[side]+max(0.,.10-hem.z))*factor
                    near=[point for point in points if abs(point.z-(ref.z+lift))<.13]
                    lo=min((point.y for point in near),default=ref.y+front)-.085
                    hi=max((point.y for point in near),default=ref.y+back)+.085
                    delta=min(0.,lo-(ref.y+front)) if side=='front' else max(0.,hi-(ref.y+back))
                    desired=inherited.copy();desired.translation+=Vector((0,delta,lift))
                    desired.col[0]*=1.10 if i==0 else 1.22
                    p.matrix=desired;p.keyframe_insert(data_path='location',frame=frame,group='Robe clearance');p.keyframe_insert(data_path='scale',frame=frame,group='Robe clearance')
                    shifts.append(abs(delta))
            samples.append(max(shifts))
        evidence[action.name]={'frames':end-start+1,'max_panel_translation_m':max(samples)}
    rig.animation_data.action=None
    for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
    bpy.context.view_layer.update()
    return dict(method='eight front/back skirt controls, leg envelope at four heights, 85 mm axial margin plus bounded lateral ease; preserve authored sleeve weights',native_bones=53,garment_bones=8,preserved_sleeve_vertices=preserved_sleeve_vertices,clips=evidence)
