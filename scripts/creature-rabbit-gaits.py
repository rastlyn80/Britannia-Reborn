"""Reconcile donor paw stance with native travel using common root motion.

No joint angles, limb lengths or relative source poses change. The two rig
roots receive the same small longitudinal offset, with smooth airborne resets.
"""
import math
from mathutils import Vector

def reconcile(mesh,rig,frames,duration,speed,scale):
    rest={b.name:b.matrix_local.inverted() for b in rig.data.bones}
    vertices=[v.co.copy() for v in mesh.data.vertices]
    weights=[[(mesh.vertex_groups[g.group].name,g.weight) for g in v.groups if g.weight>0. and mesh.vertex_groups[g.group].name in rest] for v in mesh.data.vertices]
    paws=[prefix+'Paw_'+side for prefix in ['Front','Back'] for side in ['L','R']]
    sole_indices={paw:[i for i,w in enumerate(weights) if sum(v for name,v in w if name==paw)>.6] for paw in paws}
    assert all(sole_indices.values()),'Each original paw needs its weighted skin'
    n=len(frames)-1;dt=duration/n;soles=[];labels=[]
    for frame in frames[:-1]:
        matrices={name:frame[name]@matrix for name,matrix in rest.items()}
        posed=[sum((matrices[name]@point*weight for name,weight in row),Vector()) for point,row in zip(vertices,weights)]
        low=min(p.z for p in posed);lift=max(0.,-low)
        points={paw:min((posed[i] for i in ids),key=lambda p:p.z) for paw,ids in sole_indices.items()}
        groups=[[points[paw] for paw in paws[:2]],[points[paw] for paw in paws[2:]]]
        heights=[max(p.z+lift for p in group)*scale for group in groups]
        group=min(range(2),key=lambda i:heights[i]);labels.append(group if heights[group]<.012 else None)
        soles.append([-sum(p.y for p in group)*scale/2 for group in groups])
    starts=[i for i in range(n) if labels[i] is not None and labels[i]!=labels[(i-1)%n]]
    assert len(starts)>=2,'Bounding source needs fore and hind stance intervals'
    offsets=[None]*n;segments=[]
    for start in starts:
        group=labels[start];end=start
        while end+1<start+n and labels[(end+1)%n]==group:end+=1
        midpoint=(start+end)/2.;base=math.floor(midpoint);alpha=midpoint-base
        anchor=soles[base%n][group]*(1-alpha)+soles[(base+1)%n][group]*alpha
        for i in range(start,end+1):offsets[i%n]=anchor-speed*(i-midpoint)*dt-soles[i%n][group]
        segments.append({'group':'fore' if group==0 else 'hind','start_phase':start/n,'end_phase':end/n,'samples':end-start+1})
    # Smoothly reset the presentation root while no pair is planted. Hermite
    # endpoint slopes keep the following contact from snapping into place.
    planted=[i for i in range(n) if offsets[i] is not None]
    assert len(planted)<n,'Source bound must retain a real airborne interval'
    for left in planted:
        if offsets[(left+1)%n] is not None:continue
        right=left+1
        while offsets[right%n] is None:right+=1
        width=right-left;value_a=offsets[left];value_b=offsets[right%n]
        slope_a=(value_a-offsets[(left-1)%n]) if offsets[(left-1)%n] is not None else 0.
        slope_b=(offsets[(right+1)%n]-value_b) if offsets[(right+1)%n] is not None else 0.
        for i in range(left+1,right):
            u=(i-left)/width;u2=u*u;u3=u2*u
            offsets[i%n]=(2*u3-3*u2+1)*value_a+(u3-2*u2+u)*width*slope_a+(-2*u3+3*u2)*value_b+(u3-u2)*width*slope_b
    assert all(v is not None and math.isfinite(v) for v in offsets)
    assert max(abs(v) for v in offsets)<.12,('Excessive source root reconciliation',speed,min(offsets),max(offsets))
    offsets.append(offsets[0]);roots=[b.name for b in rig.data.bones if b.parent is None]
    # A shared presentation parent carries the correction. Re-keying two
    # rotating rig roots separately creates small interpolation differences.
    return frames,{'target_stance_speed_mps':speed,'duration':duration,'segments':segments,'offset_range_m':[min(offsets),max(offsets)],'offsets_m':offsets,'roots':roots,'applied_to':'RabbitMotion presentation parent','method':'Authored common longitudinal parent correction from actual weighted paw stances; circular airborne Hermite reset. Source rig channels, relative joint poses, orientations and positive vertical hop retained; entity coordinates untouched.'}
