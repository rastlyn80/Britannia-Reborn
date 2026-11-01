"""Authored gestures on measured source rigs; no original choreography claimed.

Source coordinates are Z-up. Anatomical forward comes from the shoulder line,
so scene authoring yaw is retained rather than guessed from file names.
"""
import copy, math

def add(a,b):return [x+y for x,y in zip(a,b)]
def sub(a,b):return [x-y for x,y in zip(a,b)]
def mul(a,s):return [x*s for x in a]
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def length(v):return math.sqrt(dot(v,v))
def unit(v):
    size=length(v);assert size>1e-10,'Degenerate anatomical direction'
    return mul(v,1./size)
def mix(a,b,u):return add(mul(a,1.-u),mul(b,u))
def inverse(q):return [-q[0],-q[1],-q[2],q[3]]
def qmul(a,b):
    xyz=add(add(mul(b[:3],a[3]),mul(a[:3],b[3])),cross(a[:3],b[:3]))
    return unit(xyz+[a[3]*b[3]-dot(a[:3],b[:3])])
def rotate(q,v):
    twice=mul(cross(q[:3],v),2.)
    return add(v,add(mul(twice,q[3]),cross(q[:3],twice)))
def axis_angle(axis,angle):return mul(unit(axis),math.sin(angle*.5))+[math.cos(angle*.5)]
def between(a,b):
    a,b=unit(a),unit(b);cosine=max(-1.,min(1.,dot(a,b)))
    if cosine<-.999999:
        axis=cross(a,[1.,0.,0.])
        if length(axis)<1e-6:axis=cross(a,[0.,1.,0.])
        return axis_angle(axis,math.pi)
    return unit(cross(a,b)+[1.+cosine])
def smooth(u):
    u=max(0.,min(1.,u));return u*u*(3.-2.*u)
def envelope(u):return smooth(u/.3)*(1.-smooth((u-.72)/.28))

class Pose:
    def __init__(self,body,idle):
        self.bones=body['bones'];self.names={b['name'].replace('_',''):i for i,b in enumerate(self.bones)}
        assert len(self.names)==len(self.bones),'Ambiguous normalized rig names'
        tracks={t['name']:t for t in idle['tracks']}
        self.positions=[];self.rotations=[];self.cache={}
        for b in self.bones:
            track=tracks.get(b['name'],{})
            def first(channel):
                stream=track.get(channel,{})
                return list(stream['values'][0]) if stream.get('values') else list(b[channel])
            self.positions.append(first('translation'));self.rotations.append(unit(first('rotation')))
            scales=track.get('scale_shear',{}).get('values',[])
            if scales:assert max(abs(v-(1. if i in [0,4,8] else 0.)) for i,v in enumerate(scales[0]))<.001,'Gesture requires a normalized rigid source rig'
    def world(self,name):
        i=self.names[name.replace('_','')] if isinstance(name,str) else name
        if i not in self.cache:
            b=self.bones[i];q,p=self.rotations[i],self.positions[i]
            if b['parent']!=i:
                pq,pp=self.world(b['parent']);q,p=qmul(pq,q),add(pp,rotate(pq,p))
            self.cache[i]=(q,p)
        return self.cache[i]
    def world_rotation(self,name,q):
        i=self.names[name.replace('_','')];parent=self.bones[i]['parent']
        self.rotations[i]=qmul(inverse(self.world(parent)[0]),q) if parent!=i else q
        self.cache.clear()
    def turn(self,name,axis,angle):
        self.world_rotation(name,qmul(axis_angle(axis,angle),self.world(name)[0]))
    def translate(self,name,delta):
        i=self.names[name.replace('_','')];parent=self.bones[i]['parent']
        local=rotate(inverse(self.world(parent)[0]),delta) if parent!=i else delta
        self.positions[i]=add(self.positions[i],local);self.cache.clear()
    def limb(self,upper,lower,end,target,pole):
        uq,origin=self.world(upper);_,elbow=self.world(lower);_,tip=self.world(end)
        first,second=length(sub(elbow,origin)),length(sub(tip,elbow))
        ray=sub(target,origin);distance=max(abs(first-second)+1e-6,min(length(ray),first+second-1e-6));direction=unit(ray)
        target=add(origin,mul(direction,distance))
        across=sub(pole,origin);across=sub(across,mul(direction,dot(across,direction)))
        if length(across)<1e-7:across=cross(direction,[0.,0.,1.])
        across=unit(across)
        along=(first*first-second*second+distance*distance)/(2.*distance)
        bend=math.sqrt(max(0.,first*first-along*along))
        desired=add(add(origin,mul(direction,along)),mul(across,bend))
        self.world_rotation(upper,qmul(between(sub(elbow,origin),sub(desired,origin)),uq))
        lq,actual=self.world(lower);_,tip=self.world(end)
        self.world_rotation(lower,qmul(between(sub(tip,actual),sub(target,actual)),lq))
        return target

