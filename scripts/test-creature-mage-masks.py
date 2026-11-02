"""Source-free costume dye isolation and non-destructive mask regression."""
import base64
import copy
import importlib.util
import struct
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('mage_masks', Path(__file__).with_name('creature-mage-masks.py'))
masks = importlib.util.module_from_spec(spec)
spec.loader.exec_module(masks)


def document(positions, uvs, joints):
    doc = {'buffers': [], 'bufferViews': [], 'accessors': [], 'nodes': [{'name': n} for n in ['bip01 l foot', 'bip01 head', 'bip01 l hand']],
           'skins': [{'joints': [0, 1, 2]}], 'animations': [], 'meshes': [{'primitives': [{'attributes': {}}]}]}
    for name, kind, rows in [('POSITION', 'VEC3', positions), ('TEXCOORD_0', 'VEC2', uvs),
                             ('JOINTS_0', 'VEC4', [(j, 0, 0, 0) for j in joints]), ('WEIGHTS_0', 'VEC4', [(1., 0., 0., 0.) for _ in joints])]:
        index = len(doc['buffers'])
        component = 'H' if name == 'JOINTS_0' else 'f'
        raw = struct.pack('<' + component * len(rows) * len(rows[0]), *(v for row in rows for v in row))
        doc['buffers'].append({'byteLength': len(raw), 'uri': 'data:application/octet-stream;base64,' + base64.b64encode(raw).decode()})
        doc['bufferViews'].append({'buffer': index, 'byteLength': len(raw)})
        doc['accessors'].append({'bufferView': index, 'componentType': 5123 if component == 'H' else 5126, 'count': len(rows), 'type': kind})
        doc['meshes'][0]['primitives'][0]['attributes'][name] = index
    return doc


def costume():
    # Two foot-weighted faces: only the actual low shoe should be shoe-dyed.
    faces = [[(0., 0., z), (.1, 0., z), (0., .1, z)] for z in [.05, .2, 1.3, 1.71]]
    uvs = [(0., 0.), (1., 0.), (0., 1.)]
    original = document([p for face in faces for p in face], uvs * 4, [0] * 6 + [2] * 3 + [1] * 3)
    refined_positions, refined_uvs, refined_joints = [], [], []
    for face, joint in zip(faces, [0, 0, 2, 1]):
        for triangle in [c for first in masks.children(face) for c in masks.children(first)]:
            refined_positions.extend(triangle)
        for triangle in [c for first in masks.children(uvs) for c in masks.children(first)]:
            refined_uvs.extend(triangle)
        refined_joints.extend([joint] * 48)
    return original, document(refined_positions, refined_uvs, refined_joints)


class GarmentMasks(unittest.TestCase):
    def test_foot_weighted_hem_and_exposed_skin(self):
        original, refined = costume()
        masked, proof = masks.apply(original, refined)
        colors = masks.accessor(masked, masked['meshes'][0]['primitives'][0]['attributes']['COLOR_0'])
        self.assertTrue(all(c[:3] == (0., 0., 1.) for c in colors[:48]), 'Shoe dye belongs to actual low shoe faces')
        self.assertTrue(all(c[:3] == (1., 0., 0.) for c in colors[48:96]), 'Foot-weighted cloth hem must stay robe-dyed')
        self.assertTrue(all(c[:3] == (0., 0., 0.) for c in colors[96:144]), 'Hands remain outside garment dyes')
        self.assertTrue(all(c[0] == 0. and c[1] > .99 and c[2] == 0. for c in colors[144:]), 'Integral cap gets its own independent channel')
        self.assertLess(proof['maximum_parent_uv_error'], .00001)
        del masked['meshes'][0]['primitives'][0]['attributes']['COLOR_0']
        for key in ['buffers', 'bufferViews', 'accessors']:
            masked[key].pop()
        self.assertEqual(masked, refined, 'Mask cannot alter mesh, UV, weights, hierarchy or motion payloads')

    def test_reordered_subdivision_uvs_are_rejected(self):
        original, refined = costume()
        broken = copy.deepcopy(refined)
        raw = bytearray(base64.b64decode(broken['buffers'][1]['uri'].split(',', 1)[1]))
        struct.pack_into('<ff', raw, 0, .7, .7)
        broken['buffers'][1]['uri'] = 'data:application/octet-stream;base64,' + base64.b64encode(raw).decode()
        with self.assertRaisesRegex(AssertionError, 'face/UV order changed'):
            masks.apply(original, broken)


if __name__ == '__main__':
    unittest.main()
