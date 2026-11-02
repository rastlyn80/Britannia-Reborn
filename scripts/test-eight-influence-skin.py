"""Source-free skin limits, complete glTF weights and lossless refinement."""
import base64
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
def load(name,file):
    spec=importlib.util.spec_from_file_location(name,ROOT/'scripts'/file);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
TD=load('eight_td','import-third-dawn.py')
SMOOTH=load('eight_smooth','third-dawn-subdivide.py')
REPAIR=load('indexed_normals','solen-warrior-normals.py')
_header=bytearray(18);_header[2]=2;struct.pack_into('<HHBB',_header,12,1,1,24,0)
PNG=TD.png_from_tga(_header+bytes([255,255,255]))
TEMP=ROOT/'work/eight-skin-tests';TEMP.mkdir(parents=True,exist_ok=True)

def model(count=5):
    bones=[dict(name='root' if i==0 else 'joint_'+str(i),parent=0,translation=[0.,0.,0.],rotation=[0.,0.,0.,1.]) for i in range(max(5,count))]
    return dict(points=[(0.,0.,0.),(1.,0.,1.),(0.,1.,1.)],normals=[(0.,-1.,0.)],
                polygons=[(0,1,2,0,0,0)],texture_polygons=[(0,1,2)],uv_sets=[[(0.,0.,0.),(1.,0.,0.),(0.,1.,0.)]],
                bones=bones,ties=list(range(len(bones))),weights=[[(0,1.)],[(i,1./count) for i in range(count)],[(0,1.)]])

def motion(mesh):
    return {'Probe':dict(bones=copy.deepcopy(mesh['bones']),tracks=[dict(name='joint_4',
        translation=dict(times=[0.,1.],values=[[0.,0.,0.],[0.,0.,0.]]),
        rotation=dict(times=[0.,1.],values=[[0.,0.,0.,1.],[0.,0.,2**-.5,2**-.5]]))])}

def values(gltf,index):
    a=gltf['accessors'][index];view=gltf['bufferViews'][a['bufferView']];data=base64.b64decode(gltf['buffers'][0]['uri'].split(',')[1]);width={'VEC3':3,'VEC4':4}[a['type']];fmt={5126:'f',5123:'H'}[a['componentType']]
    offset=view.get('byteOffset',0)+a.get('byteOffset',0);return list(struct.iter_unpack('<'+fmt*width,data[offset:offset+a['count']*width*struct.calcsize(fmt)]))