def gesture(body,idle,label,head_landmarks=None):
    assert label in ['Cast','Pillage','Attack2','Attack3']
    baseline=Pose(body,idle);up=[0.,0.,1.]
    spines=[name for name in ['bip01 spine','bip01 spine1','bip01 spine2','bip01 spine3'] if name in baseline.names]
    heads=head_landmarks if head_landmarks is not None else ['bip01 head'] if 'bip01 head' in baseline.names else ['geosphere01','geosphere02']
    assert len(spines)>=3 and all(name in baseline.names for name in heads),'Undeclared source torso/head layout'
    left=unit(sub(baseline.world('bip01 l upperarm')[1],baseline.world('bip01 r upperarm')[1]))
    left=unit([left[0],left[1],0.]);forward=unit(cross(left,up))
    height=max(p[2] for p in body['points'])-min(p[2] for p in body['points'])
    duration={'Cast':1.4,'Pillage':1.8,'Attack2':.85,'Attack3':.95}[label];frames=round(duration*60)+1
    if len(heads)==2:duration*=1.2;frames=round(duration*60)+1
    result=copy.deepcopy(idle)
    # Source animation files omit unanimated grasp/attachment leaves. Retain
    # their body bind transforms while keeping the original animation scene
    # anchor for animated bones (the exporter uses it to re-anchor the hips).
    source_bones={b['name']:b for b in idle['bones']}
    result['bones']=[dict(b,translation=source_bones.get(b['name'],b)['translation'],rotation=source_bones.get(b['name'],b)['rotation']) for b in body['bones']]
    result['tracks']=[{'name':b['name'],'translation':{'times':[],'values':[]},'rotation':{'times':[],'values':[]}} for b in body['bones']]
    feet={side:baseline.world('bip01 '+side+' foot')[1] for side in ['l','r']}
    for frame in range(frames):
        u=frame/(frames-1);attack=label.startswith('Attack');stroke=smooth((u-.27)/.25)
        amount=smooth(u/.24)*(1.-smooth((u-.64)/.36)) if attack else envelope(u)
        pose=Pose(body,idle)
        if amount>1e-8:
            # A short, distributed torso bend avoids a single sharp waist
            # hinge. Feet retain their measured starting anchors in a crouch.
            lean=((.9 if len(heads)==2 else .55) if label=='Pillage' else (-.1+.28*stroke) if attack else -.08)*amount
            # The ettin's broad calf-weighted boots cannot fold through the
            # ground. Distribute its reach through the torso and a shallower
            # knee bend rather than lifting both planted feet with the mesh.
            if label=='Pillage':pose.translate('bip01',mul(up,-height*(.08 if len(heads)==2 else .18)*amount))
            elif attack:pose.translate('bip01',mul(up,-height*.018*amount*stroke))
            for name in spines:
                pose.turn(name,left,lean/len(spines))
                if label=='Attack3':pose.turn(name,up,(-.23+.5*stroke)*amount/len(spines))
            for name in heads:pose.turn(name,left,-lean*.25)
            # These source thighs branch from the spine rather than the
            # pelvis. Even a small standing torso lean needs leg compensation.
            for side in ['l','r']:
                thigh='bip01 '+side+' thigh';calf='bip01 '+side+' calf';foot='bip01 '+side+' foot'
                _,knee=baseline.world(calf)
                pole=add(knee,mul(forward,height*.35*amount if label=='Pillage' else 0.))
                pose.limb(thigh,calf,foot,feet[side],pole)
                pose.world_rotation(foot,baseline.world(foot)[0])
            for side,sign in [('l',1.),('r',-1.)]:
                upper='bip01 '+side+' upperarm';lower='bip01 '+side+' forearm';hand='bip01 '+side+' hand'
                _,shoulder=pose.world(upper);_,elbow=baseline.world(lower);_,start=baseline.world(hand)
                reach=length(sub(baseline.world(lower)[1],baseline.world(upper)[1]))+length(sub(start,baseline.world(lower)[1]))
                if attack:
                    if side=='l':
                        target=add(shoulder,add(mul(forward,reach*.43),add(mul(up,reach*.12),mul(left,reach*.12))))
                    elif label=='Attack2':
                        windup=add(shoulder,add(mul(up,reach*.78),add(mul(forward,-reach*.12),mul(left,-reach*.12))))
                        impact=add(shoulder,add(mul(forward,reach*.91),mul(up,-reach*.2)))
                        target=mix(windup,impact,stroke)
                    else:
                        windup=add(shoulder,add(mul(left,-reach*.76),mul(up,reach*.08)))
                        impact=add(shoulder,add(mul(forward,reach*.79),mul(left,reach*.44)))
                        target=mix(windup,impact,stroke)
                elif label=='Cast':
                    # Supporting hand stays nearer the chest; the release
                    # hand reaches forward. Original grip/attachments remain.
                    target=add(shoulder,add(mul(forward,reach*(.58 if side=='l' else .8)),add(mul(up,reach*(.2 if side=='l' else .04)),mul(left,sign*reach*.08))))
                else:
                    target=add(shoulder,add(mul(forward,reach*.65),add(mul(up,-reach*.7),mul(left,sign*reach*.07))))
                target=mix(start,target,amount)
                desired_pole=add(shoulder,add(mul(left,sign*reach*.5),mul(up,-reach*.55)))
                pole=mix(elbow,desired_pole,amount)
                pose.limb(upper,lower,hand,target,pole)
                # Retain the source wrist/finger pose relative to its forearm.
                # Fixing the palm in world space creates sharp wrist bends as
                # the elbow and forearm swing through their new trajectories.
        for i,track in enumerate(result['tracks']):
            for channel,value in [('translation',pose.positions[i]),('rotation',pose.rotations[i])]:
                track[channel]['times'].append(duration*u);track[channel]['values'].append(list(value))
    return result

