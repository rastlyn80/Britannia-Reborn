"""Anatomical IK/gesture invariants on synthetic rigs; no game inputs."""
import copy, importlib.util, math, unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('humanoid_actions',Path(__file__).with_name('creature-humanoid-actions.py'))
h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h)

def fixture():
    bones=[]
    def bone(name,parent,p):
        index=len(bones);bones.append({'name':name,'parent':parent if parent is not None else index,'translation':p,'rotation':[0.,0.,0.,1.]});return index
    root=bone('__root',None,[0.,0.,0.]);master=bone('granny_master',root,[0.,0.,0.]);hips=bone('bip_01',master,[0.,0.,.9]);pelvis=bone('bip_01 pelvis',hips,[0.,0.,0.]);spine=pelvis
    for name in ['spine','spine1','spine2','spine3']:spine=bone('bip_01 '+name,spine,[0.,0.,.13])
    bone('bip_01 head',spine,[0.,-.08,.18])
    for side,sign in [('l',1.),('r',-1.)]:
        arm=bone('bip_01 '+side+' upperarm',spine,[sign*.2,0.,0.]);elbow=bone('bip_01 '+side+' forearm',arm,[sign*.3,0.,0.]);hand=bone('bip_01 '+side+' hand',elbow,[sign*.3,0.,0.]);bone('cp_grasp_'+side+'hand',hand,[sign*.04,0.,0.])
        thigh=bone('bip_01 '+side+' thigh',pelvis+1,[sign*.13,0.,-.13]);calf=bone('bip_01 '+side+' calf',thigh,[0.,0.,-.4]);bone('bip_01 '+side+' foot',calf,[0.,-.08,-.4])
    body={'bones':bones,'points':[[0.,0.,0.],[0.,0.,1.8]]}
    idle={'bones':copy.deepcopy(bones),'tracks':[{'name':b['name'],'translation':{'times':[0.,1.],'values':[b['translation']]*2},'rotation':{'times':[0.,1.],'values':[b['rotation']]*2}} for b in bones]}
    return body,idle

class HumanoidActionsTests(unittest.TestCase):
    def test_rotated_ancestor_ik_reaches_target_without_stretch(self):
        body,idle=fixture();pose=h.Pose(body,idle);pose.turn('granny_master',[0.,0.,1.],.7)
        upper,lower,end=['bip01 l '+name for name in ['upperarm','forearm','hand']]
        origin=pose.world(upper)[1];before=[h.length(h.sub(pose.world(b)[1],pose.world(a)[1])) for a,b in [(upper,lower),(lower,end)]]
        target=h.add(origin,[.12,-.35,.18]);pose.limb(upper,lower,end,target,h.add(origin,[.3,.1,-.2]))
        self.assertLess(h.length(h.sub(pose.world(end)[1],target)),1e-8)
        for expected,(a,b) in zip(before,[(upper,lower),(lower,end)]):self.assertAlmostEqual(h.length(h.sub(pose.world(b)[1],pose.world(a)[1])),expected,places=9)

    def test_unreachable_target_is_bounded_by_measured_reach(self):
        body,idle=fixture();pose=h.Pose(body,idle);origin=pose.world('bip01 l upperarm')[1]
        fitted=pose.limb('bip01 l upperarm','bip01 l forearm','bip01 l hand',h.add(origin,[100.,0.,0.]),h.add(origin,[0.,0.,1.]))
        self.assertLess(h.length(h.sub(fitted,origin)),.6)
        self.assertLess(h.length(h.sub(pose.world('bip01 l hand')[1],fitted)),1e-8)

    def test_crouch_retains_feet_and_source_grip(self):
        body,idle=fixture();baseline=h.Pose(body,idle);clip=h.gesture(body,idle,'Pillage')
        mid=copy.deepcopy(clip)
        for track in mid['tracks']:
            for channel in ['translation','rotation']:
                stream=track[channel];stream['values']=[stream['values'][len(stream['values'])//2]];stream['times']=[0.]
        pose=h.Pose(body,mid)
        for side in ['l','r']:
            foot='bip01 '+side+' foot';self.assertLess(h.length(h.sub(pose.world(foot)[1],baseline.world(foot)[1])),1e-7)
            hand='bip01 '+side+' hand';index=pose.names[hand.replace('_','')];self.assertAlmostEqual(abs(h.dot(pose.rotations[index],baseline.rotations[index])),1.,places=8)
        self.assertLess(pose.world('bip01 head')[1][2],baseline.world('bip01 head')[1][2]-.3)

    def test_endpoints_match_idle_and_missing_attachment_leaves_survive(self):
        body,idle=fixture();idle['bones']=[b for b in idle['bones'] if not b['name'].startswith('cp_')]
        original=copy.deepcopy(idle)
        for label in ['Cast','Pillage','Attack2','Attack3']:
            clip=h.gesture(body,idle,label);self.assertEqual(len(clip['bones']),len(body['bones']))
            self.assertTrue({t['name'] for t in clip['tracks']}<={b['name'] for b in clip['bones']})
            for track in clip['tracks']:
                for channel in ['translation','rotation']:self.assertLess(max(abs(a-b) for a,b in zip(track[channel]['values'][0],track[channel]['values'][-1])),1e-8)
        self.assertEqual(idle,original)

    def test_shaman_ground_slap_is_explicit_reuse(self):
        body,idle=fixture();clips={'Idle':idle,'Stomp':copy.deepcopy(idle)};authored={};aliases={}
        h.install(body,clips,authored,aliases,'orcs_orc_shaman')
        self.assertEqual(clips['Pillage'],clips['Stomp']);self.assertIn('Pillage',aliases);self.assertIn('Cast',authored)
        untouched={'Idle':idle};h.install(body,untouched,{}, {},'unrelated_creature');self.assertEqual(list(untouched),['Idle'])

    def test_cast_compensates_thighs_parented_to_the_spine(self):
        body,idle=fixture();baseline=h.Pose(body,idle);clip=h.gesture(body,idle,'Cast')
        for track in clip['tracks']:
            for channel in ['translation','rotation']:
                stream=track[channel];stream['values']=[stream['values'][len(stream['values'])//2]];stream['times']=[0.]
        pose=h.Pose(body,clip)
        for side in ['l','r']:
            name='bip01 '+side+' foot';self.assertLess(h.length(h.sub(pose.world(name)[1],baseline.world(name)[1])),1e-7)

    def test_overhead_and_sweep_have_different_real_hand_paths(self):
        body,idle=fixture();paths=[]
        for label in ['Attack2','Attack3']:
            clip=h.gesture(body,idle,label);frames=len(clip['tracks'][0]['rotation']['values']);positions=[]
            for frame in [round((frames-1)*.25),round((frames-1)*.5)]:
                sample=copy.deepcopy(clip)
                for track in sample['tracks']:
                    for channel in ['translation','rotation']:track[channel]={'times':[0.],'values':[track[channel]['values'][frame]]}
                pose=h.Pose(body,sample);positions.append(pose.world('bip01 r hand')[1])
                for side in ['l','r']:
                    foot='bip01 '+side+' foot';self.assertLess(h.length(h.sub(pose.world(foot)[1],h.Pose(body,idle).world(foot)[1])),1e-7)
            paths.append(positions)
        self.assertGreater(h.length(h.sub(paths[0][0],paths[1][0])),.15)
        self.assertGreater(paths[0][0][2],paths[0][1][2]+.2)

if __name__=='__main__':unittest.main()
