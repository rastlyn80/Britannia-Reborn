"""Synthetic rig/reader regression tests; no proprietary input required."""
import copy,importlib.util,math,struct,tempfile,unittest
from pathlib import Path
from unittest.mock import patch

spec=importlib.util.spec_from_file_location('creature_pipeline',Path(__file__).with_name('prepare-creatures.py'))
p=importlib.util.module_from_spec(spec);spec.loader.exec_module(p)
a=p.affine

def bone_payload(parent,scales):
    return struct.pack('<I16f',parent,0.,0.,0.,0.,0.,0.,1.,*scales)
def matrix(x=1.,y=1.,z=1.):return [x,0.,0.,0.,y,0.,0.,0.,z]

class CreaturePipelineTests(unittest.TestCase):
    def test_flight_retains_source_vertical_motion_and_sampling_is_bounded(self):
        bone={'name':'root','parent':0,'translation':[0.,0.,0.],'rotation':[0.,0.,0.,1.]}
        model={'bones':[bone],'points':[(0.,0.,0.),(1.,0.,0.),(0.,0.,1.)],
               'normals':[(0.,1.,0.)],'polygons':[(0,1,2,0,0,0)],
               'uv_sets':[[(0.,0.,0.),(1.,0.,0.),(0.,1.,0.)]],'texture_polygons':[(0,1,2)],
               'weights':[[(0,1.)]]*3,'ties':[0]}
        track={'name':'root','translation':{'times':[0.,1.],'values':[[0.,0.,0.],[0.,0.,1.]]},
               'rotation':{'times':[0.],'values':[[0.,0.,0.,1.]]}}
        animation={'bones':[bone],'tracks':[track]}
        test_work=Path(__file__).resolve().parents[1]/'work';test_work.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='synthetic-creature-',dir=test_work) as directory:
            self.assertTrue(Path(directory).resolve().is_relative_to(test_work.resolve()))
            output=Path(directory)/'synthetic.gltf'
            ground=p.td.export_gltf(model,{'Fly':animation},b'png',output,1.)
            flying=p.td.export_gltf(model,{'Fly':animation},b'png',output,1.,preserve_vertical_clips=['Fly'])
            self.assertNotEqual(*ground['clips']['Fly']['floor_offset_range'])
            self.assertEqual(*flying['clips']['Fly']['floor_offset_range'])
            self.assertEqual(flying['clips']['Fly']['floor_policy'],'source_vertical')
            with self.assertRaisesRegex(ValueError,'30..240'):p.td.export_gltf({}, {},b'',output,1.,floor_sample_rate=10000)

    def test_duplicate_auxiliary_names_require_explicit_unused_subtrees(self):
        empty=struct.pack('<II',0,0)+b'\0'
        names=[b'__objectname',b'root',b'aux']
        table=struct.pack('<II',3,0)+b'\0'.join(names)+b'\0'
        entries=[(0xca5e0200,empty,[]),(0xca5e0200,table,[])]
        for object_id,value in enumerate([1,2,2],1):
            entries += [(0xca5e0f00,b'',[0xca5e0f03]),(0xca5e0f01,struct.pack('<I',0),[0xca5e0f03]),
                        (0xca5e0f02,struct.pack('<II',0,value),[0xca5e0f03]),
                        (0xca5e0f04,struct.pack('<I',object_id),[0xca5e0b01]),
                        (0xca5e0506,bone_payload(0,matrix()),[])]
        entries.append((0xca5e0c02,struct.pack('<3I',1,2,3),[]))
        for retained in [None,['aux']]:
            with patch.object(p.td,'chunks',return_value=iter(entries)):
                with self.assertRaisesRegex(ValueError,'Duplicate bone'):
                    p.td.parse(b'',animations_only=True,retained_bone_names=retained)
        with patch.object(p.td,'chunks',return_value=iter(entries)):
            result=p.td.parse(b'',animations_only=True,retained_bone_names=['root'])
        self.assertEqual(result['omitted_duplicate_auxiliary_names'],['aux'])
        self.assertEqual(len({bone['name'] for bone in result['bones']}),3)
        # A retained joint parented beneath an auxiliary node must stay blocked.
        changed=list(entries);index=next(i for i,(kind,_,_) in enumerate(changed) if kind==0xca5e0506)
        changed[index]=(0xca5e0506,bone_payload(1,matrix()),[])
        with patch.object(p.td,'chunks',return_value=iter(changed)):
            with self.assertRaisesRegex(ValueError,'intermediary'):
                p.td.parse(b'',animations_only=True,retained_bone_names=['root'])

    def test_collapsed_bind_seam_normal_keeps_potentially_moving_faces(self):
        model={'points':[(0.,0.,0.),(1.,0.,0.),(0.,1.,0.),(0.,0.,0.)],
               'polygons':[(0,1,2,0,1,2),(3,0,1,3,0,1)]}
        original=copy.deepcopy(model)
        self.assertEqual(p.helper.audit.coincident_surface_vector(model,3),[0.,0.,1.])
        self.assertEqual(model,original)

    def test_unweighted_vertex_interpolation_is_local_and_normalised(self):
        model={'points':[(0.,0.,0.),(1.,0.,0.),(0.,2.,0.),(99.,99.,99.)],
               'polygons':[(0,1,2,0,1,2)],
               'weights':[[(0,0.)],[(1,1.)],[(2,1.)],[(3,1.)]]}
        original=copy.deepcopy(model)
        weights,adjacent=p.repairs.neighbour_weights(model,0)
        self.assertEqual(adjacent,[1,2]);self.assertEqual([bone for bone,_ in weights],[1,2])
        self.assertAlmostEqual(weights[0][1],2./3.)
        self.assertAlmostEqual(sum(w for _,w in weights),1.)
        self.assertEqual(model,original)
        model['weights'][1]=[(1,0.)]
        with self.assertRaisesRegex(ValueError,'unweighted neighbours'):p.repairs.neighbour_weights(model,0)

    def test_only_bounded_untextured_helper_boxes_may_be_omitted(self):
        empty=struct.pack('<II',0,0)+b'\0'
        header=(0xca5e0601,b'',[])
        helper=[header,(0xca5e0801,bytes(8*12),[0xca5e0601]),
                (0xca5e0702,struct.pack('<3I',0,0,0),[0xca5e0601])]
        body=[header,(0xca5e0801,struct.pack('<3f',1.,2.,3.),[0xca5e0601]),
              (0xca5e0702,struct.pack('<5If',1,0,0,1,0,1.),[0xca5e0601])]
        faces=(0xca5e0e06,struct.pack('<13I',12,*([0]*12)),[])
        entries=[(0xca5e0200,empty,[])]*2+helper+body+[faces]
        with patch.object(p.td,'chunks',return_value=iter(entries)):
            result=p.td.parse(b'',skip_unskinned_helpers=True)
        self.assertEqual(result['points'],[(1.,2.,3.)])
        self.assertEqual(result['weights'],[[(0,1.)]])
        textured=list(entries);textured.insert(4,(0xca5e0803,bytes(4+8*12),[0xca5e0601]))
        with patch.object(p.td,'chunks',return_value=iter(textured)):
            with self.assertRaisesRegex(ValueError,'Only untextured'):p.td.parse(b'',skip_unskinned_helpers=True)
        with patch.object(p.td,'chunks',return_value=iter(entries[:-1])):
            with self.assertRaisesRegex(ValueError,'matching untextured'):p.td.parse(b'',skip_unskinned_helpers=True)
        with patch.object(p.td,'chunks',return_value=iter(entries+body)):
            with self.assertRaisesRegex(ValueError,'Exactly one skinned'):p.td.parse(b'',skip_unskinned_helpers=True)

    def test_scale_shear_curve_has_nine_floats_per_key(self):
        empty=struct.pack('<II',0,0)+b'\0'
        header=[0]*13;header[8]=1
        payload=struct.pack('<13If9f',*header,0.,*matrix(2.,3.,4.))
        entries=[(0xca5e0200,empty,[]),(0xca5e0200,empty,[]),(0xca5e1204,payload,[])]
        # Supply one named scene object so the bounded parser can resolve the
        # synthetic track ID without relying on game strings.
        names=[b'__objectname',b'root'];table=struct.pack('<II',2,0)+b'\0'.join(names)+b'\0'
        header[0]=1;payload=struct.pack('<13If9f',*header,0.,*matrix(2.,3.,4.))
        entries=[(0xca5e0200,empty,[]),(0xca5e0200,table,[]),
                 (0xca5e0f00,b'',[0xca5e0f03]),(0xca5e0f01,struct.pack('<I',0),[0xca5e0f03]),
                 (0xca5e0f02,struct.pack('<II',0,1),[0xca5e0f03]),(0xca5e0f04,struct.pack('<I',1),[0xca5e0b01]),
                 (0xca5e1204,payload,[])]
        with patch.object(p.td,'chunks',return_value=iter(entries)):
            result=p.td.parse(b'',animations_only=True,scale_shear_tracks=True)
        self.assertEqual(result['tracks'][0]['scale_shear']['values'],[matrix(2.,3.,4.)])
        entries[-1]=(0xca5e1204,payload[:-4],[])
        with patch.object(p.td,'chunks',return_value=iter(entries)):
            with self.assertRaisesRegex(ValueError,'Truncated animation'):p.td.parse(b'',animations_only=True,scale_shear_tracks=True)

    def test_affine_animation_uses_full_shear_matrix_not_its_first_row(self):
        model={'bones':[{'name':'root','parent':0,'translation':[0.,0.,0.],'rotation':[0.,0.,0.,1.]}],
               'tracks':[{'name':'root','translation':{'times':[0.,1.],'values':[[0.,0.,0.],[0.,0.,0.]]},
                          'rotation':{'times':[0.,1.],'values':[[0.,0.,0.,1.],[0.,0.,0.,1.]]},
                          'scale_shear':{'times':[0.,1.],'values':[matrix(),matrix(2.,1.,1.)]}}],
               'points':[(1.,0.,0.)],'weights':[[(0,1.)]]}
        entries=[(0xca5e0506,bone_payload(0,matrix()),[])]
        with patch.object(p.td,'chunks',return_value=iter(entries)):result,_=a.neutralise(b'',model,p.td)
        self.assertEqual(result['tracks'][0]['rotation']['times'][0],0.)
        self.assertEqual(result['tracks'][0]['rotation']['times'][-1],1.)
        self.assertTrue(all(abs(sum(v*v for v in q)-1.)<1e-8 for q in result['tracks'][0]['rotation']['values']))

    def test_inverse_and_polar_preserve_rotation_with_nonuniform_scale(self):
        rotation=[[0.,-1.,0.],[1.,0.,0.],[0.,0.,1.]]
        basis=a.multiply(rotation,[[2.,0.,0.],[0.,.8,0.],[0.,0.,3.]])
        identity=a.multiply(basis,a.inverse(basis))
        for i in range(3):
            for j in range(3):
                self.assertAlmostEqual(identity[i][j],a.IDENTITY[i][j],places=10)
                self.assertAlmostEqual(a.polar(basis)[i][j],rotation[i][j],places=9)
        q=a.quaternion(rotation)
        self.assertAlmostEqual(abs(q[2]),math.sqrt(.5));self.assertAlmostEqual(abs(q[3]),math.sqrt(.5))

    def test_fixed_reflection_basis_produces_proper_rotation(self):
        reflected=[[-2.,0.,0.],[0.,3.,0.],[0.,0.,1.]]
        result=a.polar(reflected)
        self.assertAlmostEqual(a.determinant(result),1.)
        self.assertEqual(result,a.IDENTITY)
        with self.assertRaises(AssertionError):a.inverse([[0.,0.,0.]]*3)

    def test_affine_neutral_rig_keeps_bind_mesh_and_joint_centres(self):
        model={'bones':[{'name':'root','parent':0,'translation':[0.,0.,0.],'rotation':[0.,0.,0.,1.]},
                        {'name':'child','parent':0,'translation':[1.,2.,0.],'rotation':[0.,0.,0.,1.]}],
               'tracks':[],'points':[[2.,3.,0.]],'weights':[[(0,1.)]],'uv_sets':[[(.2,.3,0.)]]}
        entries=[(0xca5e0506,bone_payload(0,matrix(2.,1.,1.)),[]),(0xca5e0506,bone_payload(0,matrix()),[])]
        original=copy.deepcopy(model)
        with patch.object(p.td,'chunks',return_value=iter(entries)):result,report=a.neutralise(b'',model,p.td)
        self.assertEqual(result['bones'][1]['translation'],[2.,2.,0.])
        self.assertEqual(model,original)
        for key in ['points','weights','uv_sets']:self.assertEqual(result[key],model[key])
        self.assertIn('not native scale/shear',report['method'])

    def test_uniform_scene_units_fold_without_changing_visible_mesh(self):
        model={'bones':[{'name':'root','parent':0,'translation':[0.,0.,0.]},
                        {'name':'child','parent':0,'translation':[1.,2.,3.]}],
               'tracks':[{'name':'child','translation':{'times':[0.],'values':[[2.,3.,4.]]}}],
               'points':[(1.,2.,3.)],'weights':[[(0,1.)]]}
        entries=[(0xca5e0506,bone_payload(0,matrix(2.,2.,2.)),[]),(0xca5e0506,bone_payload(0,matrix(.5,.5,.5)),[])]
        with patch.object(p.td,'chunks',return_value=iter(entries)):result,changes=p.fold_uniform_scales(b'',model)
        self.assertEqual(result['bones'][1]['translation'],[2.,4.,6.])
        self.assertEqual(result['tracks'][0]['translation']['values'],[[4.,6.,8.]])
        self.assertEqual(result['points'],model['points']);self.assertEqual(len(changes),2)

    def test_invisible_vertices_cannot_dictate_visible_floor(self):
        model={'points':[(0,0,0),(1,0,0),(0,1,0),(0,0,-100)],'weights':[[(i,1.)] for i in range(4)],
               'polygons':[(0,2,1,4,5,6)],'texture_polygons':[(4,5,6)],'uv_sets':[[(.2,.3,0.)]]}
        result,omitted=p.visible_vertices(model)
        self.assertEqual(omitted,[3]);self.assertEqual(result['points'],model['points'][:3])
        self.assertEqual(result['texture_polygons'],model['texture_polygons'])
        self.assertEqual(result['polygons'],model['polygons'])
        self.assertEqual(len(model['points']),4)

    def test_scene_root_alias_does_not_rename_a_master_mage_mesh_leaf(self):
        empty=struct.pack('<II',0,0)+b'\0'
        names=[b'__objectname',b'master_mages_evil_mage_master',b'mages_evil_mage_master']
        table=struct.pack('<II',len(names),0)+b'\0'.join(names)+b'\0'
        entries=[(0xca5e0200,empty,[]),(0xca5e0200,table,[])]
        for value in [1,2]:
            entries += [(0xca5e0f00,b'',[0xca5e0f03]),(0xca5e0f01,struct.pack('<I',0),[0xca5e0f03]),
                        (0xca5e0f02,struct.pack('<II',0,value),[0xca5e0f03]),
                        (0xca5e0f04,struct.pack('<I',value),[0xca5e0b01]),(0xca5e0506,bone_payload(0,matrix()),[])]
        entries.append((0xca5e0c02,struct.pack('<2I',1,2),[]))
        with patch.object(p.td,'chunks',return_value=iter(entries)):
            with self.assertRaisesRegex(ValueError,'Duplicate bone'):p.td.parse(b'',animations_only=True)
        with patch.object(p.td,'chunks',return_value=iter(entries)):
            result=p.td.parse(b'',animations_only=True,scene_root_names=True)
        self.assertEqual([b['name'] for b in result['bones']],['granny_master','mages_evil_mage_master'])

if __name__=='__main__':unittest.main()