def install(body,clips,authored,aliases,stem):
    if stem not in ['orcs_orc','orcs_orc_captain','orcs_orc_lord','orcs_orc_shaman','ettins_ettin','walking_dead_ghoul','headless_headless']:return
    landmarks=['bip01 neck'] if stem=='headless_headless' else None
    if 'Cast' not in clips:
        clips['Cast']=gesture(body,clips['Idle'],'Cast',landmarks)
        authored['Cast']='Authored two-bone arm reach and distributed torso gesture on the measured source rig; original grip retained; not recovered UO choreography'
    for label in ['Attack2','Attack3']:
        if label not in clips:
            clips[label]=gesture(body,clips['Idle'],label,landmarks)
            authored[label]='Authored measured-limb overhead strike' if label=='Attack2' else 'Authored measured-limb sweeping strike'
            authored[label]+=' with windup, impact, recovery, planted feet and source grip hierarchy; not recovered UO choreography'
    if 'Pillage' not in clips:
        if 'Stomp' in clips:
            clips['Pillage']=copy.deepcopy(clips['Stomp']);aliases['Pillage']='Stomp: explicit source ground-slap category reuse, not a recovered pillaging clip'
        else:
            clips['Pillage']=gesture(body,clips['Idle'],'Pillage',landmarks)
            authored['Pillage']='Authored crouch/reach with measured leg IK and fixed source stance anchors; ground-slap/pillage category approximation, not recovered UO choreography'
    return True
