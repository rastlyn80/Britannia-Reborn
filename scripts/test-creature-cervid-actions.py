"""Independent synthetic cervid anatomy and planted-hoof checks; no game data."""
import copy,importlib.util,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('cervid_actions',Path(__file__).with_name('creature-cervid-actions.py'))
c=importlib.util.module_from_spec(spec);spec.loader.exec_module(c);h=c.h

def fixture():
    bones=[]
    def add(name,parent,p):
        i=len(bones);bones.append({'name':name,'parent':i if parent is None else parent,'translation':p,'rotation':[0.,0.,0.,1.]});return i
    root=add('__root',None,[0.,0.,0.]);master=add('granny_master',root,[0.,0.,0.]);hips=add('bip01',master,[0.,.35,.75]);pelvis=add('bip01 pelvis',hips,[0.,0.,0.]);spine=add('bip01 spine',pelvis,[0.,0.,.05]);s1=add('bip01 spine1',spine,[0.,-.5,0.]);neck=add('bip01 neck',s1,[0.,-.35,.05]);n1=add('bip01 neck1',neck,[0.,-.10,.10]);n2=add('bip01 neck2',n1,[0.,-.15,.12]);add('bip01 head',n2,[0.,-.15,.05])
    for side,sign in [('l',1.),('r',-1.)]:
        thigh=add('bip01 '+side+' thigh',spine,[sign*.12,0.,-.05]);calf=add('bip01 '+side+' calf',thigh,[0.,-.1,-.25]);hock=add('bip01 '+side+' horselink',calf,[0.,.1,-.25]);add('bip01 '+side+' foot',hock,[0.,0.,-.17])
        clav=add('bip01 '+side+' clavicle',neck,[sign*.12,0.,-.03]);upper=add('bip01 '+side+' upperarm',clav,[0.,0.,-.26]);fore=add('bip01 '+side+' forearm',upper,[0.,0.,-.24]);add('bip01 '+side+' hand',fore,[0.,0.,-.24])
    body={'bones':bones,'points':[[0.,0.,0.],[0.,0.,1.3]]}
    idle={'bones':copy.deepcopy(bones),'tracks':[{'name':b['name'],'translation':{'times':[0.,1.],'values':[b['translation'][:],b['translation'][:]]},'rotation':{'times':[0.,1.],'values':[b['rotation'][:],b['rotation'][:]]}} for b in bones]}
    return body,idle

def sample(body,clip,phase):
    out=copy.deepcopy(clip);index=round((len(out['tracks'][0]['rotation']['times'])-1)*phase)
    for track in out['tracks']:
        for channel in ['translation','rotation']:track[channel]={'times':[0.],'values':[track[channel]['values'][index]]}
    return h.Pose(body,out)

class CervidActionsTests(unittest.TestCase):
    def test_both_actions_preserve_four_hooves_and_measured_segment_lengths(self):
        body,idle=fixture();base=h.Pose(body,idle)
        for label in ['Attack2','Eat']:
            clip=c.gesture(body,idle,label)
            for phase in [0.,.25,.5,.75,1.]:
                pose=sample(body,clip,phase)
                for side in ['l','r']:
                    for end in ['hand','foot']:
                        name='bip01 '+side+' '+end;self.assertLess(h.length(h.sub(pose.world(name)[1],base.world(name)[1])),1e-7)
                    for chain in [['clavicle','upperarm','forearm','hand'],['thigh','calf','horselink','foot']]:
                        for a,b in zip(chain,chain[1:]):
                            a='bip01 '+side+' '+a;b='bip01 '+side+' '+b
                            self.assertAlmostEqual(h.length(h.sub(pose.world(a)[1],pose.world(b)[1])),h.length(h.sub(base.world(a)[1],base.world(b)[1])),places=8)

    def test_strike_is_distal_and_grazing_lowers_the_actual_head(self):
        body,idle=fixture();base=h.Pose(body,idle)
        attack=sample(body,c.gesture(body,idle,'Attack2'),.5)
        eat=sample(body,c.gesture(body,idle,'Eat'),.5)
        self.assertGreater(h.length(h.sub(attack.world('bip01 head')[1],base.world('bip01 head')[1])),.1)
        self.assertLess(eat.world('bip01 head')[1][2],base.world('bip01 head')[1][2]-.5)
        for side in ['l','r']:
            name='bip01 '+side+' clavicle';self.assertEqual(attack.world(name),base.world(name))

    def test_antler_height_does_not_change_the_cervical_or_leg_motion(self):
        body,idle=fixture();antlered=copy.deepcopy(body);antlered['points'].append([0.,0.,2.])
        for label in ['Eat','Attack2']:self.assertEqual(c.gesture(body,idle,label),c.gesture(antlered,idle,label))

    def test_closed_endpoints_original_inputs_and_unrelated_models(self):
        body,idle=fixture();original=copy.deepcopy((body,idle));base=h.Pose(body,idle)
        for label in ['Eat','Attack2']:
            clip=c.gesture(body,idle,label)
            for phase in [0.,1.]:
                pose=sample(body,clip,phase)
                for i in range(len(body['bones'])):self.assertLess(h.length(h.sub(pose.world(i)[1],base.world(i)[1])),1e-8)
        self.assertEqual((body,idle),original)
        clips={'Idle':idle};self.assertFalse(c.install(body,clips,{}, {},'unrelated'));self.assertEqual(list(clips),['Idle'])

if __name__=='__main__':unittest.main()