class EightSkin(unittest.TestCase):
    def test_indexed_normal_repair_preserves_all_other_bytes(self):
        points=struct.pack('<9f',0.,0.,0.,1.,0.,0.,0.,1.,0.)
        normals=struct.pack('<6f',float('nan'),float('nan'),float('nan'),0.,0.,1.)
        faces=struct.pack('<6I',0,1,2,0,1,1);raw=b'prefix'+normals+b'suffix'
        entries=[(0xca5e0801,points,[]),(0xca5e0802,normals,[]),(0xca5e0901,faces,[])]
        digest=hashlib.sha256(raw).hexdigest()
        with patch.object(TD,'chunks',return_value=iter(entries)):
            fixed,report=REPAIR.repair(raw,TD,digest,[0])
        self.assertEqual(fixed[:6],raw[:6]);self.assertEqual(fixed[18:],raw[18:])
        self.assertEqual(struct.unpack_from('<3f',fixed,6),(0.,0.,1.));self.assertEqual(report['permitted_bytes'],12)
        with self.assertRaisesRegex(ValueError,'hash mismatch'):REPAIR.repair(raw,TD,'0'*64,[0])
        with patch.object(TD,'chunks',return_value=iter(entries)):
            with self.assertRaisesRegex(ValueError,'differ from repair contract'):REPAIR.repair(raw,TD,digest,[1])
    def test_four_slot_outputs_match_pre_extension_reference(self):
        mesh=model(4)
        with tempfile.TemporaryDirectory(dir=TEMP) as tmp:
            path=Path(tmp)/'legacy.gltf';TD.export_gltf(mesh,motion(mesh),PNG,path,1.)
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),'9caf91ee4584f8a61644cfb9da47b18e3d5659db26862e3cf8adda8ed3db78cd')
        refined,stats=SMOOTH.refine(mesh)
        self.assertEqual(hashlib.sha256(json.dumps([refined,stats],sort_keys=True).encode()).hexdigest(),'d1cca600dcb2b264b7546932a028b7eba4446fb8d46961bcbecaa0add8d49382')
    def parse_weights(self,count,**options):
        strings=struct.pack('<II',0,0)+b'\0';skin=struct.pack('<4I',1,0,0,count)+b''.join(struct.pack('<If',i,1./count) for i in range(count))
        entries=[(0xca5e0200,strings,[]),(0xca5e0200,strings,[]),(0xca5e0702,skin,[])]
        with patch.object(TD,'chunks',return_value=iter(entries)):return TD.parse(b'',**options)
    def test_reader_requires_explicit_opt_in_and_preserves_fifth(self):
        with self.assertRaisesRegex(ValueError,'Unsupported GRN vertex influences'):self.parse_weights(5)
        actual=self.parse_weights(5,max_influences=8)
        self.assertEqual([bone for bone,_ in actual['weights'][0]],list(range(5)))
        self.assertTrue(all(abs(w-.2)<1e-7 for _,w in actual['weights'][0]))
        with self.assertRaises(ValueError):self.parse_weights(9,max_influences=8)
        with self.assertRaises(ValueError):self.parse_weights(5,max_influences=6)
    def test_export_refuses_silent_loss_and_writes_both_joint_sets(self):
        mesh=model();saved=copy.deepcopy(mesh)
        with tempfile.TemporaryDirectory(dir=TEMP) as tmp:
            path=Path(tmp)/'fixture.gltf'
            with self.assertRaisesRegex(ValueError,'Source influences exceed'):TD.export_gltf(mesh,motion(mesh),PNG,path,1.)
            TD.export_gltf(mesh,motion(mesh),PNG,path,1.,max_influences=8)
            gltf=json.loads(path.read_text());a=gltf['meshes'][0]['primitives'][0]['attributes']
            joints=values(gltf,a['JOINTS_0'])[1]+values(gltf,a['JOINTS_1'])[1]
            weights=values(gltf,a['WEIGHTS_0'])[1]+values(gltf,a['WEIGHTS_1'])[1]
            self.assertEqual(joints,(0,1,2,3,4,0,0,0));self.assertGreater(weights[4],.19999)
            self.assertAlmostEqual(sum(weights),1.,places=6)
            self.assertEqual(mesh,saved)
    def test_refinement_retains_all_original_influences_and_source(self):
        mesh=model();saved=copy.deepcopy(mesh)
        refined,stats=SMOOTH.refine(mesh,levels=2,max_influences=8)
        self.assertEqual(mesh,saved);self.assertEqual(stats['triangles_after'],16)
        for index in range(3):
            self.assertEqual(dict(refined['weights'][index]),dict(mesh['weights'][index]))
        self.assertTrue(all(len(w)<=8 and abs(sum(v for _,v in w)-1.)<1e-7 for w in refined['weights']))
        self.assertTrue(any(dict(w).get(4,0.)>0 for w in refined['weights'][3:]))
    def test_nine_bone_union_is_rejected_without_truncation(self):
        entries=[([(i,1.)],1./9) for i in range(9)]
        with self.assertRaisesRegex(ValueError,'exceed eight bones'):SMOOTH.mix_weights(entries,8)
        # Legacy four-slot refinement keeps its established approximation.
        self.assertEqual(len(SMOOTH.mix_weights(entries)),4)
    def test_pure_eighth_influence_survives(self):
        pairs=[(7,1.)];actual=SMOOTH.mix_weights([(pairs,1.)],8)
        self.assertEqual(actual,pairs)
        mesh=model(8)
        with tempfile.TemporaryDirectory(dir=TEMP) as tmp:
            path=Path(tmp)/'eight.gltf';TD.export_gltf(mesh,motion(mesh),PNG,path,1.,max_influences=8);gltf=json.loads(path.read_text());a=gltf['meshes'][0]['primitives'][0]['attributes']
            self.assertEqual(values(gltf,a['JOINTS_1'])[1],(4,5,6,7))
            self.assertEqual(values(gltf,a['WEIGHTS_1'])[1],(.125,)*4)

def fixture():
    folder=ROOT/'Viewer/local-art/diagnostics/eight-skin';folder.mkdir(parents=True,exist_ok=True);mesh=model()
    TD.export_gltf(mesh,motion(mesh),PNG,folder/'five.gltf',1.,max_influences=8)
    print('Source-free five-influence fixture:',folder/'five.gltf')

if __name__=='__main__':
    import sys
    if '--fixture' in sys.argv:fixture()
    else:unittest.main()
