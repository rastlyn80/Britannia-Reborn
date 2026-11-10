# SPDX-License-Identifier: GPL-3.0-or-later
"""Small AMOU regression fixtures with no original art."""

from pathlib import Path
import runpy
from struct import pack
import unittest


HERE = Path(__file__).resolve().parent
DECODER = runpy.run_path(str(HERE / "uo-enhanced-frames.py"))
HEADER = DECODER["HEADER"]
FRAME = DECODER["FRAME"]
decode = DECODER["read_amou"]


def sample(pixels=b"\x01\x81\x80\x00\x01\x01", palette=b"\x22\x44\x66\0\x11\x22\x33\0",
           ordinals=(1, 2, 3, 4, 5)):
    table = HEADER.size + len(palette)
    count = len(ordinals)
    image_at = table + count * FRAME.size
    length = image_at + count * len(pixels)
    header = HEADER.pack(b"AMOU", 1, length, 17, -1, -2, 1, 0, len(palette) // 4, HEADER.size, count, table)
    frames = b"".join(FRAME.pack(23, ordinal, -1, -2, 1, 0,
                                  image_at + i * len(pixels) - table - i * FRAME.size)
                      for i, ordinal in enumerate(ordinals))
    return header + palette + frames + pixels * count


class EnhancedFrameDecoderTests(unittest.TestCase):
    def test_opaque_and_partial_pixels(self):
        body, frames = decode(sample())
        self.assertEqual(body, 17)
        self.assertEqual(len(frames), 5)
        self.assertEqual(frames[0].box, (-1, -2, 1, 0))
        self.assertEqual(frames[0].rgba, bytes((0, 0, 0, 0, 34, 68, 102, 127, 17, 34, 51, 255, 0, 0, 0, 0)))

    def test_single_palette_and_explicit_ordinal_gaps(self):
        _, frames = decode(sample(b"\x80\x18\0\0\x02", b"\xff\xff\xff\0", (2, 4, 6, 8, 10)))
        self.assertEqual([frame.ordinal for frame in frames], [2, 4, 6, 8, 10])
        self.assertEqual(frames[0].rgba[3::4], bytes((15, 127, 0, 0)))

    def test_rejects_malformed_streams(self):
        for data in (sample(b"\x05"), sample(b"\x02"), sample(b"\x04\0"),
                     sample(b"\x80"), sample(b"\x84\0\x00"), sample(b"\x81\0\x02\x03"),
                     sample(ordinals=(1, 2, 4, 5, 6)), sample()[:-1]):
            with self.subTest(data=data.hex()[-20:]), self.assertRaises(ValueError):
                decode(data)
        data = bytearray(sample())
        offset = HEADER.size + 8 + FRAME.size - 4
        data[offset:offset + 4] = pack("<I", 0)
        with self.assertRaisesRegex(ValueError, "pixel ranges"):
            decode(data)


if __name__ == "__main__":
    unittest.main()
