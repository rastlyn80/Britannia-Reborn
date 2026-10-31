"""Rebind a local creature trial to a rigid rig using source joint centres.

Non-uniform exporter scales/shear cannot pass through the rigid legacy exporter
unchanged. Preserve the visible bind mesh, names and hierarchy; take the polar
rotation and position of each affine joint, then retarget source motion to that
neutral rig. This is an explicit motion approximation, not native stretch/shear
fidelity. The strict binary reader and all source files remain unchanged.
"""
import bisect,copy,math,struct

IDENTITY=[[1.,0.,0.],[0.,1.,0.],[0.,0.,1.]]
def transpose(a):return [list(row) for row in zip(*a)]
def multiply(a,b):return [[sum(a[i][k]*b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
def vector(a,v):return [sum(a[i][j]*v[j] for j in range(3)) for i in range(3)]
def determinant(a):
    return a[0][0]*(a[1][1]*a[2][2]-a[1][2]*a[2][1])-a[0][1]*(a[1][0]*a[2][2]-a[1][2]*a[2][0])+a[0][2]*(a[1][0]*a[2][1]-a[1][1]*a[2][0])
def inverse(a):
    det=determinant(a)
    assert math.isfinite(det) and abs(det)>1e-15,'Singular affine bone'
    return [[(a[(j+1)%3][(i+1)%3]*a[(j+2)%3][(i+2)%3]-a[(j+1)%3][(i+2)%3]*a[(j+2)%3][(i+1)%3])/det for j in range(3)] for i in range(3)]
def polar(a):
    q=copy.deepcopy(a)
    # A fixed handedness basis cancels between a bone's bind and animated
    # rotation. Mesh-object helper bones can carry reflected exporter scales.
    if determinant(q)<0.:
        for row in q:row[0]=-row[0]
    for _ in range(24):
        other=transpose(inverse(q));updated=[[(q[i][j]+other[i][j])*.5 for j in range(3)] for i in range(3)]
        delta=max(abs(updated[i][j]-q[i][j]) for i in range(3) for j in range(3));q=updated
        if delta<1e-10:break
    product=multiply(transpose(q),q)
    assert max(abs(product[i][j]-IDENTITY[i][j]) for i in range(3) for j in range(3))<1e-7,'Affine polar rotation did not converge'
    return q
def quaternion(a):
    trace=sum(a[i][i] for i in range(3))
    if trace>0.:
        s=math.sqrt(trace+1.)*2.;q=[(a[2][1]-a[1][2])/s,(a[0][2]-a[2][0])/s,(a[1][0]-a[0][1])/s,s*.25]
    else:
        i=max(range(3),key=lambda j:a[j][j]);j=(i+1)%3;k=(i+2)%3
        s=math.sqrt(max(0.,1.+a[i][i]-a[j][j]-a[k][k]))*2.
        assert s>1e-10
        q=[0.,0.,0.,0.];q[i]=s*.25;q[j]=(a[j][i]+a[i][j])/s;q[k]=(a[k][i]+a[i][k])/s;q[3]=(a[k][j]-a[j][k])/s
    length=math.sqrt(sum(v*v for v in q));return [v/length for v in q]
def sample(stream,time,default,rotation=False):
    if not stream or not stream['times']:return default
    times,values=stream['times'],stream['values'];index=bisect.bisect_right(times,time)
    if not index:return values[0]
    if index==len(times):return values[-1]
    a,b=values[index-1],values[index];u=(time-times[index-1])/max(1e-9,times[index]-times[index-1])
    if rotation:
        dot=sum(x*y for x,y in zip(a,b))
        if dot<0.:b=[-v for v in b];dot=-dot
        if dot<.9995:
            theta=math.acos(max(-1.,min(1.,dot)));p=math.sin((1-u)*theta)/math.sin(theta);q=math.sin(u*theta)/math.sin(theta)
            result=[p*x+q*y for x,y in zip(a,b)]
        else:result=[x*(1-u)+y*u for x,y in zip(a,b)]
        length=math.sqrt(sum(v*v for v in result));return [v/length for v in result]
    return [x*(1-u)+y*u for x,y in zip(a,b)]

def neutralise(raw,model,td):
    matrices=[list(struct.unpack('<I16f',payload)[8:]) for tag,payload,_ in td.chunks(raw) if tag==0xca5e0506]
    assert len(matrices)==len(model['bones'])
    matrices=[[values[i:i+3] for i in [0,3,6]] for values in matrices]
    result=copy.deepcopy(model);tracks={track['name']:track for track in model['tracks']}
    def poses(time=None):
        global_poses={};visiting=set()
        def joint(i):
            if i in global_poses:return global_poses[i]
            assert i not in visiting,'Cyclic affine hierarchy'
            visiting.add(i);bone=model['bones'][i];track=tracks.get(bone['name'],{}) if time is not None else {}
            t=sample(track.get('translation'),time,bone['translation'])
            q=td.unit(sample(track.get('rotation'),time,bone['rotation'],True))
            rotation=transpose([list(td.rotate(q,axis)) for axis in IDENTITY])
            scaling=matrices[i]
            if track.get('scale_shear',{}).get('times'):
                values=sample(track['scale_shear'],time,[v for row in scaling for v in row]);scaling=[values[j:j+3] for j in [0,3,6]]
            basis=multiply(rotation,scaling)
            if bone['parent']!=i:
                parent_basis,parent_position=joint(bone['parent']);t=[x+y for x,y in zip(vector(parent_basis,t),parent_position)];basis=multiply(parent_basis,basis)
            visiting.remove(i);global_poses[i]=(basis,t);return basis,t
        for i in range(len(model['bones'])):joint(i)
        rotations={i:polar(basis) for i,(basis,_) in global_poses.items()}
        output=[]
        for i,bone in enumerate(model['bones']):
            rotation=rotations[i];position=global_poses[i][1];parent=bone['parent']
            if parent!=i:
                parent_inverse=transpose(rotations[parent]);rotation=multiply(parent_inverse,rotation)
                position=vector(parent_inverse,[x-y for x,y in zip(position,global_poses[parent][1])])
            output.append((position,quaternion(rotation)))
        return output
    bind=poses()
    for bone,(position,rotation) in zip(result['bones'],bind):bone.update(translation=position,rotation=rotation)
    if model['tracks']:
        duration=max(stream['times'][-1] for track in model['tracks'] for stream in [track['translation'],track['rotation'],track.get('scale_shear',{'times':[]})] if stream['times'])
        assert duration>0.
        times=sorted({min(duration,i/30) for i in range(math.ceil(duration*30)+1)}|{t for track in model['tracks'] for key in ['translation','rotation','scale_shear'] for t in track.get(key,{}).get('times',[])})
        sampled=[poses(time) for time in times];result['tracks']=[]
        for i,bone in enumerate(model['bones']):
            result['tracks'].append({'name':bone['name'],'translation':{'times':times,'values':[pose[i][0] for pose in sampled]},
                                     'rotation':{'times':times,'values':[pose[i][1] for pose in sampled]},'scale':{'times':[],'values':[]}})
    return result,{'method':'Affine joint centres and proper polar rotations rebound to a rigid rig, with a fixed X handedness basis for reflected joints; original bind mesh/UVs/weights retained. Resampled source joint motion, not native scale/shear skin fidelity.',
                   'bones':len(model['bones']),'source_matrices':matrices,'sample_rate_hz':30}
