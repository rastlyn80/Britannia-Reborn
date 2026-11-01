"""Authored cervid head strike and grazing on preserved source rigs.

Fore and rear limbs use three measured segments with a planted hoof target.
No recovered original choreography or model-table linkage is asserted.
"""
import copy,importlib.util
from pathlib import Path
spec=importlib.util.spec_from_file_location('cervid_pose_support',Path(__file__).with_name('creature-humanoid-actions.py'))
h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h)

def planted_leg(pose,baseline,upper,lower,fetlock,hoof,forward,height,amount):
    names=[upper,lower,fetlock,hoof];points=[pose.world(name)[1][:] for name in names]
    lengths=[h.length(h.sub(b,a)) for a,b in zip(points,points[1:])];origin=points[0][:];target=baseline.world(hoof)[1]
    assert h.length(h.sub(target,origin))<sum(lengths),'Cervid stance requires reachable measured limbs'
    if h.length(h.cross(h.sub(points[1],points[0]),h.sub(points[2],points[1])))<1e-8:
        points[1]=h.add(points[1],h.mul(forward,height*.02*amount))
    # FABRIK distributes the bend through shoulder/elbow/fetlock instead of
    # locking the lower leg and folding only the scapula. Source lengths stay.
    for _ in range(64):
        points[-1]=target[:]
        for i in [2,1,0]:points[i]=h.add(points[i+1],h.mul(h.unit(h.sub(points[i],points[i+1])),lengths[i]))
        points[0]=origin[:]
        for i in range(3):points[i+1]=h.add(points[i],h.mul(h.unit(h.sub(points[i+1],points[i])),lengths[i]))
        if h.length(h.sub(points[-1],target))<1e-9:break
    q,actual=pose.world(upper);_,child=pose.world(lower)
    pose.world_rotation(upper,h.qmul(h.between(h.sub(child,actual),h.sub(points[1],actual)),q))
    # Exact final two-link solve removes accumulated positional error without
    # stretching a segment; the FABRIK knee chooses the source bend plane.
    pose.limb(lower,fetlock,hoof,target,points[2])
    pose.world_rotation(hoof,baseline.world(hoof)[0])

def gesture(body,idle,label):
    assert label in ['Attack2','Eat']
    baseline=h.Pose(body,idle);up=[0.,0.,1.]
    left=h.unit(h.sub(baseline.world('bip01 l clavicle')[1],baseline.world('bip01 r clavicle')[1]));left=h.unit([left[0],left[1],0.]);forward=h.unit(h.cross(left,up))
    # Antlers change total mesh height without lengthening the neck or legs.
    height=baseline.world('bip01 neck')[1][2]-min(p[2] for p in body['points'])
    result=copy.deepcopy(idle);source={b['name']:b for b in idle['bones']}
    result['bones']=[dict(b,translation=source.get(b['name'],b)['translation'],rotation=source.get(b['name'],b)['rotation']) for b in body['bones']]
    result['tracks']=[{'name':b['name'],'translation':{'times':[],'values':[]},'rotation':{'times':[],'values':[]}} for b in body['bones']]
    duration=.95 if label=='Attack2' else 2.8;frames=round(duration*60)+1
    for frame in range(frames):
        u=frame/(frames-1);pose=h.Pose(body,idle)
        amount=h.smooth(u/.27)*(1.-h.smooth((u-.67)/.33)) if label=='Attack2' else h.smooth(u/.28)*(1.-h.smooth((u-.72)/.28))
        if amount>1e-8:
            if label=='Attack2':
                stroke=h.smooth((u-.25)/.28);pitch=(-.14+.8*stroke)*amount
                # Distal neck nodes leave the shoulder/foreleg branch fixed.
                pose.turn('bip01 neck1',left,pitch*.6);pose.turn('bip01 neck2',left,pitch*.4)
                pose.turn('bip01 head',left,-.08*amount)
            else:
                pose.translate('bip01',h.mul(up,-height*.07*amount))
                pose.turn('bip01 spine',left,.08*amount);pose.turn('bip01 spine1',left,.06*amount)
                # Counter-rotate the skull as the neck lowers: forward antler
                # tines must not drive the whole animal upward off its hooves.
                for name,angle in [('bip01 neck',.55),('bip01 neck1',.65),('bip01 neck2',.4),('bip01 head',-.95)]:pose.turn(name,left,angle*amount)
                for side in ['l','r']:
                    prefix='bip01 '+side+' '
                    planted_leg(pose,baseline,prefix+'thigh',prefix+'calf',prefix+'horselink',prefix+'foot',forward,height,amount)
                    planted_leg(pose,baseline,prefix+'clavicle',prefix+'upperarm',prefix+'forearm',prefix+'hand',forward,height,amount)
        for i,track in enumerate(result['tracks']):
            for channel,value in [('translation',pose.positions[i]),('rotation',pose.rotations[i])]:track[channel]['times'].append(duration*u);track[channel]['values'].append(list(value))
    return result

def install(body,clips,authored,aliases,stem):
    if stem not in ['deer_doe','deer_stag']:return False
    if 'Attack2' not in clips:
        clips['Attack2']=gesture(body,clips['Idle'],'Attack2')
        authored['Attack2']='Authored grounded head/neck thrust distinct from the recovered rearing strike; four hoof anchors and original rig retained, not recovered UO choreography'
    if 'Eat' not in clips:
        clips['Eat']=gesture(body,clips['Idle'],'Eat')
        authored['Eat']='Authored distributed grazing bend with measured three-segment fore/rear leg fitting and planted hooves; not recovered UO choreography'
    return True
