"""Synthetic importer boundary/coordinate tests; no game data required."""
import importlib.util
from pathlib import Path
import struct
import unittest
import zlib

spec = importlib.util.spec_from_file_location('third_dawn', Path(__file__).with_name('import-third-dawn.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ImportBoundaries(unittest.TestCase):
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
