"""Boundary tests for static clothing/proxy import; no game data."""
import unittest,tempfile
from pathlib import Path
from mhclo_inspect import parse_proxy,parse_obj,offset_scales
TEST_WORK=Path(__file__).resolve().parents[1]/'work/free-equipment'
TEST_WORK.mkdir(parents=True,exist_ok=True)
HEADER='basemesh hm08\nx_scale 0 1 1\ny_scale 0 1 1\nz_scale 0 1 1\nobj_file cloth.obj\nmaterial cloth.mhmat\nverts 0\n'
class ProxyBoundaries(unittest.TestCase):
 def test_signed_reference_box_offsets(self):
  header='basemesh hm08\nl_shear_x 0 1 3 1\nl_shear_y 0 1 4 2\nl_shear_z 0 1 8 6\nobj_file cloth.obj\nverts 0\n'
  data=self.read(header+'0\n')
  for value in offset_scales(data['fields'],[(.3,-.8,.4),(.1,-.6,.2)]).values():self.assertAlmostEqual(value,.1)
  with self.assertRaises(ValueError):self.read(header.replace('3 1','3 3')+'0\n')
 def test_official_hair_material_after_verts(self):
  d=self.read(HEADER+'material long01.mhmat\n0\n')
  self.assertEqual(d['fields']['material'],'long01.mhmat');self.assertEqual(len(d['rows']),1)
 def read(self,text):
  with tempfile.TemporaryDirectory(dir=Path(__file__).resolve().parents[1]/"work/free-equipment") as d:
   self.assertTrue(Path(d).resolve().is_relative_to(Path(__file__).resolve().parents[1]));p=Path(d)/'fixture.mhclo';p.write_text(text);return parse_proxy(p)
 def test_extrapolating_weights_single_vertex_and_coverage_ranges(self):
  d=self.read(HEADER+'1 2 3 -0.1 0.5 0.6 0.01 0 0\n4\ndelete_verts\n1 - 3 7\n')
  self.assertEqual(d['rows'][0][1],(-.1,.5,.6));self.assertEqual(d['rows'][1],((4,4,4),(1.,0.,0.),(0.,0.,0.)));self.assertEqual(d['deleted'],{1,2,3,7})
 def test_rejects_bad_numeric_rows_and_ranges(self):
  for row in ['1 2 3 0.2 0.2 0.2 0 0 0','1 2 3 nan 0 1 0 0 0','-1','1 2 3']:
   with self.subTest(row=row),self.assertRaises(ValueError):self.read(HEADER+row+'\n')
  with self.assertRaises(ValueError):self.read(HEADER+'0\ndelete_verts\n5 - 2\n')
 def test_rejects_wrong_mesh_and_zero_reference_distance(self):
  for header in [HEADER.replace('hm08','unknown'),HEADER.replace('x_scale 0 1 1','x_scale 0 1 0')]:
   with self.assertRaises(ValueError):self.read(header+'0\n')
 def test_obj_preserves_uv_seams_and_body_vertex_identity(self):
  with tempfile.TemporaryDirectory(dir=Path(__file__).resolve().parents[1]/"work/free-equipment") as d:
   self.assertTrue(Path(d).resolve().is_relative_to(Path(__file__).resolve().parents[1]));p=Path(d)/'a.obj';p.write_text('v 0 0 0\nv 1 0 0\nv 0 1 0\nvt 0 0\nvt 1 0\nvt 0 1\nvt 1 1\ng body\nf 1/1 2/2 3/3\ng helper\nf 1/4 3/3 2/2\n')
   a=parse_obj(p);self.assertEqual(a['body_ids'],{0,1,2});self.assertNotEqual(a['face_uv'][0][0],a['face_uv'][1][0]);self.assertEqual(a['faces'][0][0],a['faces'][1][0])
if __name__=='__main__':unittest.main()
