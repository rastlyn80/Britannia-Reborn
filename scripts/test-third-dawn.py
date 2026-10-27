"""Synthetic importer boundary/coordinate tests; no game data required."""
import importlib.util
from pathlib import Path
import struct
import unittest
import zlib

spec = importlib.util.spec_from_file_location('third_dawn', Path(__file__).with_name('import-third-dawn.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
wardrobe_spec = importlib.util.spec_from_file_location('wardrobe', Path(__file__).with_name('prepare-third-dawn-human.py'))
wardrobe = importlib.util.module_from_spec(wardrobe_spec)
wardrobe_spec.loader.exec_module(wardrobe)
anatomy_spec = importlib.util.spec_from_file_location('anatomy', Path(__file__).with_name('prepare-third-dawn-rounded.py'))
anatomy = importlib.util.module_from_spec(anatomy_spec)
anatomy_spec.loader.exec_module(anatomy)


class ImportBoundaries(unittest.TestCase):
    def test_anatomy_correction_is_local_symmetric_and_keeps_rig_uvs(self):
        model = dict(points=[(-.109,-.128,1.255),(.109,-.128,1.255),
                             (-.05,-.06,1.60),(.05,-.06,1.60),(0.,0.,.2)],
                     bones=[dict(name='bip01 spine2'),dict(name='bip01 head')],
                     ties=[0,1], weights=[[(0,1.)],[(0,1.)],[(1,1.)],[(1,1.)],[(0,1.)]],
                     uv_sets=[[(.1,.2,0.)]])
        result = anatomy.anatomy_source(model)
        self.assertEqual(result['points'][4], model['points'][4])
        for left,right in [(0,1),(2,3)]:
            self.assertAlmostEqual(result['points'][left][0], -result['points'][right][0])
            self.assertEqual(result['points'][left][1:], result['points'][right][1:])
        self.assertGreater(result['points'][0][1], model['points'][0][1])
        self.assertGreater(result['points'][0][2], model['points'][0][2])
        self.assertEqual(model['points'][0], (-.109,-.128,1.255))
        for key in ['bones','ties','weights','uv_sets']: self.assertEqual(result[key],model[key])
        import math
        self.assertLess(max(math.dist(a,b) for a,b in zip(result['points'],model['points'])), .032)
        old = anatomy.region_strengths(model)
        new = anatomy.region_strengths(model, anatomy=True)
        self.assertGreater(new[0],old[0])
        self.assertEqual(new[4],old[4])

    def test_subdivision_preserves_uv_seams_skin_and_displacement_budget(self):
        model = dict(points=[(0., 0., 0.), (1., 0., 0.), (0., 1., 0.), (0., 0., 1.)],
                     polygons=[(0, 2, 1, 0, 2, 1), (0, 1, 3, 0, 1, 3),
                               (0, 3, 2, 0, 3, 2), (1, 2, 3, 1, 2, 3)],
                     normals=[(0., 0., 1.)] * 4, bones=[dict(name='root'), dict(name='joint')],
                     ties=[0, 1], weights=[[(0, 1.)], [(0, .4), (1, .6)], [(1, 1.)], [(1, 1.)]],
                     uv_sets=[[(0., 0., 0.), (1., 0., 0.), (0., 1., 0.),
                               (2., 0., 0.), (3., 0., 0.), (2., 1., 0.)]],
                     texture_polygons=[(0, 1, 2), (3, 4, 5), (0, 1, 2), (3, 4, 5)])
        refined, report = wardrobe.smooth.refine(model, levels=2, maximum=.01)
        self.assertEqual(len(refined['polygons']), 64)
        self.assertEqual(len(refined['points']), 34)
        self.assertLessEqual(report['measured_max_displacement'], .01000001)
        self.assertEqual(refined['bones'], model['bones'])
        self.assertTrue(any(p[0] > 2 for p in refined['uv_sets'][0]))
        for weights in refined['weights']:
            self.assertLessEqual(len(weights), 4)
            self.assertAlmostEqual(sum(w for _, w in weights), 1.)
        self.assertEqual(len(model['points']), 4)
        with self.assertRaises(ValueError): wardrobe.smooth.refine(model, levels=3)

    def test_local_rounding_pins_unselected_geometry_and_validates_mask(self):
        model = dict(points=[(0.,0.,0.), (1.,0.,0.), (0.,1.,0.), (0.,0.,1.)],
                     polygons=[(0,2,1,0,2,1), (0,1,3,0,1,3), (0,3,2,0,3,2), (1,2,3,1,2,3)],
                     normals=[(0.,0.,1.)]*4, bones=[dict(name='root'),dict(name='joint')],
                     ties=[0,1], weights=[[(0,1.)],[(1,1.)],[(0,1.)],[(0,1.)]],
                     uv_sets=[[(0.,0.,0.),(1.,0.,0.),(0.,1.,0.),(1.,1.,0.)]],
                     texture_polygons=[(0,2,1),(0,1,3),(0,3,2),(1,2,3)])
        output, report = wardrobe.smooth.refine(model, strengths=[0.,1.,0.,0.], maximum=.04, weight_smoothing=.35)
        for i in [0,2,3]:
            self.assertEqual(output['points'][i], model['points'][i])
            self.assertEqual(output['weights'][i], model['weights'][i])
        self.assertNotEqual(output['points'][1], model['points'][1])
        self.assertGreater(len(output['weights'][1]), 1)
        self.assertLessEqual(report['measured_max_displacement'], .04000001)
        for mask in [[], [0.]*3, [float('nan')]*4, [1.1]*4]:
            with self.assertRaises(ValueError): wardrobe.smooth.refine(model, strengths=mask)

    def test_garment_mask_retains_head_hands_and_feet(self):
        model = dict(points=[(0, 0, 1.2), (0, 0, 1.7), (.8, 0, 1.1), (0, 0, .1)],
                     bones=[dict(name=n) for n in ['bip01 spine', 'bip01 head', 'bip01 l hand', 'bip01 l foot']],
                     ties=list(range(4)), weights=[[(i, 1.)] for i in range(4)],
                     polygons=[(i, i, i, 0, 0, 0) for i in range(4)],
                     texture_polygons=[(i, i, i) for i in range(4)])
        for region in ['shirt', 'robe']:
            masked, hidden = wardrobe.hidden_body(model, region)
            self.assertEqual(hidden, 1)
            self.assertEqual([p[0] for p in masked['polygons']], [1, 2, 3])
            self.assertEqual([p[0] for p in masked['texture_polygons']], [1, 2, 3])
            self.assertEqual(len(model['polygons']), 4)

    def test_chunk_rejects_bad_magic_and_table_overrun(self):
        for data in (b'', bytes(96), bytes(64) + struct.pack('<II', 0xCA5E0000, 1000) + bytes(24)):
            with self.assertRaises(ValueError):
                list(module.chunks(data))

    def test_chunk_does_not_allow_payload_in_header(self):
        data = bytearray(160)
        struct.pack_into('<II', data, 64, 0xCA5E0000, 1)
        struct.pack_into('<5I', data, 96, 0xCA5E0103, 0, 116, 0, 0)
        struct.pack_into('<I', data, 116, 1)
        struct.pack_into('<III', data, 132, 0xCA5E0801, 0, 0)
        with self.assertRaises(ValueError):
            list(module.chunks(data))

    def test_coordinate_rotation_preserves_length(self):
        # Human animation master turns source Y-up into model Z-up.
        result = module.rotate([-.5, .5, .5, -.5], [0, 1, 0])
        self.assertEqual(result, (0., 0., 1.))
        inverse = [.5, -.5, -.5, -.5]
        self.assertEqual(module.rotate(inverse, result), (0., 1., 0.))

    def test_zero_quaternion_rejected(self):
        with self.assertRaises(ValueError):
            module.unit([0, 0, 0, 0])

    def test_tga_bottom_origin_is_converted_to_png_top_origin(self):
        header = bytearray(18)
        header[2] = 2
        struct.pack_into('<HHBB', header, 12, 1, 2, 24, 0)
        png = module.png_from_tga(header + bytes([255, 0, 0, 0, 0, 255]))
        offset, payload = 8, b''
        while offset < len(png):
            size = struct.unpack_from('>I', png, offset)[0]
            if png[offset + 4:offset + 8] == b'IDAT':
                payload += png[offset + 8:offset + 8 + size]
            offset += size + 12
        self.assertEqual(zlib.decompress(payload), bytes([0, 255, 0, 0, 255, 0, 0, 0, 255, 255]))

    def test_tga_rejects_truncated_or_oversize_run(self):
        header = bytearray(18)
        header[2] = 10
        struct.pack_into('<HHBB', header, 12, 1, 1, 24, 0)
        for tail in (bytes([129, 0, 0, 0]), bytes([128, 0])):
            with self.assertRaises(ValueError):
                module.png_from_tga(header + tail)


if __name__ == '__main__':
    unittest.main()
