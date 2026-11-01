"""Explicit, bounded source-tentacle shaping; no generic reader rule is changed."""
import copy,math

def gesture(idle,reader,label):
    """Authored waterborne tentacle actions; source Attack remains untouched."""
    if label not in ['Attack2','Attack3','Cast']:
        raise ValueError('Explicit cephalopod action category required')
    result=copy.deepcopy(idle);bones=result['bones'];by_name={b['name']:i for i,b in enumerate(bones)}
    tracks={t['name']:t for t in result['tracks']}
    for name in ['bip01 l calf','bip01 r calf','bip01 l foot','bip01 r foot']:
        if name not in tracks:raise ValueError('Source tentacle controls are required')
    orientation={}
    def world_rotation(index):
        if index not in orientation:
            bone=bones[index];track=tracks.get(bone['name'],{}).get('rotation',{})
            q=reader.unit(track['values'][0] if track.get('values') else bone['rotation'])
            orientation[index]=reader.qmul(world_rotation(bone['parent']),q) if bone['parent']!=index else q
        return orientation[index]
    duration={'Attack2':1.,'Attack3':1.1,'Cast':1.6}[label];times=[duration*i/32 for i in range(33)]
    def smooth(t):return t*t*(3.-2.*t)
    def envelope(u):
        if u<.35:return smooth(u/.35)
        if u<.55:return 1.
        if u<.8:return 1.-1.12*smooth((u-.55)/.25)
        return -.12*(1.-smooth((u-.8)/.2))
    for name,track in tracks.items():
        # Hold the recovered initial source pose in every unrelated channel.
        for key in ['translation','rotation','scale']:
            stream=track.get(key)
            if stream and stream.get('values'):track[key]={'times':times[:],'values':[copy.deepcopy(stream['values'][0]) for _ in times]}
        axis=[-1.,0.,0.];angle=0.
        if ' calf' in name or ' foot' in name or ' toe' in name:
            side='l' if ' l ' in name else 'r'
            strong=label=='Cast' or side==('l' if label=='Attack2' else 'r')
            angle=(.24 if label=='Cast' else .48) if ' calf' in name else (.28 if label=='Cast' else .4) if ' foot' in name else .1
            if not strong:angle=-angle*.18
        elif name=='bip01 spine2' and label!='Cast':
            axis=[0.,0.,1.];angle=.1 if label=='Attack2' else -.1
        elif name=='bip01 neck':angle=.06
        if angle==0. or not track.get('rotation',{}).get('values'):continue
        index=by_name[name];parent=bones[index]['parent']
        pq=world_rotation(parent) if parent!=index else [0.,0.,0.,1.]
        local_axis=reader.rotate([-pq[0],-pq[1],-pq[2],pq[3]],axis)
        base=reader.unit(track['rotation']['values'][0]);values=[]
        for i in range(33):
            half=angle*envelope(i/32)/2.;delta=[v*math.sin(half) for v in local_axis]+[math.cos(half)]
            values.append(reader.unit(reader.qmul(delta,base)))
        track['rotation']={'times':times[:],'values':values}
    return result

def round_tentacles(source,scale,iterations=16,maximum_m=.16):
    if not (0<scale<100 and 1<=iterations<=20 and 0<maximum_m<=.22):
        raise ValueError('Bounded source tentacle recipe required')
    result=copy.deepcopy(source);points=list(source['points']);reference=list(points)
    neighbours=[set() for _ in points]
    for face in source['polygons']:
        a,b,c=face[:3]
        for x,y in [(a,b),(b,c),(c,a)]:neighbours[x].add(y);neighbours[y].add(x)
    strengths=[]
    for pairs in source['weights']:
        score=sum(weight for tie,weight in pairs if any(label in source['bones'][source['ties'][tie]]['name'].lower() for label in ['thigh','calf','foot','toe']))
        strengths.append(max(0.,min(1.,(score-.35)/.45)))
    # Opposite low-pass steps reduce corner kinks while resisting tube shrink.
    # Cap every pass against the unchanged cage, in actual presentation metres.
    for _ in range(iterations):
        for gain in [.5,-.53]:
            refined=[]
            for i,point in enumerate(points):
                sides=neighbours[i]
                delta=[(sum(points[k][a] for k in sides)/len(sides)-point[a])*gain*strengths[i] for a in range(3)] if sides else [0.,0.,0.]
                candidate=[point[a]+delta[a] for a in range(3)]
                offset=[candidate[a]-reference[i][a] for a in range(3)]
                length=math.sqrt(sum(v*v for v in offset));factor=min(1.,maximum_m/scale*strengths[i]/max(length,1e-12))
                refined.append(tuple(reference[i][a]+offset[a]*factor for a in range(3)))
            points=refined
    normals=[[0.,0.,0.] for _ in points]
    for face in source['polygons']:
        ids=face[:3];a,b,c=[points[i] for i in ids]
        u=[b[j]-a[j] for j in range(3)];v=[c[j]-a[j] for j in range(3)]
        normal=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
        for i in ids:
            for j in range(3):normals[i][j]+=normal[j]
    # The subdivider supplies per-vertex normals and matching corner indices.
    if len(source['normals'])!=len(points) or any(tuple(face[3:])!=tuple(face[:3]) for face in source['polygons']):
        raise ValueError('Tentacle shaping requires the refined per-vertex normal mesh')
    score=sum(sum(normals[i][j]*source['normals'][i][j] for j in range(3)) for i in range(len(points)))
    sign=1. if score>=0. else -1.
    out=[]
    for i,n in enumerate(normals):
        if strengths[i]==0.:
            out.append(tuple(source['normals'][i]));continue
        length=math.sqrt(sum(v*v for v in n))
        target=[v*sign/max(length,1e-12) for v in n] if length>1e-12 else source['normals'][i]
        blended=[source['normals'][i][j]*(1.-strengths[i])+target[j]*strengths[i] for j in range(3)]
        norm=math.sqrt(sum(v*v for v in blended));out.append(tuple(v/max(norm,1e-12) for v in blended))
    result.update(points=points,normals=out)
    return result,{'method':'Authored tentacle-only Taubin shape pass on refined source cage; original rig, UVs, topology, skin weights and clips retained',
                   'iterations':iterations,'maximum_displacement_m':maximum_m,
                   'measured_displacement_m':max(math.dist(a,b)*scale for a,b in zip(points,reference)),
                   'selected_vertices':sum(s>0. for s in strengths),'fixed_vertices':sum(s==0. for s in strengths)}
